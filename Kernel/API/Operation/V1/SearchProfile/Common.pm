# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SearchProfile::Common;

use strict;
use warnings;

use MIME::Base64();
use Mail::Address;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SearchProfile::Common - Base class for all SearchProfile Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=begin Internal:

=item _CheckSearchProfile()

checks if the given SearchProfile parameter is valid.

    my $CheckResult = $OperationObject->_CheckSearchProfile(
        SearchProfile => $SearchProfile,              # all parameters
    );

    returns:

    $CheckResult = {
        Success => 1,                               # if everything is OK
    }

    $CheckResult = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckSearchProfile {
    my ( $Self, %Param ) = @_;

    my $SearchProfile = $Param{SearchProfile};

    my $SearchProfileObject = $Kernel::OM->Get('Kernel::System::SearchProfile');

    if ( $SearchProfile->{SubscribedProfileID} && IsArrayRefWithData($SearchProfile->{Categories}) ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "A subscribed profile can't be shared in categories.",
        );        
    }

    if ( $SearchProfile->{SubscribedProfileID} && IsHashRefWithData($SearchProfile->{Data})   ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "A subscribed profile can't have data.",
        );        
    }

    if ( $SearchProfile->{SubscribedProfileID} ) {
        # check if the the profille can be subscribed to the given ID
        my @SubscribableProfileIDs = $Kernel::OM->Get('Kernel::System::SearchProfile')->SearchProfileList(
            OnlySubscribable => 1,
        );
        my %SubscribableProfiles = map { $_ => 1 } @SubscribableProfileIDs;

        if ( !$SubscribableProfiles{$SearchProfile->{SubscribedProfileID}} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Can't subscribe to the given SubscribableProfileID.",
            );        
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
