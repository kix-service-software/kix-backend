# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::User::UserPreferenceSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::User::UserRoleSearch - API UserPreference Search Operation backend

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
    }
}

=item Run()

perform UserPreferenceSearch Operation. This will return a list of preferences.

    my $Result = $OperationObject->Run(
        Data => {
            UserID  => 123
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            UserPreference => [
                ...
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get the user data
    my %UserData = $Kernel::OM->Get('User')->GetUserData(
        UserID => $Param{Data}->{UserID},
    );

    if ( !IsHashRefWithData( \%UserData ) ) {

        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    my @PrefList;
    foreach my $Pref ( sort keys %{$UserData{Preferences}} ) {
        push(@PrefList, {
            UserID => $Param{Data}->{UserID},
            ID     => $Pref,
            Value  => $UserData{Preferences}->{$Pref}
        });
    }

    if ( IsArrayRefWithData(\@PrefList) ) {
        return $Self->_Success(
            UserPreference => \@PrefList,
        )
    }

    # return result
    return $Self->_Success(
        UserPreference => [],
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
