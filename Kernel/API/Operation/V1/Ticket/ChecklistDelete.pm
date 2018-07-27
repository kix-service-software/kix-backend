# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ChecklistDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ChecklistDelete - API ChecklistDelete Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ChecklistDelete');

    return $Self;
}

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
        'TicketID' => {
            Required => 1
        },
        'ChecklistItemID' => {
            Required => 1
        },
    }
}

=item Run()

perform ChecklistDelete Operation. This will return the deleted ChecklistItemID.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID          => 123,                                           # required
            ChecklistItemID   => 1                                              # required
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ChecklistItemID   => 123,               # ID of deleted item
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check delete permission
    my $Permission = $Self->CheckWritePermission(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to delete checklist item.",
        );
    }

    # check if checklist item exists
    my $Checklist = $Kernel::OM->Get('Kernel::System::Ticket')->TicketChecklistGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !IsHashRefWithData($Checklist) || !$Checklist->{$Param{Data}->{ChecklistItemID}}) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Checklist item $Param{Data}->{ChecklistItemID} not found in ticket $Param{Data}->{TicketID}",
        );
    }

    my $Success = $Kernel::OM->Get('Kernel::System::Ticket')->TicketChecklistItemDelete(
        ItemID => $Param{Data}->{ChecklistItemID}
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToDelete',
            Message => 'Unable to to delete checklist item, please contact system administrator!',
        );
    }

    return $Self->_Success(
        ChecklistItemID => $Param{Data}->{ChecklistItemID},
    );
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
