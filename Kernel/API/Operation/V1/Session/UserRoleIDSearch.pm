# --
# Kernel/API/Operation/Session/UserRoleSearch.pm - API UserRole Search operation backend
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
    my @RoleList = $Kernel::OM->Get('Kernel::System::User')->RoleList(
        UserID => $Param{Data}->{UserID},
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