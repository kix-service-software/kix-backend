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

use Kernel::System::PostMaster;

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $TicketObject = $Kernel::OM->Get('Ticket');
my $QueueObject  = $Kernel::OM->Get('Queue');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

$Helper->FixedTimeSet();

my $AgentAddress    = 'agent@example.com';
my $CustomerAddress = 'external@example.com';

my $QueueID = $QueueObject->QueueAdd(
    Name            => 'NewTestQueue',
    ValidID         => 1,
    GroupID         => 1,
    UnlockTimeout   => 480,
    FollowUpID      => 3,                # create new ticket
    SystemAddressID => 1,
    Comment         => 'Some comment',
    UserID          => 1,
);
$Self->True(
    $QueueID,
    "Queue created."
);

my @Tests = (
    {
        TicketState     => 'new',
        QueueFollowUpID => 1,       # possible (1), reject (2) or new ticket (3) (optional, default 0)
        ExpectedResult  => 2,       # 0 = error (also false)
                                    # 1 = new ticket created
                                    # 2 = follow up / open/reopen
                                    # 3 = follow up / close -> new ticket
                                    # 4 = follow up / close -> reject
                                    # 5 = ignored (because of X-KIX-Ignore header)
                                    # 6 = ignored (Message-ID already in system)
    },
    {
        TicketState     => 'open',
        QueueFollowUpID => 1,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'closed',
        QueueFollowUpID => 1,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'pending reminder',
        QueueFollowUpID => 1,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'removed',
        QueueFollowUpID => 1,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'merged',
        QueueFollowUpID => 1,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'new',
        QueueFollowUpID => 2,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'open',
        QueueFollowUpID => 2,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'closed',
        QueueFollowUpID => 2,
        ExpectedResult  => 4,
    },
    {
        TicketState     => 'pending reminder',
        QueueFollowUpID => 2,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'removed',
        QueueFollowUpID => 2,
        ExpectedResult  => 4,
    },
    {
        TicketState     => 'merged',
        QueueFollowUpID => 2,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'new',
        QueueFollowUpID => 3,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'open',
        QueueFollowUpID => 3,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'closed',
        QueueFollowUpID => 3,
        ExpectedResult  => 3,
    },
    {
        TicketState     => 'pending reminder',
        QueueFollowUpID => 3,
        ExpectedResult  => 2,
    },
    {
        TicketState     => 'removed',
        QueueFollowUpID => 3,
        ExpectedResult  => 3,
    },
    {
        TicketState     => 'merged',
        QueueFollowUpID => 3,
        ExpectedResult  => 2,
    },
);

# create a new ticket
my $TicketID = $TicketObject->TicketCreate(
    Title          => 'My ticket created by Agent',
    Queue          => 'NewTestQueue',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'removed',
    OrganisationID => 'external@example.com',
    ContactID      => 'external@example.com',
    OwnerID        => 1,
    UserID         => 1,
);
$TicketID //= '';

$Self->True(
    $TicketID,
    "Ticket created - TicketID=$TicketID."
);

my %Ticket = $TicketObject->TicketGet(
    TicketID      => $TicketID,
    DynamicFields => 0,
    UserID        => 1,
    Silent        => 0,
);

for my $Test (@Tests) {

    my @Return;

    # update Queue (FollowUpID)
    my $QueueUpdated = $QueueObject->QueueUpdate(
        QueueID         => $QueueID,
        Name            => 'NewTestQueue',
        ValidID         => 1,
        GroupID         => 1,
        UnlockTimeout   => 480,
        FollowUpID      => $Test->{QueueFollowUpID},
        SystemAddressID => 1,
        Comment         => 'Some comment',
        UserID          => 1,
        CheckSysConfig  => 0,
    );
    $Self->True(
        $QueueUpdated,
        "Queue updated."
    );

    my $TicketUpdated = $TicketObject->TicketStateSet(
        State    => $Test->{TicketState},
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->True(
        $TicketUpdated,
        "TicketStateSet updated."
    );

    my $PostMasterObject = Kernel::System::PostMaster->new(
        Email => "From: Provider <$CustomerAddress>
To: Agent <$AgentAddress>
Subject: FollowUp Ticket#$Ticket{TicketNumber}

Some Content in Body",
    );

    @Return = $PostMasterObject->Run();
    @Return = @{ $Return[0] || [] };

    $Self->Is(
        $Return[0] || 0,
        $Test->{ExpectedResult},
        "Check result (State=$Test->{TicketState}, FollowUpID=$Test->{QueueFollowUpID}).",
    );
}

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
