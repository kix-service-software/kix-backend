# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Role::PermissionSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Role::RoleGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Role::PermissionSearch - API Permission Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

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
        'RoleID' => {
            DataType => 'NUMERIC',
            Required => 1
        }              
    }
}

=item Run()

perform PermissionSearch Operation. This will return a PermissionID list.

    my $Result = $OperationObject->Run(
        Data => {
            RoleID => 123,
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Permission => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if role exists 
    my $Rolename = $Kernel::OM->Get('Kernel::System::Role')->RoleLookup(
        RoleID => $Param{Data}->{RoleID},
    );
  
    if ( !$Rolename ) {
        return $Self->_Error(
            Code => 'Object.ParentNotFound',
        );
    }

    # perform permission search
    my @PermissionList = $Kernel::OM->Get('Kernel::System::Role')->PermissionList(
        RoleID => $Param{Data}->{RoleID}
    );

	# get already prepared Permission data from PermissionGet operation
    if ( @PermissionList ) {  	
        my $PermissionGetResult = $Self->ExecOperation(
            OperationType            => 'V1::Role::PermissionGet',
            SuppressPermissionErrors => 1,
            Data      => {
                RoleID       => $Param{Data}->{RoleID},
                PermissionID => join(',', sort @PermissionList),
            }
        );    

        if ( !IsHashRefWithData($PermissionGetResult) || !$PermissionGetResult->{Success} ) {
            return $PermissionGetResult;
        }

        my @PermissionDataList = IsArrayRef($PermissionGetResult->{Data}->{Permission}) ? @{$PermissionGetResult->{Data}->{Permission}} : ( $PermissionGetResult->{Data}->{Permission} );

        if ( IsArrayRefWithData(\@PermissionDataList) ) {
            return $Self->_Success(
                Permission => \@PermissionDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Permission => [],
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
