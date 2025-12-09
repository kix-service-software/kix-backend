# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::TicketStateUpdateOnExternalNote;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Cache
    Config
    Log
    Queue
    Ticket
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data Event UserID)) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # handle only events with given TicketID
    return 1 if ( !$Param{Data}->{TicketID} );

    # remember CacheInMemory state
    my $CacheInMemory = $Kernel::OM->Get('Cache')->{CacheInMemory};

    # enable CacheInMemory
    $Kernel::OM->Get('Cache')->Configure(
        CacheInMemory  => 1,
    );

    # reset protection: check if state was just set, dont reset directly
    my $ResetProtection = $Kernel::OM->Get('Cache')->Get(
        Type           => 'TicketStateUpdateOnExternalNote',
        Key            => 'ResetProtection::' . $Param{Data}->{TicketID},
        CacheInMemory  => 1,
        CacheInBackend => 0,
        NoStatsUpdate  => 1,
    );
    if ( $ResetProtection ) {
        # restore CacheInMemory
        $Kernel::OM->Get('Cache')->Configure(
            CacheInMemory  => $CacheInMemory,
        );

        return 1;
    }

    # register state update and ticket create for reset protection
    if (
        $Param{Event} eq 'TicketCreate'
        || $Param{Event} eq 'TicketStateUpdate'
    ) {
        $Kernel::OM->Get('Cache')->Set(
            Type           => 'TicketStateUpdateOnExternalNote',
            Key            => 'ResetProtection::' . $Param{Data}->{TicketID},
            Value          => 1,
            TTL            => 0,
            CacheInMemory  => 1,
            CacheInBackend => 0,
            NoStatsUpdate  => 1,
        );

        # restore CacheInMemory
        $Kernel::OM->Get('Cache')->Configure(
            CacheInMemory  => $CacheInMemory,
        );

        return 1;
    }

    # restore CacheInMemory
    $Kernel::OM->Get('Cache')->Configure(
        CacheInMemory  => $CacheInMemory,
    );

    # check preconditions
    return 1 if ( $Param{Event} ne 'ArticleCreate' );
    return 1 if ( !$Param{Data}->{ArticleID} );

    # get article data to check for external note
    my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
        ArticleID     => $Param{Data}->{ArticleID},
        DynamicFields => 0,
        UserID        => 1,
    );
    return 1 if (
        $Article{Channel} ne 'note'
        || $Article{SenderType} ne 'external'
    );

    # get ticket data
    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        DynamicFields => 0,
        UserID        => 1,
    );

    # check for possible followup, when ticket is closed
    if ( $Ticket{StateType} =~ /^(removed|close)/i ) {
        # get follow up option (possible or not)
        my $FollowUpPossible = $Kernel::OM->Get('Queue')->GetFollowUpOption(
            QueueID => $Ticket{QueueID},
        );
        return 1 if ( $FollowUpPossible ne 'possible' );
    }

    # prepare followup state
    my $State = $Kernel::OM->Get('Config')->Get('PostmasterFollowUpState') || 'open';

    if (
        $Ticket{StateType} =~ /^close/
        && $Kernel::OM->Get('Config')->Get('PostmasterFollowUpStateClosed')
    ) {
        $State = $Kernel::OM->Get('Config')->Get('PostmasterFollowUpStateClosed');
    }

    my $NextStateRef = $Kernel::OM->Get('Config')->Get('TicketStateWorkflow::PostmasterFollowUpState');
    if (
        $NextStateRef->{ $Ticket{Type} . ':::' . $Ticket{State} }
        || $NextStateRef->{ $Ticket{State} }
    ) {
        $State = $NextStateRef->{ $Ticket{Type} . ':::' . $Ticket{State} }
            || $NextStateRef->{ $Ticket{State} }
            || $NextStateRef->{q{}};
    }

    # set followup state
    if ( $State ) {
        $Kernel::OM->Get('Ticket')->TicketStateSet(
            State    => $State,
            TicketID => $Param{Data}->{TicketID},
            UserID   => 1,
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
