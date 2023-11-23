# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Session::UserRoleIDSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Session::UserRoleIDSearch - API Session UserRole Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform UserRoleSearch Operation. This will return a Role ID.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            RoleIDs => [
                ...
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get roles list
    my @RoleList = $Kernel::OM->Get('User')->RoleList(
        UserID => $Self->{Authorization}->{UserID},
    );

    my @ResultList;
    foreach my $RoleID ( sort @RoleList ) {
        push(@ResultList, 0 + $RoleID);     # enforce nummeric ID
    }
    if ( IsArrayRefWithData(\@ResultList) ) {
        return $Self->_Success(
            RoleIDs => \@ResultList,
        )
    }

    # return result
    return $Self->_Success(
        RoleIDs => [],
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
