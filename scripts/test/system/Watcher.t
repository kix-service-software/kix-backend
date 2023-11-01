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

use vars (qw($Self));

# get needed objects
my $TicketObject  = $Kernel::OM->Get('Ticket');
my $WatcherObject = $Kernel::OM->Get('Watcher');
my $UserObject    = $Kernel::OM->Get('User');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my @TicketIDs;
my @TestUserIDs;
for ( 1 .. 2 ) {

    my $TestUserLogin = $Helper->TestUserCreate();

    my $TestUserID = $UserObject->UserLookup(
        UserLogin => $TestUserLogin,
    );

    push @TestUserIDs, $TestUserID;

    # create a new ticket
    my $TicketID = $TicketObject->TicketCreate(
        Title          => 'My ticket for watching',
        Queue          => 'Junk',
        Lock           => 'unlock',
        Priority       => '3 normal',
        State          => 'open',
        ContactID      => 'customer@example.com',
        OrganisationID => 'example.com',
        OwnerID        => 1,
        UserID         => 1,
    );

    $Self->True(
        $TicketID,
        "Ticket created for test - $TicketID",
    );
    push @TicketIDs, $TicketID;
}

my $Subscribe = $WatcherObject->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketIDs[0],
    WatchUserID => $TestUserIDs[0],
    UserID      => 1,
);
$Self->True(
    $Subscribe || 0,
    'WatcherAdd()',
);
my $Unsubscribe = $WatcherObject->WatcherDelete(
    Object      => 'Ticket',
    ObjectID    => $TicketIDs[0],
    WatchUserID => $TestUserIDs[0],
    UserID      => 1,
);
$Self->True(
    $Unsubscribe || 0,
    'WatcherDelete()',
);

# add new subscription (will be deleted by TicketDelete(), also check foreign keys)
$Subscribe = $WatcherObject->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketIDs[0],
    WatchUserID => $TestUserIDs[0],
    UserID      => 1,
);
$Self->True(
    $Subscribe || 0,
    'WatcherAdd()',
);

# subscribe first ticket with second user
$Subscribe = $WatcherObject->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketIDs[0],
    WatchUserID => $TestUserIDs[1],
    UserID      => 1,
);
$Self->True(
    $Subscribe || 0,
    'WatcherAdd()',
);

# subscribe second ticket with second user
$Subscribe = $WatcherObject->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketIDs[1],
    WatchUserID => $TestUserIDs[1],
    UserID      => 1,
);
$Self->True(
    $Subscribe || 0,
    'WatcherAdd()',
);

my @WatcherList = $WatcherObject->WatcherList(
    Object   => 'Ticket',
    ObjectID => $TicketIDs[0],
);
my %Watchers = map { $_->{UserID} => $_ } @WatcherList;
$Self->True(
    $Watchers{ $TestUserIDs[0] } || 0,
    'WatcherList - first user',
);
$Self->True(
    $Watchers{ $TestUserIDs[1] },
    'WatcherList - second user',
);

@WatcherList = $WatcherObject->WatcherList(
    Object   => 'Ticket',
    ObjectID => $TicketIDs[1],
);
%Watchers = map { $_->{UserID} => $_ } @WatcherList;
$Self->False(
    $Watchers{ $TestUserIDs[0] } || 0,
    'WatcherList - first user',
);
$Self->True(
    $Watchers{ $TestUserIDs[1] },
    'WatcherList - second user',
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
