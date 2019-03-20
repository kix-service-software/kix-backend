# --
# Kernel/API/Operation/Role/RoleUserSearch.pm - API UserRole Search operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Role::RoleUserSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Role::RoleUserSearch - API Role RoleUser Search Operation backend

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
            Required => 1
        },
    }
}

=item Run()

perform UserRoleSearch Operation. This will return a User ID.

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
            UserID => [
                ...
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform RoleUser search
    my %UserList = $Kernel::OM->Get('Kernel::System::Role')->RoleUserList(
        RoleID => $Param{Data}->{RoleID},
    );

    my @ResultList;
    foreach my $UserID ( sort keys %UserList ) {
        push(@ResultList, 0 + $UserID);     # enforce nummeric ID
    }
    if ( IsArrayRefWithData(\@ResultList) ) {
        return $Self->_Success(
            UserIDs => \@ResultList,
        )
    }

    # return result
    return $Self->_Success(
        UserIDs => [],
    );
}

1;