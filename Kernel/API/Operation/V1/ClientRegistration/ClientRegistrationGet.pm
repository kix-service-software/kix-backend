# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ClientRegistration::ClientRegistrationGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ClientRegistration::ClientRegistrationGet - API ClientRegistration Get Operation backend

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
        'ClientID' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform ClientRegistrationGet Operation.

    my $Result = $OperationObject->Run(
        Data => {
            ClientID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            ClientRegistration => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ClientRegistrationList;

    # start loop
    foreach my $ClientID ( @{$Param{Data}->{ClientID}} ) {

        # get the ClientRegistration data
        my %ClientRegistrationData = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationGet(
            ClientID => $ClientID,
        );

        if ( !IsHashRefWithData( \%ClientRegistrationData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add
        push(@ClientRegistrationList, \%ClientRegistrationData);
    }

    if ( scalar(@ClientRegistrationList) == 1 ) {
        return $Self->_Success(
            ClientRegistration => $ClientRegistrationList[0],
        );
    }

    # return result
    return $Self->_Success(
        ClientRegistration => \@ClientRegistrationList,
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
