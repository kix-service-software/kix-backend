# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::DataSource::GenericSQL;

use strict;
use warnings;

use Date::Pcalc qw(:all);
use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Reporting::DataSource::Common
);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Reporting::DataSource::GenericSQL - generic SQL datasource for automation lib

=head1 SYNOPSIS

Provides a simple generic SQL execution.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this datasource module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Allows to retrieve report data based on an SQL statement.'));
    $Self->AddOption(
        Name        => 'SQL',
        Label       => Kernel::Language::Translatable('SQL'),
        Description => Kernel::Language::Translatable('The SQL statement. You can also base64-encode the statement in the form "base64(...)".'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'OutputHandler',
        Label       => Kernel::Language::Translatable('Output Handler'),
        Description => Kernel::Language::Translatable('A list of output handler to be run on the data in the given order. The output of each handler will be used as the input of the following handler.'),
        Required    => 0,
    );

    return;
}

=item DefinitionGet()

get the definition of this datasource module.

Example:
    my %Definition = $Object->DefinitionGet();

=cut

sub DefinitionGet {
    my ( $Self ) = @_;

    my %Definition = $Self->SUPER::DefinitionGet();

    # add output handlers
    my $OutputHandlers = $Kernel::OM->Get('Config')->Get('Reporting::DataSource::GenericSQL::OutputHandler');

    if ( IsHashRefWithData($OutputHandlers) ) {
        foreach my $OutputHandler ( sort keys %{$OutputHandlers} ) {
            # load backend module
            my $BackendObject = $Self->_LoadOutputHandlerBackend(
                Name => $OutputHandler
            );
            return if !$BackendObject;

            my %HandlerDefinition = $BackendObject->DefinitionGet();
            if ( %HandlerDefinition ) {
                $HandlerDefinition{Name} = $OutputHandler;
                $Definition{OutputHandlers}->{$OutputHandler} = \%HandlerDefinition;
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "GenericSQL output handler module \"$OutputHandler\" doesn't describe itself!",
                );
            }
        }
    }

    # add functions
    my $Functions = $Kernel::OM->Get('Config')->Get('Reporting::DataSource::GenericSQL::Function');

    if ( IsHashRefWithData($Functions) ) {
        foreach my $Function ( sort keys %{$Functions} ) {
            # load backend module
            my $BackendObject = $Self->_LoadFunctionBackend(
                Name => $Function
            );
            return if !$BackendObject;

            my %FunctionDefinition = $BackendObject->DefinitionGet();
            if ( %FunctionDefinition ) {
                $FunctionDefinition{Name} = $Function;
                $FunctionDefinition{Usage} = $Functions->{$Function}->{Usage};
                $Definition{Functions}->{$Function} = \%FunctionDefinition;
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "GenericSQL function module \"$Function\" doesn't describe itself!",
                );
            }
        }
    }

    return %Definition;
}

=item ValidateConfig()

Validates the config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # required
    );

=cut

sub ValidateConfig {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Config} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Got no Config!',
            );
        }
        return;
    }

    # do some basic checks
    return if !$Self->SUPER::ValidateConfig(%Param);

    # check the SQL config
    if ( !IsHashRefWithData($Param{Config}->{SQL}) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "SQL is not a HASH ref!",
            );
        }
        return;
    }

    foreach my $DBMS ( sort keys %{$Param{Config}->{SQL}} ) {
        # validate DBMS
        if ( $DBMS !~ /^(postgresql|mysql|any)$/g ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Given DBMS \"$DBMS\" is not supported!",
                );
            }
            return;
        }

        # validate the SQL statement
        my $SQL = $Param{Config}->{SQL}->{$DBMS};
        if ( $SQL =~ /^base64\((.*?)\)\s*$/ ) {
            $SQL = MIME::Base64::decode_base64($1);
        }

        if ( $SQL !~ /^(SELECT|WITH)\s+/i ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "SQL statement for DBMS \"$DBMS\" is not a SELECT statement!",
                );
            }
            return;
        }
    }


    # get SQL statement from config and prepare it for use
    my $SQL = $Self->_PrepareSQLStatement(
        Config                => $Param{Config},
        UseFallbackParameters => 1,                  # if we don't have defaults we want to have a valid SQL at least
        Silent                => $Param{Silent},
    );

    my $DBObject = $Kernel::OM->Get('DB');

    # prepare the SQL statement
    my $Result = $DBObject->Prepare(
        SQL => $SQL
    );
    if ( !$Result ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid SQL statement!",
            );
        }
        return;
    }

    if ( !$DBObject->GetColumnNames() ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "SQL statement does not contain a column list!",
            );
        }
        return;
    }

    # check output handler
    foreach my $OutputHandler ( @{$Param{Config}->{OutputHandler} || []} ) {
        if ( !IsHashRefWithData($OutputHandler) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "OutputHandler config is invalid!",
                );
            }
            return;
        }
        if ( !$OutputHandler->{Name} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "OutputHandler config is invalid - handler doesn't have a name!",
                );
            }
            return;
        }

        # load backend module
        my $BackendObject = $Self->_LoadOutputHandlerBackend(
            Name => $OutputHandler->{Name}
        );
        return if !$BackendObject;

        return if !$BackendObject->ValidateConfig(
            Config => $OutputHandler
        );
    }

    return 1;
}

=item GetProperties()

Get the attributes contained in the report data from the underlying source based on the given parameters.

Example:
    my $ArrayRef = $Object->GetProperties(
        Config => {}
    );

=cut

sub GetProperties {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # get SQL statement from config and prepare it for use
    my $SQL = $Self->_PrepareSQLStatement(
        Config                => $Param{Config},
        UseFallbackParameters => 1                  # if we don't have defaults we want to have a valid SQL at least
    );

    my $DBObject = $Kernel::OM->Get('DB');

    # prepare the SQL statement
    my $Result = $DBObject->Prepare(
        SQL => $SQL
    );
    if ( !$Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Invalid SQL statement: $SQL!",
        );
        return;
    }

    my @Result = $DBObject->GetColumnNames();

    return \@Result;
}

=item GetData()

get the report data from the underlying source according to the given parameters

Example:
    my $ArrayRef = $Object->Run(
        Config => {...}
    );

=cut

sub GetData {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # get SQL statement from config and prepare it for use (we don't use fallback parameters here since we want valid SQL + parameters by itself)
    my $SQL = $Self->_PrepareSQLStatement(
        Config => $Param{Config}
    );

    my $DBObject = $Kernel::OM->Get('DB');

    # prepare the SQL statement
    my $Success = $DBObject->Prepare(
        SQL => $SQL
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to prepare SQL statement!",
        );
        return;
    }

    my $Columns = $Self->GetProperties(Config => $Param{Config});
    if ( !$Columns ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "SQL statement defines no columns!",
        );
        return;
    }

    # fetch the result
    my $FetchResult = $DBObject->FetchAllArrayRef(
        Columns => $Columns,
    );
    if ( !$FetchResult ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to execute SQL statement!",
        );
        $FetchResult = [];
    }

    my $Result = {
        'Columns' => $Columns,
        'Data'    => $FetchResult,
    };

    # check output handler
    foreach my $OutputHandler ( @{$Param{Config}->{OutputHandler} || []} ) {
        # load backend module
        my $BackendObject = $Self->_LoadOutputHandlerBackend(
            Name => $OutputHandler->{Name}
        );
        return if !$BackendObject;

        $Result = $BackendObject->Run(
            Data   => $Result,
            Config => $OutputHandler,
            UserID => $Param{UserID},
        );
    }

    return $Result;
}

sub _PrepareSQLStatement {
    my ( $Self, %Param) = @_;

    # check needed stuff
    for (qw(Config)) {
        if ( !$Param{$_} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    my $DBObject = $Kernel::OM->Get('DB');

    my $SQL = $Param{Config}->{SQL}->{$DBObject->{'DB::Type'}} || $Param{Config}->{SQL}->{any};
    if ( !$SQL ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No SQL statement for the current DBMS \"".$DBObject->{'DB::Type'}."\" given!",
            );
        }
        return;
    }
    if ( $SQL =~ /^base64\((.*?)\)\s*$/ ) {
        $SQL = MIME::Base64::decode_base64($1);
    }

    # quote parameters to prevent SQL injection
    foreach my $Parameter ( sort keys %{$Self->{Parameters} || {}} ) {
        if ( IsArrayRefWithData($Self->{Parameters}->{$Parameter}) ) {
            foreach my $Value ( @{$Self->{Parameters}->{$Parameter}} ) {
                $Value = $DBObject->Quote($Value);
            }
        }
        else {
            $Self->{Parameters}->{$Parameter} = $DBObject->Quote($Self->{Parameters}->{$Parameter});
        }
    }

    # "execute" functions
    my %Definition = $Self->DefinitionGet();
    foreach my $Function ( sort keys %{$Definition{Functions} || {}} ) {
        my $Usage = $Definition{Functions}->{$Function}->{Usage};
        $Usage =~ s/([()])/\\$1/g;

        # map function parameters to capture group
        my %FunctionParamIndex;
        my $Index;
        while ( $Usage =~ s/:(\w+)/\(.*?\)/ ) {
            $FunctionParamIndex{$1} = $Index++;
        }

        # extract function parameters
        my @Captured;
        do {
            if ( @Captured = $SQL =~ /\$\{Functions\.$Usage\}/smx ) {
                my %FunctionParams;
                foreach my $Param ( sort keys %FunctionParamIndex ) {
                    $FunctionParams{$Param} = $Captured[$FunctionParamIndex{$Param}];
                    $FunctionParams{$Param} =~ s/^\n+//gsmx;
                    $FunctionParams{$Param} =~ s/^\s+//gsmx;
                    $FunctionParams{$Param} =~ s/\s+$//gsmx;
                    $FunctionParams{$Param} =~ s/^'(.*?)'$/$1/gsmx;

                    # replace parameters
                    $FunctionParams{$Param} = $Self->_ReplaceParametersInString(
                        String => $FunctionParams{$Param},
                        Silent => $Param{Silent},
                    );
                }
                my $Result = $Self->_ExecuteFunction(
                    Function => $Function,
                    %FunctionParams
                );
                $SQL =~ s/\$\{Functions\.$Usage\}/$Result/smx;
            }
        } while ( @Captured );
    }

    # prepare SQL statement, use empty parameter initialization only if requested
    $SQL = $Self->_ReplaceParametersInString(
        String   => $SQL,
        UseEmpty => $Param{UseFallbackParameters},
    );

    return $SQL;
}

sub _ExecuteFunction {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Function)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $BackendObject = $Self->_LoadFunctionBackend(
        Name => $Param{Function}
    );
    return if !$BackendObject;

    return $BackendObject->Run(%Param);
}

sub _LoadOutputHandlerBackend {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # load backend
    $Self->{GenericSQLOutputHandlerModules} //= {};

    if ( !$Self->{GenericSQLOutputHandlerModules}->{$Param{Name}} ) {
        # load backend modules
        my $Backends = $Kernel::OM->Get('Config')->Get('Reporting::DataSource::GenericSQL::OutputHandler');

        if ( !IsHashRefWithData($Backends) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No GenericSQL output handler modules found!",
            );
            return;
        }

        my $Backend = $Backends->{$Param{Name}}->{Module};

        if ( !$Kernel::OM->Get('Main')->Require($Backend) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to require $Backend!"
            );
            return;
        }

        my $BackendObject = $Backend->new( %{$Self} );
        if ( !$BackendObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create instance of $Backend!"
            );
            return;
        }

        $Self->{GenericSQLOutputHandlerModules}->{$Param{Name}} = $BackendObject;
    }

    $Self->{GenericSQLOutputHandlerModules}->{$Param{Name}}->{Config}     = $Self->{Config};
    $Self->{GenericSQLOutputHandlerModules}->{$Param{Name}}->{Parameters} = $Self->{Parameters};

    return $Self->{GenericSQLOutputHandlerModules}->{$Param{Name}};
}

sub _LoadFunctionBackend {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # load backend
    $Self->{GenericSQLFunctionModules} //= {};

    if ( !$Self->{GenericSQLFunctionModules}->{$Param{Name}} ) {
        # load backend modules
        my $Backends = $Kernel::OM->Get('Config')->Get('Reporting::DataSource::GenericSQL::Function');

        if ( !IsHashRefWithData($Backends) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No GenericSQL function modules found!",
            );
            return;
        }

        my $Backend = $Backends->{$Param{Name}}->{Module};

        if ( !$Kernel::OM->Get('Main')->Require($Backend) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to require $Backend!"
            );
            return;
        }

        my $BackendObject = $Backend->new( %{$Self} );
        if ( !$BackendObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create instance of $Backend!"
            );
            return;
        }

        $Self->{GenericSQLFunctionModules}->{$Param{Name}} = $BackendObject;
    }

    $Self->{GenericSQLFunctionModules}->{$Param{Name}}->{Config}     = $Self->{Config};
    $Self->{GenericSQLFunctionModules}->{$Param{Name}}->{Parameters} = $Self->{Parameters};

    return $Self->{GenericSQLFunctionModules}->{$Param{Name}};
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
