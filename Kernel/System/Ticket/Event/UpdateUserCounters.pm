# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::UpdateUserCounters;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::AsynchronousExecutor
);

our @ObjectDependencies = (
    'ITSMConfigItem',
    'Log',
);

=head1 NAME

Kernel::System::Ticket::Event::UpdateUserCounters - Event handler to update user counters

=head1 SYNOPSIS

All event handler functions for user counters.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $UpdateCountersObject = $Kernel::OM->Get('Ticket::Event::UpdateUser
    Counters');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

This method handles the event.

    $DoHistoryObject->Run(
        Event => 'TicketCreate',
        Data  => {
            TicketID => 123
        },
        UserID => 1,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data Event UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( $Param{Event} ne 'TicketDelete' ) {
        my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID => $Param{Data}->{TicketID},
        );
        return if !%Ticket;

        $Param{Ticket} = \%Ticket;

        $Self->{ViewableStates} = {
            reverse $Kernel::OM->Get('State')->StateGetStatesByType(
                Type   => 'Viewable',
                Result => 'HASH',
            )
        };

        if ( !$Self->{ViewableStates}->{$Ticket{State}} ) {
            # delete all user counters for this object for the ticket owner and leave
            $Kernel::OM->Get('User')->DeleteUserCounterObject(
                Category => 'Ticket',
                ObjectID => $Param{Data}->{TicketID},
                UserID   => $Ticket{OwnerID}
            );
            return 1;
        }
    }

    # handle ticket events to update ticket counters:
    # - Owned
    # - OwnedAndUnseen
    # - OwnedAndLocked
    # - OwnedAndLockedAndUnseen
    # - Watched
    # - WatchedAndUnseen

    my $Function = 'Handle'.$Param{Event};
    return $Self->$Function(%Param);

}

sub HandleTicketCreate {
    my ($Self, %Param) = @_;

    $Kernel::OM->Get('User')->AddUserCounterObject(
        Category => 'Ticket',
        Counter  => 'Owned',
        ObjectID => $Param{Ticket}->{TicketID},
        UserID   => $Param{Ticket}->{OwnerID}
    );

    my $IsSeen = $Kernel::OM->Get('Ticket')->TicketUserFlagExists(
        TicketID => $Param{Ticket}->{TicketID},
        Flag     => 'Seen',
        UserID   => $Param{Ticket}->{OwnerID},
    );
    if ( !$IsSeen ) {
        $Kernel::OM->Get('User')->AddUserCounterObject(
            Category => 'Ticket',
            Counter  => 'OwnedAndUnseen',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{Ticket}->{OwnerID}
        );
    }

    if ( $Param{Ticket}->{Lock} eq 'lock' ) {
        $Kernel::OM->Get('User')->AddUserCounterObject(
            Category => 'Ticket',
            Counter  => 'OwnedAndLocked',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{Ticket}->{OwnerID}
        );
        if ( !$IsSeen ) {
            # add for new owner
            $Kernel::OM->Get('User')->AddUserCounterObject(
                Category => 'Ticket',
                Counter  => 'OwnedAndLockedAndUnseen',
                ObjectID => $Param{Ticket}->{TicketID},
                UserID   => $Param{Ticket}->{OwnerID}
            );
        }
    }

    return 1;
}

sub HandleTicketDelete {
    my ($Self, %Param) = @_;

    # delete all user counters for this object for all users (the object simply doesn't exist anymore)
    $Kernel::OM->Get('User')->DeleteUserCounterObject(
        Category => 'Ticket',
        ObjectID => $Param{Data}->{TicketID},
    );

    return 1;
}

sub HandleTicketStateUpdate {
    my ($Self, %Param) = @_;

    $Self->HandleTicketCreate(
        %Param,
    );
    $Self->HandleTicketSubscribe(
        %Param,
        Data => {
            WatchUserID => $Param{UserID}
        }
    );

    return 1;
}

sub HandleTicketFlagSet {
    my ($Self, %Param) = @_;

    my ( $OwnerID, $Owner ) = $Kernel::OM->Get('Ticket')->OwnerCheck(
        TicketID => $Param{Ticket}->{TicketID}
    );

    if ( $Param{Data}->{Key} eq 'Seen' && $OwnerID == $Param{UserID} ) {
        $Kernel::OM->Get('User')->DeleteUserCounterObject(
            Category => 'Ticket',
            Counter  => '*AndUnseen',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $OwnerID
        );
    }

    my $IsWatched = $Kernel::OM->Get('Watcher')->WatcherLookup(
        Object      => 'Ticket',
        ObjectID    => $Param{Ticket}->{TicketID},
        WatchUserID => $Param{UserID},
    );
    if ( $IsWatched ) {
        $Kernel::OM->Get('User')->DeleteUserCounterObject(
            Category => 'Ticket',
            Counter  => 'WatchedAndUnseen',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{UserID}
        );
    }

    return 1;
}

sub HandleTicketFlagDelete {
    my ($Self, %Param) = @_;

    return 1 if lc $Param{Data}->{Key} ne 'seen';

    if ( $Param{Ticket}->{OwnerID} == $Param{Data}->{UserID} ) {
        $Kernel::OM->Get('User')->AddUserCounterObject(
            Category => 'Ticket',
            Counter  => 'OwnedAndUnseen',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{Ticket}->{OwnerID}
        );

        if ( $Param{Ticket}->{Lock} eq 'lock' ) {
            $Kernel::OM->Get('User')->AddUserCounterObject(
                Category => 'Ticket',
                Counter  => 'OwnedAndLockedAndUnseen',
                ObjectID => $Param{Ticket}->{TicketID},
                UserID   => $Param{Ticket}->{OwnerID}
            );
        }
    }

    my $IsWatched = $Kernel::OM->Get('Watcher')->WatcherLookup(
        Object      => 'Ticket',
        ObjectID    => $Param{Ticket}->{TicketID},
        WatchUserID => $Param{UserID},
    );
    if ( $IsWatched ) {
        $Kernel::OM->Get('User')->AddUserCounterObject(
            Category => 'Ticket',
            Counter  => 'WatchedAndUnseen',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{UserID}
        );
    }

    return 1;
}

sub HandleTicketLockUpdate {
    my ($Self, %Param) = @_;

    if ( $Param{Data}->{Lock} eq 'lock' ) {
        $Kernel::OM->Get('User')->AddUserCounterObject(
            Category => 'Ticket',
            Counter  => 'OwnedAndLocked',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{Ticket}->{OwnerID}
        );
        my $IsSeen = $Kernel::OM->Get('Ticket')->TicketUserFlagExists(
            TicketID => $Param{Ticket}->{TicketID},
            Flag     => 'Seen',
            UserID   => $Param{Ticket}->{OwnerID},
        );
        if ( !$IsSeen ) {
            $Kernel::OM->Get('User')->AddUserCounterObject(
                Category => 'Ticket',
                Counter  => 'OwnedAndLockedAndUnseen',
                ObjectID => $Param{Ticket}->{TicketID},
                UserID   => $Param{Ticket}->{OwnerID}
            );
        }
    }
    else {
        $Kernel::OM->Get('User')->DeleteUserCounterObject(
            Category => 'Ticket',
            Counter  => 'OwnedAndLocked',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{Ticket}->{OwnerID}
        );
        $Kernel::OM->Get('User')->DeleteUserCounterObject(
            Category => 'Ticket',
            Counter  => 'OwnedAndLockedAndUnseen',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{Ticket}->{OwnerID}
        );
    }

    return 1;
}

sub HandleTicketOwnerUpdate {
    my ($Self, %Param) = @_;

    # add for new owner
    $Kernel::OM->Get('User')->AddUserCounterObject(
        Category => 'Ticket',
        Counter  => 'Owned',
        ObjectID => $Param{Ticket}->{TicketID},
        UserID   => $Param{Ticket}->{OwnerID}
    );
    # delete for previous owner
    $Kernel::OM->Get('User')->DeleteUserCounterObject(
        Category => 'Ticket',
        Counter  => 'Owned*',
        ObjectID => $Param{Ticket}->{TicketID},
        UserID   => $Param{Data}->{PreviousOwnerID}
    );

    my $IsSeen = $Kernel::OM->Get('Ticket')->TicketUserFlagExists(
        TicketID => $Param{Ticket}->{TicketID},
        Flag     => 'Seen',
        UserID   => $Param{Ticket}->{OwnerID},
    );
    if ( !$IsSeen ) {
        $Kernel::OM->Get('User')->AddUserCounterObject(
            Category => 'Ticket',
            Counter  => 'OwnedAndUnseen',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{Ticket}->{OwnerID}
        );
    }

    if ( $Param{Ticket}->{Lock} eq 'lock' ) {
        # add for new owner
        $Kernel::OM->Get('User')->AddUserCounterObject(
            Category => 'Ticket',
            Counter  => 'OwnedAndLocked',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{Ticket}->{OwnerID}
        );

        if ( !$IsSeen ) {
            # add for new owner
            $Kernel::OM->Get('User')->AddUserCounterObject(
                Category => 'Ticket',
                Counter  => 'OwnedAndLockedAndUnseen',
                ObjectID => $Param{Ticket}->{TicketID},
                UserID   => $Param{Ticket}->{OwnerID}
            );
        }
    }

    return 1;
}

sub HandleTicketSubscribe {
    my ($Self, %Param) = @_;

    my $IsWatched = $Kernel::OM->Get('Watcher')->WatcherLookup(
        Object      => 'Ticket',
        ObjectID    => $Param{Ticket}->{TicketID},
        WatchUserID => $Param{Data}->{WatchUserID}
    );
    return if !$IsWatched;

    $Kernel::OM->Get('User')->AddUserCounterObject(
        Category => 'Ticket',
        Counter  => 'Watched',
        ObjectID => $Param{Ticket}->{TicketID},
        UserID   => $Param{Data}->{WatchUserID}
    );

    my $IsSeen = $Kernel::OM->Get('Ticket')->TicketUserFlagExists(
        TicketID => $Param{Ticket}->{TicketID},
        Flag     => 'Seen',
        UserID   => $Param{Data}->{WatchUserID},
    );
    if ( !$IsSeen ) {
        $Kernel::OM->Get('User')->AddUserCounterObject(
            Category => 'Ticket',
            Counter  => 'WatchedAndUnseen',
            ObjectID => $Param{Ticket}->{TicketID},
            UserID   => $Param{Data}->{WatchUserID}
        );
    }

    return 1;
}

sub HandleTicketUnsubscribe {
    my ($Self, %Param) = @_;

    $Kernel::OM->Get('User')->DeleteUserCounterObject(
        Category => 'Ticket',
        Counter  => 'Watched*',
        ObjectID => $Param{Ticket}->{TicketID},
        UserID   => $Param{Data}->{WatchUserID}
    );

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



