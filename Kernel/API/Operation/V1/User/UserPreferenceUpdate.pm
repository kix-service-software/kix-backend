# --
# Kernel/API/Operation/User/UserPreferenceUpdate.pm - API PreferenceUser Update operation backend
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

package Kernel::API::Operation::V1::User::UserPreferenceUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::User::UserPreferenceUpdate - API User UserPreference Update Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to Update an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
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
        'UserPreference' => {
            Type     => 'HASH',
            Required => 1
        },
        'UserPreference::Value' => {
            Required => 1
        },
    }
}

=item Run()

perform UserPreferenceUpdate Operation. This will return success.

    my $Result = $OperationObject->Run(
        Data => {
            UserID       => 12,
            UserPreferenceID => '...',
            UserPreference   => {
                Value => '...'
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            UserPreferenceID => '...'
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Preference parameter
    my $Preference = $Self->_Trim(
        Data => $Param{Data}->{UserPreference},
    );

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
            Message => "Cannot update user preference. No user preference with ID '$Param{Data}->{UserPreferenceID}' found for user.",
        );
    }

    # add user preference
    my $Success = $Kernel::OM->Get('Kernel::System::User')->SetPreferences(
        UserID => $Param{Data}->{UserID},
        Key    => $Param{Data}->{UserPreferenceID},
        Value  => $Preference->{Value},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update user preference, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        UserPreferenceID => $Param{Data}->{UserPreferenceID}
    );    
}


1;
