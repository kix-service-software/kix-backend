# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectIcon::ObjectIconCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectIcon::ObjectIconCreate - API ObjectIcon ObjectIconCreate Operation backend

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
        'ObjectIcon' => {
            Type => 'HASH',
            Required => 1
        },
        'ObjectIcon::Object' => {
            Required => 1
        },
        'ObjectIcon::ObjectID' => {
            Required => 1
        },
        'ObjectIcon::ContentType' => {
            Required => 1
        },
        'ObjectIcon::Content' => {
            Required => 1
        },
    }
}

=item Run()

perform ObjectIconCreate Operation. This will return the created ObjectIconID.

    my $Result = $OperationObject->Run(
        Data => {
        	ObjectIcon => {
                Object      => '...',
                ObjectID    => '...',
                ContentType => '...',
                Content     => '...'
            }
	    },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ObjectIconID  => '',                          # ID of the created ObjectIcon
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

     # isolate and trim ObjectIcon parameter
    my $ObjectIcon = $Self->_Trim(
        Data => $Param{Data}->{ObjectIcon},
    );

    # check if ObjectIcon exists
    my $ObjectIconList = $Kernel::OM->Get('ObjectIcon')->ObjectIconList(
        Object   => $ObjectIcon->{Object},
        ObjectID => $ObjectIcon->{ObjectID},
    );

    if ( IsArrayRefWithData($ObjectIconList) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create ObjectIcon. Another ObjectIcon with the same Object and ObjectID already exists.",
        );
    }

    # create ObjectIcon
    my $ObjectIconID = $Kernel::OM->Get('ObjectIcon')->ObjectIconAdd(
        Object      => $ObjectIcon->{Object},
        ObjectID    => $ObjectIcon->{ObjectID},
        ContentType => $ObjectIcon->{ContentType},
        Content     => $ObjectIcon->{Content},
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$ObjectIconID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create ObjectIcon, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        ObjectIconID => $ObjectIconID,
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
