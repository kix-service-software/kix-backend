# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::DynamicField::DynamicFieldCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::DynamicField::DynamicFieldCreate - API DynamicField Create Operation backend

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
        'DynamicField' => {
            Type => 'HASH',
            Required => 1
        },
        'DynamicField::Name' => {
            Required => 1
        },
        'DynamicField::Label' => {
            Required => 1
        },
        'DynamicField::FieldType' => {
            Required => 1
        },
        'DynamicField::ObjectType' => {
            Required => 1
        },
        'DynamicField::Config' => {
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

perform DynamicFieldCreate Operation. This will return the created DynamicFieldID.

    my $Result = $OperationObject->Run(
        Data => {
            DynamicFieldID => 123,
            DynamicField   => {
                Name            => '...',
                Label           => '...',
                Comment         => '...'
                FieldType       => '...',
                ObjectType      => '...',
                Config          => { },
                CustomerVisible => 0,
                InternalField   => 0|1,              # optional
                ValidID         => 1,                # optional
            }
        },
    );


    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            DynamicFieldID  => 123,             # ID of the Created DynamicField
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

    if ( $DynamicFieldsList{ $DynamicField->{Name} } ) {

        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Cannot create DynamicField. Another DynamicField with the name already exists.',
        );
    }

    # create DynamicField
    my $ID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name            => $DynamicField->{Name},
        Label           => $DynamicField->{Label},
        InternalField   => $DynamicField->{InternalField} || 0,
        FieldType       => $DynamicField->{FieldType},
        ObjectType      => $DynamicField->{ObjectType},
        Config          => $DynamicField->{Config},
        CustomerVisible => $DynamicField->{CustomerVisible},
        ValidID         => $DynamicField->{ValidID} || 1,
        UserID          => $Self->{Authorization}->{UserID},
        Comment         => $DynamicField->{Comment} || ''
    );

    if ( !$ID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create DynamicField, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code           => 'Object.Created',
        DynamicFieldID => $ID,
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
