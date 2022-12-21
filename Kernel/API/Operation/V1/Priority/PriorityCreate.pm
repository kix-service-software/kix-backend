# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Priority::PriorityCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Priority::PriorityCreate - API Priority PriorityCreate Operation backend

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
        'Priority' => {
            Type     => 'HASH',
            Required => 1
        },
        'Priority::Name' => {
            Required => 1
        },
    }
}

=item Run()

perform PriorityCreate Operation. This will return the created PriorityID.

    my $Result = $OperationObject->Run(
        Data => {
            Priority => (
                Name    => '...',
                ValidID => 1,                   # optional
            },
        },
    );

    $Result = {
        Success      => 1,                       # 0 or 1
        Code         => '',                      #
        Message      => '',                      # in case of error
        Data         => {                        # result data payload after Operation
            PriorityID  => '',                   # PriorityID
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Priority parameter
    my $Priority = $Self->_Trim(
        Data => $Param{Data}->{Priority}
    );

    # get relevant function
    my $PriorityID;

    # check if Priority exists
    my $Exists = $Kernel::OM->Get('Priority')->PriorityLookup(
        Priority => $Priority->{Name},
        Silent   => 1
    );

    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create Priority. Priority with the name '$Priority->{Name}' already exists.",
        );
    }

    # create Priority
    $PriorityID = $Kernel::OM->Get('Priority')->PriorityAdd(
        Name    => $Priority->{Name},
        Comment => $Priority->{Comment},
        ValidID => $Priority->{ValidID} || 1,
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$PriorityID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create priority, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        PriorityID => $PriorityID,
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
