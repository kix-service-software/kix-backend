# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::DynamicField::DynamicFieldConfigGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::DynamicField::DynamicFieldConfigGet - API DynamicField Get Operation backend

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
            Required => 1
        }
    }
}

=item Run()

perform DynamicFieldConfigGet Operation.

    my $Result = $OperationObject->Run(
        Data => {
            DynamicFieldID => 123
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            DynamicFieldConfig => {
                ...
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get the DynamicField data
    my $DynamicFieldData = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $Param{Data}->{DynamicFieldID}
    );

    if ( !IsHashRefWithData( $DynamicFieldData ) ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # return result
    return $Self->_Success(
        DynamicFieldConfig => $DynamicFieldData->{Config},
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
