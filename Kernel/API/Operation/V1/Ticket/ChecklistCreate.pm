# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ChecklistCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ChecklistCreate - API ChecklistCreate Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketChecklistCreate');

    return $Self;
}

=item Run()

perform ChecklistCreate Operation. This will return the created ChecklistItemID

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 123,                                                  # required
            ChecklistItem => {                                                 # required
                Text     => '...',
                Position => 1,
                State    => 'open',
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ChecklistItemID => 1
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
                Required => 1
            },
            'ChecklistItem::State' => {
                OneOf    => \@PossibleItemStates,
                Required => 1
            },
            'ChecklistItem::Position' => {
                Required => 1,
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

    # check write permission
    my $Permission = $Self->CheckWritePermission(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to create checklist!",
        );
    }

    # isolate and trim ChecklistItem parameter
    my $ChecklistItem = $Self->_Trim(
        Data => $Param{Data}->{ChecklistItem},
    );

    my $ChecklistItemID = $Kernel::OM->Get('Kernel::System::Ticket')->TicketChecklistItemCreate(
        TicketID   => $Param{Data}->{TicketID},
        Text       => $ChecklistItem->{Text},
        State      => $ChecklistItem->{State},
        Position   => $ChecklistItem->{Position},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$ChecklistItemID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create checklist item, please contact the system administrator',
        );
    }

    return $Self->_Success(
        Code            => 'Object.Created',
        ChecklistItemID => $ChecklistItemID,
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
