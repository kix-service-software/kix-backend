# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::SystemAddress::SystemAddressGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SystemAddress::SystemAddressGet - API SystemAddress Get Operation backend

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
        'SystemAddressID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }
    }
}

=item Run()

perform SystemAddressGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
            SystemAddressID => 123       # comma separated in case of multiple or arrayref (depending on transport)
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            SystemAddress => [
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

    my @SystemAddressList;

    # start loop
    foreach my $SystemAddressID ( @{$Param{Data}->{SystemAddressID}} ) {

        # get the SystemAddress data
        my %SystemAddressData = $Kernel::OM->Get('SystemAddress')->SystemAddressGet(
            ID => $SystemAddressID,
        );

        if ( !IsHashRefWithData( \%SystemAddressData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add
        push(@SystemAddressList, \%SystemAddressData);
    }

    if ( scalar(@SystemAddressList) == 1 ) {
        return $Self->_Success(
            SystemAddress => $SystemAddressList[0],
        );
    }

    # return result
    return $Self->_Success(
        SystemAddress => \@SystemAddressList,
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
