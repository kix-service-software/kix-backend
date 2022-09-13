# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Plugin::PluginSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Plugin::PluginSearch - API Plugin Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform UserSearch Operation. This will return a User ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Plugin => [
                {
                },
                {
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @PluginList = $Kernel::OM->Get('Installation')->PluginList(
        Valid     => 0|1,
        InitOrder => 1,
    );

    my @ClientIDs = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationList();
    if ( IsArrayRefWithData(\@ClientIDs) ) {
        CLIENT:
        foreach my $ClientID ( sort @ClientIDs ) {
            my %ClientData = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationGet(
                ClientID => $ClientID
            );

            next CLIENT if !IsArrayRefWithData($ClientData{Plugins});

            push @PluginList, @{$ClientData{Plugins}};
        }
    }

    my %Products = map { $_->{Product} => 1 } @PluginList;

    # get already prepared user data from UserGet operation
    my $GetResult = $Self->ExecOperation(
        OperationType            => 'V1::Plugin::PluginGet',
        SuppressPermissionErrors => 1,
        Data          => {
            Product => join(',', sort keys %Products),
        }
    );
    if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
        return $GetResult;
    }

    my @ResultList;
    if ( defined $GetResult->{Data}->{Plugin} ) {
        @ResultList = IsArrayRef($GetResult->{Data}->{Plugin}) ? @{$GetResult->{Data}->{Plugin}} : ( $GetResult->{Data}->{Plugin} );
    }

    if ( IsArrayRefWithData(\@ResultList) ) {
        return $Self->_Success(
            Plugin => \@ResultList,
        )
    }

    # return result
    return $Self->_Success(
        Plugin => [],
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
