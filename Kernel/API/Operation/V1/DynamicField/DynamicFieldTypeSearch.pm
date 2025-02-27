# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::DynamicField::DynamicFieldTypeSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::DynamicField::DynamicFieldTypeSearch - API DynamicField Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform DynamicFieldTypeSearch Operation. This will return a list of DynamicField FieldTypes.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            DynamicFieldType => [
                { },
                { },
                ...
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $FieldTypeConfig = $Kernel::OM->Get('Config')->Get('DynamicFields::Driver');

    if ( !IsHashRefWithData($FieldTypeConfig) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => 'DynamicField::Driver config is not valid',
        );
    }

    my @FieldTypes;
    for my $FieldType ( sort keys %{$FieldTypeConfig} ) {
        push(@FieldTypes, {
            Name        => $FieldType,
            DisplayName => $FieldTypeConfig->{$FieldType}->{DisplayName},
        });
    }

    if ( scalar(@FieldTypes) == 1 ) {
        return $Self->_Success(
            DynamicFieldType => $FieldTypes[0],
        );
    }

    # return result
    return $Self->_Success(
        DynamicFieldType => \@FieldTypes,
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
