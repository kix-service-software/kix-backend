# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

use Kernel::System::Role::Permission;
use Kernel::System::VariableCheck qw(:all);

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create a new users for current test
my $UserLogin1 = $Helper->TestUserCreate(
    Roles => ["Ticket Agent"],
);
my %UserData1 = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin1,
);
my $UserID1 = $UserData1{UserID};

my $UserLogin2 = $Helper->TestUserCreate(
    Roles => ["Ticket Agent"],
);
my %UserData2 = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin2,
);
my $UserID2 = $UserData2{UserID};

# create ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'User Counter Test',
    QueueID        => 1,
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'new',
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => $UserID1,
    UserID         => 1,
);

# sanity check
$Self->True(
    $TicketID,
    "TicketCreate() successful for Ticket ID $TicketID",
);

# check counters
my %Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID1
);
$Self->Is(
    $Counters{Ticket}->{Owned},
    1,
    "Counter \"Owned\" (UserID: $UserID1) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndUnseen},
    1,
    "Counter \"OwnedAndUnseen\" (UserID: $UserID1) is 1",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndLocked},
    "Counter \"OwnedAndLocked\" (UserID: $UserID1) is not set",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID1) is not set",
);

my $Success = $Kernel::OM->Get('Ticket')->TicketLockSet(
    TicketID => $TicketID,
    Lock     => 'lock',
    UserID   => $UserID1,
);

# sanity check
$Self->True(
    $Success,
    "TicketLockSet() successful for Ticket ID $TicketID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID1
);
$Self->Is(
    $Counters{Ticket}->{Owned},
    1,
    "Counter \"Owned\" (UserID: $UserID1) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndUnseen},
    1,
    "Counter \"OwnedAndUnseen\" (UserID: $UserID1) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLocked},
    1,
    "Counter \"OwnedAndLocked\" (UserID: $UserID1) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    1,
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID1) is 1",
);

$Success = $Kernel::OM->Get('Ticket')->TicketFlagSet(
    TicketID => $TicketID,
    Key      => 'Seen',
    Value    => 1,
    UserID   => $UserID1,
);

# sanity check
$Self->True(
    $Success,
    "TicketFlagSet() successful for Ticket ID $TicketID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID1
);
$Self->Is(
    $Counters{Ticket}->{Owned},
    1,
    "Counter \"Owned\" (UserID: $UserID1) is 1",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndUnseen},
    "Counter \"OwnedAndUnseen\" (UserID: $UserID1) is not set",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLocked},
    1,
    "Counter \"OwnedAndLocked\" (UserID: $UserID1) is 1",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID1) not set",
);

$Success = $Kernel::OM->Get('Watcher')->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketID,
    WatchUserID => $UserID1,
    UserID      => 1,
);

# sanity check
$Self->True(
    $Success,
    "WatcherAdd() successful for Ticket ID $TicketID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID1
);
$Self->Is(
    $Counters{Ticket}->{Watched},
    1,
    "Counter \"Watched\" (UserID: $UserID1) is 1",
);
$Self->False(
    $Counters{Ticket}->{WatchedAndUnseen},
    "Counter \"WatchedAndUnseen\" (UserID: $UserID1) not set",
);

$Success = $Kernel::OM->Get('Ticket')->TicketFlagDelete(
    TicketID => $TicketID,
    Key      => 'Seen',
    UserID   => $UserID1,
);
# sanity check
$Self->True(
    $Success,
    "TicketFlagDelete() successful for Ticket ID $TicketID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID1
);
$Self->Is(
    $Counters{Ticket}->{Watched},
    1,
    "Counter \"Watched\" (UserID: $UserID1) is 1",
);
$Self->Is(
    $Counters{Ticket}->{WatchedAndUnseen},
    1,
    "Counter \"WatchedAndUnseen\" (UserID: $UserID1) is 1",
);

# try adding the same object again to see if some unique key violation occurs
$Success = $Kernel::OM->Get('User')->AddUserCounterObject(
    Category => 'Ticket',
    Counter  => 'WatchedAndUnseen',
    ObjectID => $TicketID,
    UserID   => $UserID1,
);

# sanity check
$Self->True(
    $Success,
    "AddUserCounterObject() duplicate for Ticket ID $TicketID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID1
);
$Self->Is(
    $Counters{Ticket}->{Watched},
    1,
    "Counter \"Watched\" (UserID: $UserID1) is 1",
);
$Self->Is(
    $Counters{Ticket}->{WatchedAndUnseen},
    1,
    "Counter \"WatchedAndUnseen\" (UserID: $UserID1) is 1",
);

$Success = $Kernel::OM->Get('Watcher')->WatcherDelete(
    Object      => 'Ticket',
    ObjectID    => $TicketID,
    WatchUserID => $UserID1,
    UserID      => 1,
);

# sanity check
$Self->True(
    $Success,
    "WatcherDelete() successful for Ticket ID $TicketID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID1
);
$Self->False(
    $Counters{Ticket}->{Watched},
    "Counter \"Watched\" (UserID: $UserID1) is not set",
);
$Self->False(
    $Counters{Ticket}->{WatchedAndUnseen},
    "Counter \"WatchedAndUnseen\" (UserID: $UserID1) not set",
);

$Success = $Kernel::OM->Get('Ticket')->TicketOwnerSet(
    TicketID  => $TicketID,
    NewUserID => $UserID2,
    UserID    => $UserID1,
);

# sanity check
$Self->True(
    $Success,
    "TicketOwnerSet() successful for Ticket ID $TicketID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID1
);
$Self->False(
    $Counters{Ticket}->{Owned},
    "Counter \"Owned\" (UserID: $UserID1) is not set",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndUnseen},
    "Counter \"OwnedAndUnseen\" (UserID: $UserID1) is not set",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndLocked},
    "Counter \"OwnedAndLocked\" (UserID: $UserID1) is not set",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID1) not set",
);
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID2
);
$Self->Is(
    $Counters{Ticket}->{Owned},
    1,
    "Counter \"Owned\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndUnseen},
    1,
    "Counter \"OwnedAndUnseen\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLocked},
    1,
    "Counter \"OwnedAndLocked\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    1,
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID2) is 1",
);

$Success = $Kernel::OM->Get('Ticket')->TicketFlagSet(
    TicketID => $TicketID,
    Key      => 'Seen',
    Value    => 1,
    UserID   => $UserID2,
);

# sanity check
$Self->True(
    $Success,
    "TicketFlagSet() successful for Ticket ID $TicketID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID2
);
$Self->Is(
    $Counters{Ticket}->{Owned},
    1,
    "Counter \"Owned\" (UserID: $UserID2) is 1",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndUnseen},
    "Counter \"OwnedAndUnseen\" (UserID: $UserID1) is not set",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLocked},
    1,
    "Counter \"OwnedAndLocked\" (UserID: $UserID2) is 1",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID2) is not set",
);

# create article
my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID      => $TicketID,
    Channel       => 'note',
    SenderType    => 'external',
    Charset       => 'utf-8',
    ContentType   => 'text/plain',
    CustomerVisible => 1,
    From          => 'test@example.com',
    To            => 'test123@example.com',
    Subject       => 'article subject test',
    Body          => 'article body test',
    HistoryType   => 'NewTicket',
    HistoryComment => q{%%},
    UserID        => 1,
);

# sanity check
$Self->True(
    $ArticleID,
    "ArticleCreate() successful for Article ID $ArticleID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID2
);
$Self->Is(
    $Counters{Ticket}->{Owned},
    1,
    "Counter \"Owned\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndUnseen},
    1,
    "Counter \"OwnedAndUnseen\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLocked},
    1,
    "Counter \"OwnedAndLocked\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    1,
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID2) is 1",
);

# create another ticket
my $TicketID2 = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'User Counter Test 2',
    QueueID        => 1,
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'new',
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => $UserID2,
    UserID         => 1,
);

# sanity check
$Self->True(
    $TicketID2,
    "TicketCreate() successful for Ticket ID $TicketID2",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID2
);
$Self->Is(
    $Counters{Ticket}->{Owned},
    2,
    "Counter \"Owned\" (UserID: $UserID2) is 2",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndUnseen},
    2,
    "Counter \"OwnedAndUnseen\" (UserID: $UserID1) is 2",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLocked},
    1,
    "Counter \"OwnedAndLocked\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    1,
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID2) is 1",
);

$Success = $Kernel::OM->Get('Ticket')->TicketLockSet(
    TicketID => $TicketID2,
    Lock     => 'lock',
    UserID   => $UserID2,
);

# sanity check
$Self->True(
    $Success,
    "TicketLockSet() successful for Ticket ID $TicketID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID2
);
$Self->Is(
    $Counters{Ticket}->{Owned},
    2,
    "Counter \"Owned\" (UserID: $UserID2) is 2",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndUnseen},
    2,
    "Counter \"OwnedAndUnseen\" (UserID: $UserID1) is 2",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLocked},
    2,
    "Counter \"OwnedAndLocked\" (UserID: $UserID2) is 2",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    2,
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID2) is 2",
);

# delete the ticket to cleanup file system
my $TicketDelete = $Kernel::OM->Get('Ticket')->TicketDelete(
    TicketID => $TicketID,
    UserID   => $UserID1,
);

# sanity check
$Self->True(
    $TicketDelete,
    "TicketDelete() successful for Ticket ID $TicketID",
);

# check counters
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID1
);
$Self->False(
    $Counters{Ticket}->{Owned},
    "Counter \"Owned\" (UserID: $UserID1) is not set",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndUnseen},
    "Counter \"OwnedAndUnseen\" (UserID: $UserID1) is not set",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndLocked},
    "Counter \"OwnedAndLocked\" (UserID: $UserID1) is not set",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID1) is 1",
);
%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID2
);
$Self->Is(
    $Counters{Ticket}->{Owned},
    1,
    "Counter \"Owned\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndUnseen},
    1,
    "Counter \"OwnedAndUnseen\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLocked},
    1,
    "Counter \"OwnedAndLocked\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    1,
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID2) is 1",
);

# set non-viewable state
$Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
    TicketID => $TicketID2,
    State    => 'merged',
    UserID   => $UserID2,
);

# sanity check
$Self->True(
    $Success,
    "TicketStateSet(merged) successful for Ticket ID $TicketID2",
);

%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID2
);
$Self->False(
    $Counters{Ticket}->{Owned},
    "Counter \"Owned\" (UserID: $UserID2) is no set",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndUnseen},
    "Counter \"OwnedAndUnseen\" (UserID: $UserID2) is not set",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndLocked},
    "Counter \"OwnedAndLocked\" (UserID: $UserID2) is not set",
);
$Self->False(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID2) is not set",
);

# set non-viewable state
$Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
    TicketID => $TicketID2,
    State    => 'open',
    UserID   => $UserID2,
);

# sanity check
$Self->True(
    $Success,
    "TicketStateSet(open) successful for Ticket ID $TicketID2",
);

%Counters = $Kernel::OM->Get('User')->GetUserCounters(
    UserID => $UserID2
);
$Self->Is(
    $Counters{Ticket}->{Owned},
    1,
    "Counter \"Owned\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndUnseen},
    1,
    "Counter \"OwnedAndUnseen\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLocked},
    1,
    "Counter \"OwnedAndLocked\" (UserID: $UserID2) is 1",
);
$Self->Is(
    $Counters{Ticket}->{OwnedAndLockedAndUnseen},
    1,
    "Counter \"OwnedAndLockedAndUnseen\" (UserID: $UserID2) is 1",
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
