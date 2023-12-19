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
my $TicketObject = $Kernel::OM->Get('Ticket');
my $UserObject   = $Kernel::OM->Get('User');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $TestUserLogin = $Helper->TestUserCreate(
    Roles => ['Ticket Agent'],
);
my $TestUserID = $UserObject->UserLookup(
    UserLogin => $TestUserLogin,
);

my @TicketIDs;

# create 2 tickets
for ( 1 .. 2 ) {
    my $TicketID = $TicketObject->TicketCreate(
        Title      => 'My ticket created by Agent A',
        QueueID    => '1',
        Lock       => 'unlock',
        PriorityID => 1,
        StateID    => 1,
        OwnerID    => $TestUserID,
        UserID     => 1,
    );

    $Self->True(
        $TicketID,
        "TicketCreate() for test - $TicketID",
    );
    push @TicketIDs, $TicketID;
}

$Helper->FixedTimeSet();
$Helper->FixedTimeAddSeconds(60);

# update ticket 1
my $Success = $TicketObject->TicketLockSet(
    Lock     => 'lock',
    TicketID => $TicketIDs[0],
    UserID   => 1,
);
$Self->True(
    $Success,
    "TicketLockSet() for test - $TicketIDs[0]",
);

# close ticket 2
$Success = $TicketObject->TicketStateSet(
    State    => 'closed',
    TicketID => $TicketIDs[1],
    UserID   => 1,
);
$Self->True(
    $Success,
    "TicketStateSet() for test - $TicketIDs[1]",
);

$Helper->FixedTimeAddSeconds(60);

my $TimeObject = $Kernel::OM->Get('Time');

# the following tests should provoke a join in ticket_history table and the resulting SQL should be valid
my @Tests = (
    {
        Name   => "CreatedTypeIDs",
        Config => {
            Search => {
                AND => [
                    {
                        Field    => 'CreatedTypeIDs',
                        Operator => 'IN',
                        Type     => 'NUMERIC',
                        Value    => [ 1 ]
                    }
                ]
            }
        },
        ExpectedTicketIDs => [ $TicketIDs[0], $TicketIDs[1] ],
    },
    {
        Name   => "CreatedStateIDs",
        Config => {
            Search => {
                AND => [
                    {
                        Field    => 'CreatedStateIDs',
                        Operator => 'IN',
                        Type     => 'NUMERIC',
                        Value    => [ 1 ]
                    }
                ]
            }
        },
        ExpectedTicketIDs => [ $TicketIDs[0], ],
    },
    {
        Name   => "CreateByID",
        Config => {
            Search => {
                AND => [
                    {
                        Field    => 'CreateByID',
                        Operator => 'IN',
                        Type     => 'NUMERIC',
                        Value    => [ 1 ]
                    }
                ]
            }
        },
        ExpectedTicketIDs => [ $TicketIDs[0], $TicketIDs[1] ],
    },
    {
        Name   => "CreatedQueueIDs",
        Config => {
            Search => {
                AND => [
                    {
                        Field    => 'CreatedQueueIDs',
                        Operator => 'IN',
                        Type     => 'NUMERIC',
                        Value    => [ 1 ]
                    }
                ]
            }
        },
        ExpectedTicketIDs => [ $TicketIDs[0], $TicketIDs[1] ],
    },
    {
        Name   => "CreatedPriorityIDs",
        Config => {
            Search => {
                AND => [
                    {
                        Field    => 'CreatedPriorityIDs',
                        Operator => 'IN',
                        Type     => 'NUMERIC',
                        Value    => [ 1 ]
                    }
                ]
            }
        },
        ExpectedTicketIDs => [ $TicketIDs[0], $TicketIDs[1] ],
    },
    {
        Name   => "TicketChangeTimeOlderDate",
        Config => {
            Search => {
                AND => [
                    {
                        Field    => 'ChangeTime',
                        Operator => 'LTE',
                        Type     => 'STRING',
                        Value    => $TimeObject->CurrentTimestamp()
                    }
                ]
            }
        },
        ExpectedTicketIDs => [ $TicketIDs[0], $TicketIDs[1] ],
    },
    {
        Name   => "TicketCloseTimeOlderDate",
        Config => {
            Search => {
                AND => [
                    {
                        Field    => 'CloseTime',
                        Operator => 'LTE',
                        Type     => 'STRING',
                        Value    => $TimeObject->CurrentTimestamp()
                    }
                ]
            }
        },
        ExpectedTicketIDs => [ $TicketIDs[1] ],
    },
    {
        Name   => "TicketCloseTimeNewerDate",
        Config => {
            Search => {
                AND => [
                    {
                        Field    => 'CloseTime',
                        Operator => 'GTE',
                        Type     => 'STRING',
                        Value    => $TimeObject->SystemTime2TimeStamp(
                            SystemTime => $TimeObject->SystemTime() - 61,
                        )
                    }
                ]
            }
        },
        ExpectedTicketIDs => [ $TicketIDs[1] ],
    },
);

for my $Test (@Tests) {

    my @ReturnedTicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        UserType   => 'Agent',
        UserID     => 1,
        Result     => 'ARRAY',
        Sort       => [
            {
                Field     => 'TicketNumber',
                Direction => 'ASCENDING'
            }
        ],
        %{ $Test->{Config} },
    );

    my %ReturnedLookup = map { $_ => 1 } @ReturnedTicketIDs;

    for my $TicketID ( @{ $Test->{ExpectedTicketIDs} } ) {

        $Self->True(
            $ReturnedLookup{$TicketID},
            "$Test->{Name} TicketSearch() - Results contains ticket $TicketID",
        );
    }
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
