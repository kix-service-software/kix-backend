# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2022 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::ForceOwnerAndResponsibleResetOnMissingPermission;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Log',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    for (qw(TicketID)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{Data}->{TicketID}
    );
    if ( !%Ticket ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Ticket with ID $Param{Data}->{TicketID} not found!"
        );
        return;
    }

    # check permission
    my %HasPermission;

    TYPE:
    foreach my $Type ( qw(Owner Responsible) ) {
        # check resource permission
        my ($Granted) = $Kernel::OM->Get('User')->CheckResourcePermission(
            UserID              => $Ticket{$Type.'ID'},
            Target              => '/tickets',
            RequestedPermission => 'UPDATE',
            UsageContext        => 'Agent'
        );
        next TYPE if !$Granted;

        # check base permission
        my $Result = $Kernel::OM->Get('Ticket')->BasePermissionRelevantObjectIDList(
            UserID       => $Ticket{$Type.'ID'},
            UsageContext => 'Agent',
            Permission   => 'UPDATE,READ',
        );
        next TYPE if !$Result;

        if ( IsArrayRefWithData($Result) ) {
            my %AllowedQueueIDs = map { $_ => 1 } @{$Result};
            next TYPE if !$AllowedQueueIDs{$Ticket{QueueID}};
        }
            
        $HasPermission{$Type} = 1;
    }

    if ( !$HasPermission{Owner} ) {
        # reset owner
        $TicketObject->TicketOwnerSet(
            TicketID           => $Param{Data}->{TicketID},
            NewUserID          => 1,
            SendNoNotification => 1,
            UserID             => 1,
        );
        # add history
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Data}->{TicketID},
            CreateUserID => 1,
            HistoryType  => 'Misc',
            Name         => "Reset owner due to missing permissions.",
        );
    }

    if ( !$HasPermission{Responsible} ) {
        # reset responsible
        $TicketObject->TicketResponsibleSet(
            TicketID           => $Param{Data}->{TicketID},
            NewUserID          => 1,
            SendNoNotification => 1,
            UserID             => 1,
        );
        # add history
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Data}->{TicketID},
            CreateUserID => 1,
            HistoryType  => 'Misc',
            Name         => "Reset responsible due to missing permissions.",
        );
    }

    if ( !$HasPermission{Owner} || !$HasPermission{Responsible} ) {
        # unlock ticket
        $TicketObject->TicketLockSet(
            TicketID           => $Param{Data}->{TicketID},
            Lock               => 'unlock',
            SendNoNotification => 1,
            UserID             => 1,
        );
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
