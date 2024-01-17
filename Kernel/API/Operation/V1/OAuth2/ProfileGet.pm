# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::OAuth2::ProfileGet;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::OAuth2::ProfileGet - API OAuth2 Profile Get Operation backend

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
        'ProfileID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        }
    };
}

=item Run()

perform OAuth2 ProfileGet Operation. This function is able to return
one or more profiles in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ProfileID => [
                123,
            ]
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            Profile => [
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

    my @ProfileList;

    # start loop
    foreach my $ProfileID ( @{ $Param{Data}->{ProfileID} } ) {

        # get the Profile data
        my %ProfileData = $Kernel::OM->Get('OAuth2')->ProfileGet(
            ID => $ProfileID,
        );

        if ( !IsHashRefWithData( \%ProfileData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # remove client secret
        delete $ProfileData{ClientSecret};

        # check access token
        my $Result= $Kernel::OM->Get('OAuth2')->HasToken(
            ProfileID => $ProfileID
        );
        $ProfileData{HasAccessToken} = $Result ? 1 : 0;

        # add to list
        push( @ProfileList, \%ProfileData );
    }

    if ( scalar( @ProfileList ) == 1 ) {
        return $Self->_Success(
            Profile => $ProfileList[0],
        );
    }

    # return result
    return $Self->_Success(
        Profile => \@ProfileList,
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
