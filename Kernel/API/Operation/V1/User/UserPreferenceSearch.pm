# --
# Kernel/API/Operation/Own/UserRoleSearch.pm - API UserRole Search operation backend
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

package Kernel::API::Operation::V1::User::UserPreferenceSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Own::UserRoleSearch - API Own UserRole Search Operation backend

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
    my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{Data}->{UserID},
    );

    if ( !IsHashRefWithData( \%UserData ) ) {

        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "No user data found.",
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