# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::TextModule::TextModuleGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TextModule::TextModuleGet - API TextModule Get Operation backend

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
        'TextModuleID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform TextModuleGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TextModuleID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            TextModule => [
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

    my @TextModuleList;

    # start loop
    foreach my $TextModuleID ( @{$Param{Data}->{TextModuleID}} ) {

        # get the TextModule data
        my %TextModuleData = $Kernel::OM->Get('TextModule')->TextModuleGet(
            ID => $TextModuleID,
        );

        if ( !IsHashRefWithData( \%TextModuleData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # convert Keywords to array
        my @Keywords = split(/\s+/, $TextModuleData{Keywords});
        $TextModuleData{Keywords} = \@Keywords;

        # force numeric ID
        $TextModuleData{ID} += 0;

        # add
        push(@TextModuleList, \%TextModuleData);
    }

    if ( scalar(@TextModuleList) == 1 ) {
        return $Self->_Success(
            TextModule => $TextModuleList[0],
        );
    }

    # return result
    return $Self->_Success(
        TextModule => \@TextModuleList,
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
