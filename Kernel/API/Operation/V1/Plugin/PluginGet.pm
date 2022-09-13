# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Plugin::PluginGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Plugin::PluginGet - API Plugin Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'Product' => {
            Type     => 'ARRAY',
            Required => 1
        }
    }
}

=item Run()

perform UserGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            Product => 'KIXPro'       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
        Data         => {
            Plugin => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @Result;

    my @PluginList = $Kernel::OM->Get('Installation')->PluginList(
        Valid     => 0|1,
        InitOrder => 1,
    );
    my %Plugins = map { $_->{Product} => $_ } @PluginList;

    # start loop
    foreach my $Product ( @{$Param{Data}->{Product}} ) {

        # get backend plugin (if available)
        if ( IsHashRefWithData($Plugins{$Product}) ) {
            my %Plugin = %{$Plugins{$Product}};

            # remove some attributes
            foreach my $Attr ( qw(BuildHost Directory Exports RequiresList) ) {
                delete $Plugin{$Attr};
            }

            my @ActionList = $Kernel::OM->Get('Installation')->PluginActionList( Plugin => $Product );
            if ( @ActionList ) {
                $Plugin{Actions} = \@ActionList;
            }

            my %ExtendedData = $Kernel::OM->Get('Installation')->PluginExtendedDataGet( Plugin => $Product );
            if ( %ExtendedData ) {
                $Plugin{ExtendedData} = \%ExtendedData;
            }

            push @Result, \%Plugin;
        }

        # get client plugin (if available)
        my @ClientIDs = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationList();
        if ( IsArrayRefWithData(\@ClientIDs) ) {
            CLIENT:
            foreach my $ClientID ( sort @ClientIDs ) {
                my %ClientData = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationGet(
                    ClientID => $ClientID
                );

                next CLIENT if !IsArrayRefWithData($ClientData{Plugins});

                my %Plugins = map { $_->{Product} => $_ } @{$ClientData{Plugins}};
                next CLIENT if !IsHashRefWithData($Plugins{$Product});

                my %Plugin = %{$Plugins{$Product}};

                $Plugin{BuildDate} = $Plugin{ExtendedData}->{BuildDate};
                $Plugin{ClientID} = $ClientID;
                delete $Plugin{ExtendedData};
                
                push @Result, \%Plugin;
            }
        }
    }

    if ( scalar(@Result) == 1 ) {
        return $Self->_Success(
            Plugin => $Result[0],
        );
    }

    return $Self->_Success(
        Plugin => \@Result,
    );
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
