# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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
my $QueueObject   = $Kernel::OM->Get('Queue');
my $StateObject   = $Kernel::OM->Get('State');
my $TicketObject  = $Kernel::OM->Get('Ticket');
my $TimeObject    = $Kernel::OM->Get('Time');
my $TypeObject    = $Kernel::OM->Get('Type');
my $UserObject    = $Kernel::OM->Get('User');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# set fixed time
$Helper->FixedTimeSet();

my $TicketID = $TicketObject->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => '123465',
    ContactID      => 'customer@example.com',
    OwnerID        => 1,
    UserID         => 1,
    Silent         => 1
);
$Self->True(
    $TicketID,
    'TicketCreate()',
);

# try to get a non-existant ticket
my %Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID + 1,
    Silent   => 1
);
$Self->False(
    $Ticket{Title},
    'TicketGet() (Title) is empty',
);

my $TestUserLogin = $Helper->TestUserCreate();

my $TestUserID = $UserObject->UserLookup(
    UserLogin => $TestUserLogin,
);

my $TicketIDCreatedBy = $TicketObject->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => '123465',
    ContactID      => 'customer@example.com',
    OwnerID        => 1,
    UserID         => $TestUserID,
);

my %CheckCreatedBy = $TicketObject->TicketGet(
    TicketID => $TicketIDCreatedBy,
    UserID   => $TestUserID,
);

$Self->Is(
    $CheckCreatedBy{ChangeBy},
    $TestUserID,
    'TicketGet() (ChangeBy - not system ID 1 user)',
);

$Self->Is(
    $CheckCreatedBy{CreateBy},
    $TestUserID,
    'TicketGet() (CreateBy - not system ID 1 user)',
);

$TicketObject->TicketOwnerSet(
    TicketID  => $TicketIDCreatedBy,
    NewUserID => $TestUserID,
    UserID    => 1,
);

%CheckCreatedBy = $TicketObject->TicketGet(
    TicketID => $TicketIDCreatedBy,
    UserID   => $TestUserID,
);

$Self->Is(
    $CheckCreatedBy{CreateBy},
    $TestUserID,
    'TicketGet() (CreateBy - still the same after OwnerSet)',
);


$Self->Is(
    $CheckCreatedBy{ChangeBy},
    1,
    'TicketOwnerSet() (ChangeBy - System ID 1 now)',
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
