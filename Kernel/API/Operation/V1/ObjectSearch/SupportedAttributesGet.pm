# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectSearch::SupportedAttributesGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectSearch::SupportedAttributesGet - API ObjectSearch supported attributes Get Operation backend

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
        'ObjectType' => {
            Type     => 'ARRAY',
            DataType => 'STRING',
            Required => 1
        },
    }
}

=item Run()

perform SupportedSearch Operation. This function is able to return
one SupportedSearchesult entry in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ObjectType => 'Ticket'                   # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            SupportedAttributes => [
                {

                },
                {

                }
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @SupportedList;

    # start loop
    foreach my $ObjectType ( @{$Param{Data}->{ObjectType}} ) {

        # get the StateType data
        my $List = $Kernel::OM->Get('ObjectSearch')->GetSupportedAttributes(
            ObjectType => $ObjectType
        );

        if ( !IsArrayRefWithData($List) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add
        push(@SupportedList, @{$List});
    }

    # return result
    return $Self->_Success(
        SupportedAttributes => \@SupportedList,
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
