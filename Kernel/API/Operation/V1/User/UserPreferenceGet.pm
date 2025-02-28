# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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
    my %UserData = $Kernel::OM->Get('User')->GetUserData(
        UserID => $Param{Data}->{UserID},
    );
    if ( !%UserData ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    if ( !exists $UserData{Preferences}->{$Param{Data}->{UserPreferenceID}} ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
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
=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
