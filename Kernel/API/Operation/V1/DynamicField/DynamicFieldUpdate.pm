# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::DynamicField::DynamicFieldUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::DynamicField::DynamicFieldUpdate - API DynamicField Update Operation backend

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
        'DynamicField' => {
            Type => 'HASH',
            Required => 1
        },
        'DynamicField::CustomerVisible' => {
            RequiresValueIfUsed => 1,
            OneOf => [0, 1]
        }
    }
}

=item Run()

perform DynamicFieldUpdate Operation. This will return the updated DynamicFieldID.

    my $Result = $OperationObject->Run(
        Data => {
            DynamicFieldID => 123,
            DynamicField   => {
                Name            => '...',            # optional
                Label           => '...',            # optional
                FieldType       => '...',            # optional
                ObjectType      => '...',            # optional
                Config          => { },              # optional
                CustomerVisible => 0                 # optional
                ValidID         => 1,                # optional
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

    # isolate and trim DynamicField parameter
    my $DynamicField = $Self->_Trim(
        Data => $Param{Data}->{DynamicField}
    );

    # check attribute values
    my $CheckResult = $Self->_CheckDynamicField(
        DynamicField => $DynamicField
    );

    if ( !$CheckResult->{Success} ) {
        return $Self->_Error(
            %{$CheckResult},
        );
    }

    # check if name is duplicated
    my %DynamicFieldsList = %{
        $Kernel::OM->Get('DynamicField')->DynamicFieldList(
            Valid      => 0,
            ResultType => 'HASH',
        )
    };

    %DynamicFieldsList = reverse %DynamicFieldsList;

    if ( $DynamicField->{Name} && $DynamicFieldsList{ $DynamicField->{Name} } && $DynamicFieldsList{ $DynamicField->{Name} } ne $Param{Data}->{DynamicFieldID} ) {

        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Cannot update DynamicField. Another DynamicField with the name already exists.',
        );
    }

    # check if DynamicField exists
    my $DynamicFieldData = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $Param{Data}->{DynamicFieldID},
    );

    if ( !IsHashRefWithData($DynamicFieldData) ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if df is writeable
    if ( $DynamicFieldData->{InternalField} == 1 ) {
        return $Self->_Error(
            Code    => 'Forbidden',
            Message => "Cannot update DynamicField. DynamicField with ID '$Param{Data}->{DynamicFieldID}' is internal and cannot be changed.",
        );
    }

    # needed if internal fields can be update (if check above is deactived or removed)
    # if it's an internal field, it's name should not change
    if ( $DynamicField->{Name} && $DynamicFieldData->{InternalField} && $DynamicField->{Name} ne $DynamicFieldData->{Name} ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Cannot update name of DynamicField, because it is an internal field.',
        );
    }

    # update DynamicField
    my $Success = $Kernel::OM->Get('DynamicField')->DynamicFieldUpdate(
        ID              => $Param{Data}->{DynamicFieldID},
        Name            => $DynamicField->{Name} || $DynamicFieldData->{Name},
        Label           => $DynamicField->{Label} || $DynamicFieldData->{Label},
        FieldType       => $DynamicField->{FieldType} || $DynamicFieldData->{FieldType},
        ObjectType      => $DynamicField->{ObjectType} || $DynamicFieldData->{ObjectType},
        Config          => $DynamicField->{Config} || $DynamicFieldData->{Config},
        CustomerVisible => exists $DynamicField->{CustomerVisible} ? $DynamicField->{CustomerVisible} : $DynamicFieldData->{CustomerVisible},
        ValidID         => $DynamicField->{ValidID} || $DynamicFieldData->{ValidID},
        UserID          => $Self->{Authorization}->{UserID},
        Comment         => exists $DynamicField->{Comment} ? $DynamicField->{Comment} : $DynamicFieldData->{Comment}
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate'
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
