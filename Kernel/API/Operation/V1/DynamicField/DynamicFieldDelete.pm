# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::DynamicField::DynamicFieldDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::DynamicField::DynamicFieldDelete - API DynamicField DynamicFieldDelete Operation backend

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
        'DynamicFieldID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform DynamicFieldDelete Operation. This will return the deleted DynamicFieldID.

    my $Result = $OperationObject->Run(
        Data => {
            DynamicFieldID  => '...',
        },
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # start loop
    foreach my $DynamicFieldID ( @{$Param{Data}->{DynamicFieldID}} ) {

        # check if df is writeable
        my $DynamicFieldData = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
            ID   => $DynamicFieldID,
        );
        if ( $DynamicFieldData->{InternalField} == 1 ) {
            return $Self->_Error(
                Code    => 'Forbidden',
                Message => "Cannot delete DynamicField. DynamicField with ID '$Param{Data}->{DynamicFieldID}' is internal and cannot be deleted.",
            );
        }

        # check if there is an object with this dynamic field
        foreach my $ValueType ( qw(Integer DateTime Text) ) {
            my $ExistingValues = $Kernel::OM->Get('DynamicFieldValue')->HistoricalValueGet(
                FieldID   => $DynamicFieldID,
                ValueType => $ValueType,
            );
            if ( IsHashRefWithData($ExistingValues) ) {
                return $Self->_Error(
                    Code    => 'Object.DependingObjectExists',
                    Message => 'Cannot delete DynamicField. This DynamicField is used in at least one object.',
                );
            }
        }

        # delete DynamicField
        my $Success = $Kernel::OM->Get('DynamicField')->DynamicFieldDelete(
            ID      => $DynamicFieldID,
            UserID  => $Self->{Authorization}->{UserID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete DynamicField, please contact the system administrator',
            );
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
