# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Reporting::DataSource;

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

Kernel::System::Reporting::DataSource - datasource extension for reporting lib

=head1 SYNOPSIS

All datasource functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item DataSourceList()

returns a list of all datasources

    my @DataSources = $ReportingObject->DataSourceList();

the result looks like

    @DataSources = (
        'TicketList',
        'AssetList',
        ...
    );

=cut

sub DataSourceList {
    my ( $Self, %Param ) = @_;

    # get backend module registration
    my $Backends = $Kernel::OM->Get('Config')->Get('Reporting::DataSource');

    if ( !IsHashRefWithData($Backends) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No datasource backend modules found!",
        );
        return;
    }

    my @Result;
    foreach my $Backend ( keys %{$Backends} ) {
        push @Result, $Backend
    }

    return sort @Result;
}

=item DataSourceGet()

get a description of the given datasource

    my %DataSource = $ReportingObject->DataSourceGet(
        Name => 'TicketList'
    );

=cut

sub DataSourceGet {
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
    my $BackendObject = $Self->_LoadDataSourceBackend(
        %Param
    );
    return if !$BackendObject;

    return $BackendObject->DefinitionGet();
}

=item DataSourceValidateConfig()

validate the given config

    my $IsValid = $ReportingObject->DataSourceValidateConfig(
        Source => 'TicketList',
        Config => { ... }
    );

=cut

sub DataSourceValidateConfig {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Source Config)) {
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

    my $Backend = $Self->_LoadDataSourceBackend(
        Name   => $Param{Source},
        Silent => $Param{Silent},
    );
    return if !$Backend;

    # the backend needs the config
    $Backend->{Config} = $Param{Config};

    return $Backend->ValidateConfig(
        Config => $Param{Config}->{DataSource},
        Silent => $Param{Silent},
    );
}

=item DataSourceGetProperties()

Get the properties contained in the report data from the underlying source based on the given parameters.

Example:
    my $ArrayRef = $Object->DataSourceGetProperties(
        Source => 'TicketList',
        Config => {}
    );

=cut

sub DataSourceGetProperties {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Source Config)) {
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

    my $Backend = $Self->_LoadDataSourceBackend(
        Name => $Param{Source},
    );
    return if !$Backend;

    # the backend needs the config
    $Backend->{Config} = $Param{Config};

    # validate the given config at first
    my $IsValid =  $Backend->ValidateConfig(
        Config => $Param{Config}->{DataSource},
        Silent => $Param{Silent},
    );
    return if !$IsValid;

    return $Backend->GetProperties(
        Config => $Param{Config}->{DataSource}
    );
}

=item DataSourceGetData()

get the report data from the underlying source according to the given parameters

Example:
    my $ArrayRef = $Object->DataSourceGetData(
        Source     => 'TicketList',
        Config     => {...},
        Parameters => {...},
        UserID     => 1,
    );

=cut

sub DataSourceGetData {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Source Config UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Backend = $Self->_LoadDataSourceBackend(
        Name => $Param{Source},
    );
    return if !$Backend;

    # the backend needs the parameter definitions for parameter replacement
    $Backend->{Config}     = $Param{Config};
    $Backend->{Parameters} = $Param{Parameters};

    # validate the given config at first
    my $IsValid =  $Backend->ValidateConfig(
        Config => $Param{Config}->{DataSource}
    );
    return if !$IsValid;

    if ( IsHashRefWithData($Param{Parameters}) ) {
        # validate the given parameters
        my $IsValid =  $Backend->ValidateParameters(
            Config     => $Param{Config}->{DataSource},
            Parameters => $Param{Parameters}
        );
        return if !$IsValid;
    }

    return $Backend->GetData(
        Config     => $Param{Config}->{DataSource},
        Parameters => $Param{Parameters},
        UserID     => $Param{UserID},
    );
}

sub _LoadDataSourceBackend {
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
    $Self->{DataSourceModules} //= {};

    if ( !$Self->{DataSourceModules}->{$Param{Name}} ) {
        # load backend modules
        my $Backends = $Kernel::OM->Get('Config')->Get('Reporting::DataSource');

        if ( !IsHashRefWithData($Backends) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No datasource backend modules found!",
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

        $Self->{DataSourceModules}->{$Param{Name}} = $BackendObject;
    }

    return $Self->{DataSourceModules}->{$Param{Name}};
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
