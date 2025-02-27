# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Session::UserPreferenceCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Session::UserPreferenceCreate - API Session UserPreference Create Operation backend

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
        'UserPreference' => {
            Type     => 'HASH',
            Required => 1
        },
        'UserPreference::ID' => {
            Required => 1
        },
        'UserPreference::Value' => {},
    }
}

=item Run()

perform UserPreferenceCreate Operation. This will return success.

    my $Result = $OperationObject->Run(
        Data => {
            UserPreference  => {
                ID    => '...',
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
    my %UserData = $Kernel::OM->Get('User')->GetUserData(
        UserID => $Self->{Authorization}->{UserID},
    );
    if ( !%UserData ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }
    if ( exists $UserData{Preferences}->{$Preference->{ID}} ) {
        return $Self->_Error(
            Code => 'Object.AlreadyExists',
        );
    }

    # add user preference
    my $Success = $Kernel::OM->Get('User')->SetPreferences(
        UserID => $Self->{Authorization}->{UserID},
        Key    => $Preference->{ID},
        Value  => $Preference->{Value},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    # return result
    return $Self->_Success(
        Code             => 'Object.Created',
        UserPreferenceID => $Preference->{ID}
    );
}


1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
