# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::User::UserRoleIDCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::User::UserRoleCreate - API User UserRole Create Operation backend

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
        'UserID' => {
            Required => 1
        },
        'RoleID' => {
            Required => 1
        },
    }
}

=item Run()

perform UserRoleCreate Operation. This will return sucsess.

    my $Result = $OperationObject->Run(
        Data => {
            UserID    => 12,
            RoleID    => 6,
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            RoleID => 123
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # create RoleUser
    my $Success = $Kernel::OM->Get('Role')->RoleUserAdd(
        AssignUserID => $Param{Data}->{UserID},
        RoleID       => $Param{Data}->{RoleID},
        UserID       => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create role assignment, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        RoleID => $Param{Data}->{RoleID},
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
