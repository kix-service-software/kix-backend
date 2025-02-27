# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::DynamicField::DynamicFieldConfigUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::DynamicField::DynamicFieldConfigUpdate - API DynamicField Update Operation backend

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
        },
        'DynamicFieldConfig' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform DynamicFieldConfigUpdate Operation. This will return the updated DynamicFieldID.

    my $Result = $OperationObject->Run(
        Data => {
            DynamicFieldID => 123,
            DynamicFieldConfig => {
                ...
            }
	    },
	);


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            DynamicFieldID  => 123,             # ID of the updated DynamicField
        },
    };

=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim DynamicFieldConfig parameter
    my $DynamicFieldConfig = $Self->_Trim(
        Data   => $Param{Data}->{DynamicFieldConfig},
        Ignore => {
            ItemSeparator => 1
        }
    );

    # check if DynamicField exists
    my $DynamicFieldData = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $Param{Data}->{DynamicFieldID},
    );

    if ( !IsHashRefWithData($DynamicFieldData) ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update DynamicField
    my $Success = $Kernel::OM->Get('DynamicField')->DynamicFieldUpdate(
        ID         => $Param{Data}->{DynamicFieldID},
        Name       => $DynamicFieldData->{Name},
        Label      => $DynamicFieldData->{Label},
        FieldType  => $DynamicFieldData->{FieldType},
        ObjectType => $DynamicFieldData->{ObjectType},
        Config     => $DynamicFieldConfig,
        ValidID    => $DynamicFieldData->{ValidID},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result
    return $Self->_Success(
        DynamicFieldID => $Param{Data}->{DynamicFieldID},
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
