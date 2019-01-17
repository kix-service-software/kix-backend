# --
# Kernel/API/Operation/Own/UserRoleGet.pm - API UserRole Get operation backend
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

package Kernel::API::Operation::V1::User::UserPreferenceGet;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::User::UserPreferenceGet - API User UserPreferenceGet Operation backend

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
        'UserID' => {
            Required => 1
        },
        'UserPreferenceID' => {
            Required => 1
        },
    }
}

=item Run()

perform UserPreferenceGet Operation. This will return a list of preferences.

    my $Result = $OperationObject->Run(
        Data => {
            UserID       => 123
            UserPreferenceID => '...'
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            UserPreference => {
                UserID => 123
                ID     => '...'
                Value  => '...'
            }
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if user exists and if preference exists for given user
    my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{Data}->{UserID},
    );
    if ( !%UserData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update user preference. No user with ID '$Param{Data}->{UserID}' found.",
        );
    }

    if ( !exists $UserData{Preferences}->{$Param{Data}->{UserPreferenceID}} ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot get user preference. No user preference with ID '$Param{Data}->{UserPreferenceID}' found for user.",
        );
    }

    return $Self->_Success(
        UserPreference => {
            UserID => $Param{Data}->{UserID},
            ID     => $Param{Data}->{UserPreferenceID},
            Value  => $UserData{Preferences}->{$Param{Data}->{UserPreferenceID}}
        }
    )
}

1;