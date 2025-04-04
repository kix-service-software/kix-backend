# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Role::PermissionTypeSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Role::RoleGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Role::PermissionTypeSearch - API PermissionType Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform PermissionTypeSearch Operation. This will return a PermissionType list.

    my $Result = $OperationObject->Run(
        Data => {
            RoleID => 123
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            PermissionType => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform permission search
    my %PermissionTypeList = $Kernel::OM->Get('Role')->PermissionTypeList();

	# get prepare
    if ( IsHashRefWithData(\%PermissionTypeList) ) {

        my @Result;
        foreach my $TypeID ( sort keys %PermissionTypeList ) {
            my %TypeData = $Kernel::OM->Get('Role')->PermissionTypeGet(
                ID => $TypeID,
            );

            push(@Result, \%TypeData);
        }

        return $Self->_Success(
            PermissionType => \@Result,
        )
    }

    # return result
    return $Self->_Success(
        PermissionType => [],
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
