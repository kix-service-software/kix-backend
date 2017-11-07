# --
# Kernel/API/Operation/Role/RoleCreate.pm - API Role Create operation backend
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

package Kernel::API::Operation::V1::Role::RoleSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Role::RoleGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Role::RoleSearch - API Role Search Operation backend

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

perform RoleSearch Operation. This will return a Role ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Role => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # perform Role search
    my %RoleList = $Kernel::OM->Get('Kernel::System::Group')->RoleList(
        Result => 'HASH',
    );

	# get already prepared Role data from RoleGet operation
    if ( IsHashRefWithData(\%RoleList) ) {  	
        my $RoleGetResult = $Self->ExecOperation(
            OperationType => 'V1::Role::RoleGet',
            Data      => {
                RoleID => join(',', sort keys %RoleList),
            }
        );    

        if ( !IsHashRefWithData($RoleGetResult) || !$RoleGetResult->{Success} ) {
            return $RoleGetResult;
        }

        my @RoleDataList = IsArrayRefWithData($RoleGetResult->{Data}->{Role}) ? @{$RoleGetResult->{Data}->{Role}} : ( $RoleGetResult->{Data}->{Role} );

        if ( IsArrayRefWithData(\@RoleDataList) ) {
            return $Self->_Success(
                Role => \@RoleDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Role => {},
    );
}

1;