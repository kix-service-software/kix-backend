# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my @TicketIDs;
my @TestUserIDs;
for ( 1 .. 2 ) {

    my $TestUserLogin = $Helper->TestUserCreate(
        Groups => [ 'users', ],
    );
    my $TestUserID = $Kernel::OM->Get('User')->UserLookup(
        UserLogin => $TestUserLogin,
    );

    push @TestUserIDs, $TestUserID;

    # create a new ticket
    my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title        => 'My ticket for watching',
        Queue        => 'Junk',
        Lock         => 'unlock',
        Priority     => '3 normal',
        State        => 'open',
        ContactID    => 'customer@example.com',
        OrgansationID => 'example.com',
        OwnerID      => 1,
        UserID       => 1,
    );

    $Self->True(
        $TicketID,
        "Ticket created for test - $TicketID",
    );
    push( @TicketIDs, $TicketID );
}

my $Subscribe = $Kernel::OM->Get('Watcher')->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketIDs[0],
    WatchUserID => $TestUserIDs[0],
    UserID      => 1,
);
$Self->True(
    $Subscribe || 0,
    'WatcherAdd() - first ticket, first user',
);
my $Unsubscribe = $Kernel::OM->Get('Watcher')->WatcherDelete(
    Object      => 'Ticket',
    ObjectID    => $TicketIDs[0],
    WatchUserID => $TestUserIDs[0],
    UserID      => 1,
);
$Self->True(
    $Unsubscribe || 0,
    'WatcherDelete() - first ticket, first user',
);

# add new subscription (will be deleted by TicketDelete(), also check foreign keys)
$Subscribe = $Kernel::OM->Get('Watcher')->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketIDs[0],
    WatchUserID => $TestUserIDs[0],
    UserID      => 1,
);
$Self->True(
    $Subscribe || 0,
    'WatcherAdd() - first ticket, first user',
);

# subscribe first ticket with second user
$Subscribe = $Kernel::OM->Get('Watcher')->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketIDs[0],
    WatchUserID => $TestUserIDs[1],
    UserID      => 1,
);
$Self->True(
    $Subscribe || 0,
    'WatcherAdd() - first ticket, second user',
);

# subscribe second ticket with second user
$Subscribe = $Kernel::OM->Get('Watcher')->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketIDs[1],
    WatchUserID => $TestUserIDs[1],
    UserID      => 1,
);
$Self->True(
    $Subscribe || 0,
    'WatcherAdd() - second ticket, second user',
);

my @WatcherList = $Kernel::OM->Get('Watcher')->WatcherList(
    Object   => 'Ticket',
    ObjectID => $TicketIDs[0],
);
my %Watchers = map { $_->{UserID} => $_ } @WatcherList;
$Self->True(
    $Watchers{ $TestUserIDs[0] } || 0,
    'WatcherList() - first ticket, first user',
);
$Self->True(
    $Watchers{ $TestUserIDs[1] },
    'WatcherList() - first ticket, second user',
);

@WatcherList = $Kernel::OM->Get('Watcher')->WatcherList(
    Object   => 'Ticket',
    ObjectID => $TicketIDs[1],
);
%Watchers = map { $_->{UserID} => $_ } @WatcherList;
$Self->False(
    $Watchers{ $TestUserIDs[0] } || 0,
    'WatcherList() - second ticket, first user',
);
$Self->True(
    $Watchers{ $TestUserIDs[1] },
    'WatcherList() - second ticket, second user',
);

my $Transfer = $Kernel::OM->Get('Watcher')->WatcherTransfer(
    Object         => 'Ticket',
    SourceObjectID => $TicketIDs[0],
    TargetObjectID => $TicketIDs[1],
    KeepSource     => 1,
);
$Self->True(
    $Transfer || 0,
    'WatcherTransfer() - first ticket to second ticket, keep source',
);

@WatcherList = $Kernel::OM->Get('Watcher')->WatcherList(
    Object   => 'Ticket',
    ObjectID => $TicketIDs[0],
);
%Watchers = map { $_->{UserID} => $_ } @WatcherList;
$Self->True(
    $Watchers{ $TestUserIDs[0] } || 0,
    'WatcherList() - first ticket, first user',
);
$Self->True(
    $Watchers{ $TestUserIDs[1] },
    'WatcherList() - first ticket, second user',
);

@WatcherList = $Kernel::OM->Get('Watcher')->WatcherList(
    Object   => 'Ticket',
    ObjectID => $TicketIDs[1],
);
%Watchers = map { $_->{UserID} => $_ } @WatcherList;
$Self->True(
    $Watchers{ $TestUserIDs[0] } || 0,
    'WatcherList() - second ticket, first user',
);
$Self->True(
    $Watchers{ $TestUserIDs[1] },
    'WatcherList() - second ticket, second user',
);

$Unsubscribe = $Kernel::OM->Get('Watcher')->WatcherDelete(
    Object   => 'Ticket',
    ObjectID => $TicketIDs[0],
    UserID   => 1,
    AllUsers => 1
);
$Self->True(
    $Unsubscribe || 0,
    'WatcherDelete() - first ticket, all users',
);

@WatcherList = $Kernel::OM->Get('Watcher')->WatcherList(
    Object   => 'Ticket',
    ObjectID => $TicketIDs[0],
);
%Watchers = map { $_->{UserID} => $_ } @WatcherList;
$Self->False(
    $Watchers{ $TestUserIDs[0] } || 0,
    'WatcherList() - first ticket, first user',
);
$Self->False(
    $Watchers{ $TestUserIDs[1] },
    'WatcherList() - first ticket, second user',
);

$Transfer = $Kernel::OM->Get('Watcher')->WatcherTransfer(
    Object         => 'Ticket',
    SourceObjectID => $TicketIDs[1],
    TargetObjectID => $TicketIDs[0],
);
$Self->True(
    $Transfer || 0,
    'WatcherTransfer() - second ticket to first ticket',
);

@WatcherList = $Kernel::OM->Get('Watcher')->WatcherList(
    Object   => 'Ticket',
    ObjectID => $TicketIDs[0],
);
%Watchers = map { $_->{UserID} => $_ } @WatcherList;
$Self->True(
    $Watchers{ $TestUserIDs[0] } || 0,
    'WatcherList() - first ticket, first user',
);
$Self->True(
    $Watchers{ $TestUserIDs[1] },
    'WatcherList() - first ticket, second user',
);

@WatcherList = $Kernel::OM->Get('Watcher')->WatcherList(
    Object   => 'Ticket',
    ObjectID => $TicketIDs[1],
);
%Watchers = map { $_->{UserID} => $_ } @WatcherList;
$Self->False(
    $Watchers{ $TestUserIDs[0] } || 0,
    'WatcherList() - second ticket, first user',
);
$Self->False(
    $Watchers{ $TestUserIDs[1] },
    'WatcherList() - second ticket, second user',
);

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
