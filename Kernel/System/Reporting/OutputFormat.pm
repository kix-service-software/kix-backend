# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::OutputFormat;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Reporting::OutputFormat - output format extension for reporting lib

=head1 SYNOPSIS

All output format functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item OutputFormatList()

returns a list of all output formats

    my @OutputFormats = $ReportingObject->OutputFormatList();

the result looks like

    @OutputFormats = (
        'CSV',
        'XML',
        ...
    );

=cut

sub OutputFormatList {
    my ( $Self, %Param ) = @_;

    # get backend module registration
    my $Backends = $Kernel::OM->Get('Config')->Get('Reporting::OutputFormat');

    if ( !IsHashRefWithData($Backends) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No output format backend modules found!",
        );
        return;
    }

    my @Result;
    foreach my $Backend ( keys %{$Backends} ) {
        push @Result, $Backend
    }

    return sort @Result;
}

=item OutputFormatGet()

get a description of the given output format

    my %OutputFormat = $ReportingObject->OutputFormatGet(
        Name => 'CSV'
    );

=cut

sub OutputFormatGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name!',
        );
        return;
    }

    # load backend module
    my $BackendObject = $Self->_LoadOutputFormatBackend(
        %Param
    );
    return if !$BackendObject;

    return $BackendObject->DefinitionGet();
}

=item GenerateOutput()

Run this output module. Returns a HashRef with the result if successful, otherwise undef.

Example:
    my $Result = $Object->GenerateOutput(
        Format     => 'CSV',
        Config     => {},
        Parameters => {},                       # optional
        Data       => [                         # the row array containing the data
            {...},
            {...},
        ],
    );

returns something like:

    {
        ContentType => 'text/csv',
        Content     => '...',
    }

=cut

sub GenerateOutput {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Format Config Data)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # load the backend
    my $Backend = $Self->_LoadOutputFormatBackend(
        Name => $Param{Format}
    );
    return if !$Backend;

    # the backend needs the parameter definitions for parameter replacement
    $Backend->{Config}     = $Param{Config};
    $Backend->{Parameters} = $Param{Parameters};

    # take Title from definition if the output format config doesn't contain a Title
    my $Config = $Param{Config}->{OutputFormats}->{$Param{Format}} || {};
    if ( !exists $Config->{Title } && defined $Param{Config}->{Title} ) {
        $Config->{Title} = $Param{Config}->{Title};
    }

    # generate the output and return;
    return $Backend->Run(
        Config => $Config,
        Data   => $Param{Data}
    );
}

=item OutputFormatValidateConfig()

validate the given config

    my $IsValid = $ReportingObject->OutputFormatValidateConfig(
        Format => 'CSV',
        Config => { ... }       # optional
    );

=cut

sub OutputFormatValidateConfig {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Format)) {
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

    my $Backend = $Self->_LoadOutputFormatBackend(
        Name   => $Param{Format},
        Silent => $Param{Silent},
    );
    return if !$Backend;

    return $Backend->ValidateConfig(
        Config => $Param{Config},
        Silent => $Param{Silent},
    );
}

sub _LoadOutputFormatBackend {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name)) {
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

    # load backend
    $Self->{OutputFormatModules} //= {};

    if ( !$Self->{OutputFormatModules}->{$Param{Name}} ) {
        # load backend modules
        my $Backends = $Kernel::OM->Get('Config')->Get('Reporting::OutputFormat');

        if ( !IsHashRefWithData($Backends) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No output format backend modules found!",
                );
            }
            return;
        }

        my $Backend = $Backends->{$Param{Name}}->{Module};

        if (
            !$Kernel::OM->Get('Main')->Require(
                $Backend,
                Silent => $Param{Silent},
            )
        ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to require $Backend!"
                );
            }
            return;
        }

        my $BackendObject = $Backend->new( %{$Self} );
        if ( !$BackendObject ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to create instance of $Backend!"
                );
            }
            return;
        }

        $Self->{OutputFormatModules}->{$Param{Name}} = $BackendObject;
    }

    return $Self->{OutputFormatModules}->{$Param{Name}};
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
