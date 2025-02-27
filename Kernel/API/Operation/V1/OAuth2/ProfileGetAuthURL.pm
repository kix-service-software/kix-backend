# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::OAuth2::ProfileGetAuthURL;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::OAuth2::ProfileGet - API OAuth2 Profile Get AuthURL Operation backend

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
            Required => 1
        }
    };
}

=item Run()

perform OAuth2 ProfileGetAuthURL Operation. This will return the AuthURL for the Profile.

    my $Result = $OperationObject->Run(
        Data => {
            ProfileID => 123,
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            AuthURL => 'AuthURL'
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get the Profile data
    my %ProfileData = $Kernel::OM->Get('OAuth2')->ProfileGet(
        ID => $Param{Data}->{ProfileID},
    );

    if ( !IsHashRefWithData( \%ProfileData ) ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # get AuthURL
    my $AuthURL = $Kernel::OM->Get('OAuth2')->PrepareAuthURL(
        ProfileID => $Param{Data}->{ProfileID},
    );

    # return result
    return $Self->_Success(
        AuthURL => $AuthURL,
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
