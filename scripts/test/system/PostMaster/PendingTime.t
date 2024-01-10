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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

$Helper->FixedTimeSet();

my %NeededXHeaders = (
#rbo - T2016121190001552 - renamed X-KIX headers
    'X-KIX-PendingTime'          => 1,
    'X-KIX-FollowUp-PendingTime' => 1,
);

my $XHeaders          = $Kernel::OM->Get('Config')->Get('PostmasterX-Header');
my @PostmasterXHeader = @{$XHeaders};
HEADER:
for my $Header ( sort keys %NeededXHeaders ) {
    next HEADER if ( grep $_ eq $Header, @PostmasterXHeader );
    push @PostmasterXHeader, $Header;
}

# filter test
my @Tests = (
    {
        Name  => 'Regular pending time test',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '2021-01-01 00:00:00',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '2022-01-01 00:00:00',
        },
        CheckNewTicket => {
            PendingTimeUnix => $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                String => '2021-01-01 00:00:00'
            ),
        },
        CheckFollowUp => {
            PendingTimeUnix => $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                String => '2022-01-01 00:00:00'
            ),
        },
    },
    {
        Name  => 'Regular pending time test, wrong date',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '2022-01- 00:00:00',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '2022-01- 00:00:00',
        },
        CheckNewTicket => {
            PendingTimeUnix => 0,
        },
        CheckFollowUp => {
            PendingTimeUnix => 0,
        },
    },
    {
        Name  => 'Relative pending time test seconds',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+60s',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30s',
        },
        CheckNewTicket => {
            UntilTime => 60,
        },
        CheckFollowUp => {
            UntilTime => 30,
        },
    },
    {
        Name  => 'Relative pending time test implicit seconds',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+60',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30',
        },
        CheckNewTicket => {
            UntilTime => 60,
        },
        CheckFollowUp => {
            UntilTime => 30,
        },
    },
    {
        Name  => 'Relative pending time test implicit seconds no sign',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '60',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '30',
        },
        CheckNewTicket => {
            UntilTime => 60,
        },
        CheckFollowUp => {
            UntilTime => 30,
        },
    },
    {
        Name  => 'Relative pending time test minutes',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+60m',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30m',
        },
        CheckNewTicket => {
            UntilTime => 60 * 60,
        },
        CheckFollowUp => {
            UntilTime => 30 * 60,
        },
    },
    {
        Name  => 'Relative pending time test hours',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+60h',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30h',
        },
        CheckNewTicket => {
            UntilTime => 60 * 60 * 60,
        },
        CheckFollowUp => {
            UntilTime => 30 * 60 * 60,
        },
    },
    {
        Name  => 'Relative pending time test days',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+60d',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30d',
        },
        CheckNewTicket => {
            UntilTime => 60 * 60 * 60 * 24,
        },
        CheckFollowUp => {
            UntilTime => 30 * 60 * 60 * 24,
        },
    },
    {
        Name  => 'Relative pending time test, invalid unit',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+30y',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30y',
        },
        CheckNewTicket => {
            UntilTime => 0,
        },
        CheckFollowUp => {
            UntilTime => 0,
        },
    },
    {
        Name  => 'Relative pending time test, invalid combination',
        Match => {
            From => 'sender@example.com',
        },
        Set => {
            'X-KIX-State'                      => 'pending reminder',
            'X-KIX-State-PendingTime'          => '+30s +30m',
            'X-KIX-FollowUp-State'             => 'pending reminder',
            'X-KIX-FollowUp-State-PendingTime' => '+30s +30m',
        },
        CheckNewTicket => {
            UntilTime => (30 * 60) + (30),
        },
        CheckFollowUp => {
            UntilTime => (30 * 60) + (30),
        },
    },
);

for my $Test (@Tests) {

    my $Email = 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: some subject

Some Content in Body
';

    my @Return;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => \$Email,
        );

        $Kernel::OM->Get('Config')->Set(
            Key   => 'PostmasterX-Header',
            Value => \@PostmasterXHeader
        );
        $Kernel::OM->Get('Config')->Set(
            Key   => 'PostMaster::PreFilterModule###' . $Test->{Name},
            Value => {
                %{$Test},
                Module => 'Kernel::System::PostMaster::Filter::Match',
            },
        );

        @Return = $PostMasterObject->Run();
        @Return = @{ $Return[0] || [] };
    }

    $Self->Is(
        $Return[0] || 0,
        1,
        "$Test->{Name} - Create new ticket",
    );

    $Self->True(
        $Return[1] || 0,
        "$Test->{Name} - Create new ticket (TicketID)",
    );

    my $TicketID = $Return[1];

    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    for my $Key ( sort keys %{ $Test->{CheckNewTicket} } ) {
        $Self->Is(
            $Ticket{$Key},
            $Test->{CheckNewTicket}->{$Key},
            "$Test->{Name} - NewTicket - Check result value $Key",
        );
    }

    my $Subject = 'Subject: ' . $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => 'test',
    );

    my $Email2 = "From: Sender <sender\@example.com>
To: Some Name <recipient\@example.com>
$Subject

Some Content in Body
";

    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => \$Email2,
        );

        @Return = $PostMasterObject->Run();
        @Return = @{ $Return[0] || [] };
    }

    $Self->Is(
        $Return[0] || 0,
        2,
        "$Test->{Name} - Create follow up ticket",
    );
    $Self->True(
        $Return[1] || 0,
        "$Test->{Name} - Create follow up ticket (TicketID)",
    );
    $Self->Is(
        $Return[1],
        $TicketID,
        "$Test->{Name} - Create follow up ticket (TicketID of original ticket)",
    );

    %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    for my $Key ( sort keys %{ $Test->{CheckFollowUp} } ) {
        $Self->Is(
            $Ticket{$Key},
            $Test->{CheckFollowUp}->{$Key},
            "$Test->{Name} - FollowUp - Check result value $Key",
        );
    }

    $Kernel::OM->Get('Config')->Set(
        Key   => 'PostMaster::PreFilterModule###' . $Test->{Name},
        Value => undef,
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
