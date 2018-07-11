# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ChecklistUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ChecklistUpdate - API ChecklistUpdate Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ChecklistUpdate');

    return $Self;
}

=item Run()

perform TicketChecklistUpdate Operation. This will return the updated ChecklistItemID

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 123,                                                  # required
            ChecklistItemID  => 123',                                          # required            
            ChecklistItem => {                                                 # required
                Text     => '...',
                State    => 'open',
                Position => 1,
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ChecklistItemID => 123,                 # ID of changed item
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # get possible item states
    my $PossibleItemStates = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::KIXSidebarChecklist')->{ItemState};
    my @PossibleItemStates = sort keys %{$PossibleItemStates};

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'TicketID' => {
                Required => 1
            },
            'ChecklistItem' => {
                Type     => 'HASH',
                Required => 1
            },
            'ChecklistItem::Text' => {
                RequiresValueIfUsed => 1,
            },
            'ChecklistItem::State' => {
                RequiresValueIfUsed => 1,
                OneOf    => \@PossibleItemStates,
            },
            'ChecklistItem::Position' => {
                RequiresValueIfUsed => 1,
                Format   => '^(\d+)$',
            },            
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    if ( $Self->{Authorization}->{UserType} eq 'Customer' ) {
        # customers are not allowed to update articles
        return $Self->_Error(
            Code    => 'Forbidden',
            Message => 'No permission to update article flag!',
        );        
    }

    # check write permission
    my $Permission = $Self->CheckWritePermission(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to update checkliste item",
        );
    }

    # check if checklist item exists
    my $Checklist = $Kernel::OM->Get('Kernel::System::Ticket')->TicketChecklistGet(
        TicketID => $Param{Data}->{TicketID},
        Result   => 'ID',
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !IsHashRefWithData($Checklist) || !$Checklist->{$Param{Data}->{ChecklistItemID}}) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Checklist item $Param{Data}->{ChecklistItemID} not found in ticket $Param{Data}->{TicketID}",
        );
    }

    # isolate and trim ChecklistItem parameter
    my $ChecklistItem = $Self->_Trim(
        Data => $Param{Data}->{ChecklistItem},
    );

    my $ChecklistItemID = $Kernel::OM->Get('Kernel::System::Ticket')->TicketChecklistItemUpdate(
        TicketID   => $Param{Data}->{TicketID},
        ItemID     => $Param{Data}->{ChecklistItemID},
        Text       => $ChecklistItem->{Text} || $Checklist->{$Param{Data}->{ChecklistItemID}}->{Text},
        State      => $ChecklistItem->{State} || $Checklist->{$Param{Data}->{ChecklistItemID}}->{State},
        Position   => $ChecklistItem->{Position} || $Checklist->{$Param{Data}->{ChecklistItemID}}->{Position},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$ChecklistItemID ) {
        return $Self->_Error(
            Code         => 'Object.UnableToUpdate',
            Message      => "Unable to update checklist item $Param{Data}->{ChecklistItemID}",
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