# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $AutomationObject = $Kernel::OM->Get('Automation');
my $TicketObject     = $Kernel::OM->Get('Ticket');
my $ConfigObject     = $Kernel::OM->Get('Config');
my $MainObject       = $Kernel::OM->Get('Main');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# no event handling for tickets
$ConfigObject->Set(
    Key => 'Ticket::EventModulePost',
);

my %Data = (
    Ticket_1_Title   => 'TicketFilter_1',
    Ticket_1_TypeID  => 1,
    Ticket_1_QueueID => 1,
    Ticket_2_Title   => 'TicketFilter_2',
    Ticket_2_TypeID  => 2,
    Ticket_2_QueueID => 2,
    Ticket_3_Title   => 'TicketFilter_3',
    Ticket_3_TypeID  => 3,
    Ticket_3_QueueID => 3
);

my ($TicketID_1, $TicketID_2, $TicketID_3) = _CreateTickets();
if ($TicketID_1) {
    my @TestData = (
        {
            Test   => 'without filter',
            Filter => undef,
            Expected => {
                Count => 3,
                IDs   => [$TicketID_1, $TicketID_2, $TicketID_3]
            }
        },
        {
            Test   => 'AND filter for title of ticket 1',
            Filter => [
                {
                    AND => [
                        { Field => 'Title', Operator => 'EQ', Value => $Data{Ticket_1_Title} }
                    ]
                }
            ],
            Expected => {
                Count => 1,
                IDs   => [$TicketID_1]
            }
        },
        {
            Test   => 'AND filter for title of ticket 1 (backward compatibility)', # filter is deprecated, should always be an array, but we will support it anyways
            Filter => {
                AND => [
                    { Field => 'Title', Operator => 'EQ', Value => $Data{Ticket_1_Title} }
                ]
            },
            Expected => {
                Count => 1,
                IDs   => [$TicketID_1]
            }
        },
        {
            Test   => 'AND filter for title of ticket 2',
            Filter => [
                {
                    AND => [
                        { Field => 'Title', Operator => 'EQ', Value => $Data{Ticket_2_Title} }
                    ]
                }
            ],
            Expected => {
                Count => 1,
                IDs   => [$TicketID_2]
            }
        },
        {
            Test   => 'AND filter for title of ticket 2 but with additional TicketID of ticket 1',
            Filter => [
                {
                    AND => [
                        { Field => 'Title', Operator => 'EQ', Value => $Data{Ticket_2_Title} }
                    ]
                }
            ],
            Data => {
                TicketID => $TicketID_1
            },
            Expected => {
                Count => 0,
                IDs   => []
            }
        },
        {
            Test   => 'AND filter for type id of ticket 1',
            Filter => [
                {
                    AND => [
                        { Field => 'TypeID', Operator => 'IN', Value => [$Data{Ticket_1_TypeID}] }
                    ]
                }
            ],
            Expected => {
                Count => 1,
                IDs   => [$TicketID_1]
            }
        },
        {
            Test   => 'AND filter for type id of ticket 1 and 2',
            Filter => [
                {
                    AND => [
                        { Field => 'TypeID', Operator => 'IN', Value => [$Data{Ticket_1_TypeID}, $Data{Ticket_2_TypeID}] }
                    ]
                }
            ],
            Expected => {
                Count => 2,
                IDs   => [$TicketID_1, $TicketID_2]
            }
        },
        {
            Test   => 'AND filter for type id of ticket 1 and 2 (separate filter)',
            Filter => [
                {
                    AND => [
                        { Field => 'TypeID', Operator => 'EQ', Value => $Data{Ticket_1_TypeID} }
                    ]
                },
                {
                    AND => [
                        { Field => 'TypeID', Operator => 'EQ', Value => $Data{Ticket_2_TypeID} }
                    ]
                }
            ],
            Expected => {
                Count => 2,
                IDs   => [$TicketID_1, $TicketID_2]
            }
        },
        {
            Test   => 'AND filter for type id of ticket 1 and title of ticket 2 (separate filter)',
            Filter => [
                {
                    AND => [
                        { Field => 'TypeID', Operator => 'EQ', Value => $Data{Ticket_1_TypeID} }
                    ]
                },
                {
                    AND => [
                        { Field => 'Title', Operator => 'EQ', Value => $Data{Ticket_2_Title} }
                    ]
                }
            ],
            Expected => {
                Count => 2,
                IDs   => [$TicketID_1, $TicketID_2]
            }
        },
        {
            Test   => 'AND filter for type id of ticket 1 and title of ticket 2 (same filter)',
            Filter => [
                {
                    AND => [
                        { Field => 'TypeID', Operator => 'EQ', Value => $Data{Ticket_1_TypeID} },
                        { Field => 'Title', Operator => 'EQ', Value => $Data{Ticket_2_Title} }
                    ]
                }
            ],
            Expected => {
                Count => 0,
                IDs   => []
            }
        },
        {
            Test   => 'no filter but with id of ticket 1',
            Filter => undef,
            Data => {
                TicketID => $TicketID_1
            },
            Expected => {
                Count => 1,
                IDs   => [$TicketID_1]
            }
        },
        {
            Test   => 'empty filter but with id of ticket 1',
            Filter => [],
            Data => {
                TicketID => $TicketID_1
            },
            Expected => {
                Count => 1,
                IDs   => [$TicketID_1]
            }
        },
    );

    # load job type backend module
    my $JobObject = $AutomationObject->_LoadJobTypeBackend(
        Name => 'Ticket',
    );
    $Self->True(
        $JobObject,
        'JobObject loaded',
    );

    # run checks
    foreach my $Test ( @TestData ) {
        my @ObjectIDs = $JobObject->Run(
            Data   => $Test->{Data},
            Filter => $Test->{Filter},
            UserID => 1,
        );

        # only tickets wich are created by this test
        @ObjectIDs = $MainObject->GetCombinedList(
            ListA => \@ObjectIDs,
            ListB => [$TicketID_1, $TicketID_2, $TicketID_3]
        );

        if ($Test->{Expected}->{Count}) {
            $Self->Is(
                scalar(@ObjectIDs),
                $Test->{Expected}->{Count},
                'Test "'.$Test->{Test}.'" - count ('.$Test->{Expected}->{Count}.')'
            );
        } else {
            $Self->False(
                scalar(@ObjectIDs),
                'Test "'.$Test->{Test}.'" - count (0)'
            );
        }

        if ($Test->{Expected}->{IDs}) {
            for my $ID (@{$Test->{Expected}->{IDs}}) {
                $Self->ContainedIn(
                    $ID,
                    \@ObjectIDs,
                    'Test "'.$Test->{Test}.'" - has ID',
                );
            }
        }
    }
}

sub _CreateTickets {
    my @TicketIDs;
    for my $Index (1..3) {
        my $TicketID = $TicketObject->TicketCreate(
            Title   => $Data{"Ticket_".$Index."_Title"},
            QueueID => $Data{"Ticket_".$Index."_QueueID"},
            TypeID  => $Data{"Ticket_".$Index."_TypeID"},
            OwnerID => 1,
            LockID  => 1,
            UserID  => 1
        );
        if ($TicketID) {
            push(@TicketIDs, $TicketID);
        } else {
            $Self->True(
                0,
                "_CreateTickets - could not create ticket (" . $Data{"Ticket_".$Index."_Title"} . ")",
            );
            return;
        }
    }
    return @TicketIDs;
}

# cleanup is done by RestoreDatabase

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
