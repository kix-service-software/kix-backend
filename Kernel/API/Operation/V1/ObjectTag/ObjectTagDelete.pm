# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectTag::ObjectTagDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectTag::ObjectTagDelete - API ObjectTag ObjectTagDelete Operation backend

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
        }
    }
}

=item Run()

perform ObjectTagDelete Operation. This will return the error or success.

    my $Result = $OperationObject->Run(
        Data => {
            ObjectTagID  => '...',
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ObjectTag parameter
    my $Data = $Self->_Trim(
        Data => $Param{Data},
    );

    # deletes all entries with the tag over each object
    if ( IsArrayRefWithData( $Data->{ObjectTagID} ) ) {
        foreach my $ObjectTagID ( @{$Data->{ObjectTagID}} ) {
            # get the Organisation data
            my %ObjectTag = $Kernel::OM->Get('ObjectTag')->ObjectTagGet(
                ID => $ObjectTagID,
            );

            if ( !IsHashRefWithData( \%ObjectTag ) ) {

                return $Self->_Error(
                    Code => 'Object.NotFound',
                );
            }

            # delete contact
            my $Success = $Kernel::OM->Get('ObjectTag')->ObjectTagDelete(
                ID => $ObjectTagID
            );

            if ( !$Success ) {
                return $Self->_Error(
                    Code    => 'Object.UnableToDelete',
                    Message => 'Could not delete object tag, please contact the system administrator',
                );
            }
        }
    }

    # return result
    return $Self->_Success();
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
