# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectTag::ObjectTagGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectTag::ObjectTagGet - API ObjectTag Get Operation backend

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
        'ObjectTagID' => {
            Type     => 'ARRAY',
            DataType => 'NUMBER',
            Required => 1
        }
    }
}

=item Run()

perform ObjectTagGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ObjectTagID => 1       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            ObjectTag => [
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

    my @ObjectTagList;
    # start loop
    foreach my $ID ( @{$Param{Data}->{ObjectTagID}} ) {

        # get the ObjectTag data
        my %ObjectTag = $Kernel::OM->Get('ObjectTag')->ObjectTagGet(
            ID => $ID,
        );

        if ( !%ObjectTag ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add
        push(@ObjectTagList, \%ObjectTag);
    }

    if ( scalar(@ObjectTagList) == 1 ) {
        return $Self->_Success(
            ObjectTag => $ObjectTagList[0],
        );
    }

    # return result
    return $Self->_Success(
        ObjectTag => \@ObjectTagList,
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
