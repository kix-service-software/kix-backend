# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectTag::ObjectTagCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectTag::ObjectTagCreate - API ObjectTag ObjectTagCreate Operation backend

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
        'ObjectTag' => {
            Type => 'HASH',
            Required => 1
        },
        'ObjectTag::Name' => {
            Required => 1
        },
        'ObjectTag::ObjectID' => {
            Required => 1
        },
        'ObjectTag::ObjectType' => {
            Required => 1
        }
    }
}

=item Run()

perform ObjectTagCreate Operation. This will return the created ObjectTagID.

    my $Result = $OperationObject->Run(
        Data => {
            ObjectTag  => '...',
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ObjectTagID  => '',                          # ID of the created ObjectTag
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ObjectTag parameter
    my $ObjectTag = $Self->_Trim(
        Data => $Param{Data}->{ObjectTag},
    );

    # check if ObjectTag exists
    my $ObjectTagID = $Kernel::OM->Get('ObjectTag')->ObjectTagExists(
        Name       => $ObjectTag->{Name},
        ObjectID   => $ObjectTag->{ObjectID},
        ObjectType => $ObjectTag->{ObjectType},
    );

    if ( $ObjectTagID ) {
        return $Self->_Success(
            Code        => 'Object.Created',
            ObjectTagID => $ObjectTagID,
        );
    }

    # create ObjectTag
    $ObjectTagID = $Kernel::OM->Get('ObjectTag')->ObjectTagAdd(
        Name       => $ObjectTag->{Name},
        ObjectID   => $ObjectTag->{ObjectID},
        ObjectType => $ObjectTag->{ObjectType},
        UserID     => $Self->{Authorization}->{UserID}
    );

    if ( !$ObjectTagID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create ObjectTag, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code        => 'Object.Created',
        ObjectTagID => $ObjectTagID,
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
