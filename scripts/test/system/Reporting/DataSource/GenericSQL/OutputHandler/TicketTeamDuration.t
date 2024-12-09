# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);
use vars (qw($Self));

# get OutputHandler object
my $OutputHandler       = 'TicketTeamDuration';
my $OutputHandlerObject = $Kernel::OM->Get('Reporting')->_LoadDataSourceBackend(Name => 'GenericSQL')->_LoadOutputHandlerBackend(Name => $OutputHandler);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my @ConfigTests = (
    {
        Name   => 'no config',
        Config => undef,
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'empty config',
        Config => {},
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - missing Columns',
        Config => {
            Teams => ['Service Desk'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - invalid Columns',
        Config => {
            Columns => { 'UnitTest1' => 1 },
            Teams   => ['Service Desk'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - missing States',
        Config => {
            Columns => ['UnitTest1'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - invalid States',
        Config => {
            Columns => ['UnitTest1'],
            States  => { 'Service Desk' => 1 },
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - more entries in Columns than States',
        Config => {
            Columns => ['UnitTest1','UnitTest2'],
            Teams   => ['Service Desk'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - less entries in Columns than States',
        Config => {
            Columns => ['UnitTest1'],
            Teams   => ['Sevice Desk','Junk'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - invalid RelevantStates',
        Config => {
            Columns        => ['UnitTest1','UnitTest2'],
            Teams          => ['Sevice Desk','Junk'],
            RelevantStates => { 'open' => 1 },
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - invalid StopStates',
        Config => {
            Columns    => ['UnitTest1','UnitTest2'],
            Teams      => ['Sevice Desk','Junk'],
            StopStates => { 'closed' => 1 },
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'valid Config',
        Config => {
            Columns => ['UnitTest1','UnitTest2'],
            Teams   => ['Sevice Desk','Junk'],
        },
        Expect => 1
    },
    {
        Name   => 'valid Config - including RelevantStates and StopStates',
        Config => {
            Columns        => ['UnitTest1','UnitTest2'],
            Teams          => ['Sevice Desk','Junk'],
            RelevantStates => ['open'],
            StopStates     => ['closed'],
        },
        Expect => 1
    },
);
for my $Test ( @ConfigTests ) {
    # wrong config
    my $Result = $OutputHandlerObject->ValidateConfig(
        Config => $Test->{Config},
        Silent => $Test->{Silent},
    );

    if ( $Test->{Expect} ) {
        $Self->True(
            $Result,
            $OutputHandler . ' - ValidateConfig() - ' . $Test->{Name},
        );
    }
    else {
        $Self->False(
            $Result,
            $OutputHandler . ' - ValidateConfig() - ' . $Test->{Name},
        );
    }
}

## prepare team mapping
my $TeamID1   = 1;
my %Team1     = $Kernel::OM->Get('Queue')->QueueGet(
    ID => $TeamID1
);
my $TeamName1 = $Team1{Name};
my $TeamID2   = 2;
my %Team2     = $Kernel::OM->Get('Queue')->QueueGet(
    ID => $TeamID2
);
my $TeamName2 = $Team2{Name};
my $TeamID3   = 3;
my %Team3     = $Kernel::OM->Get('Queue')->QueueGet(
    ID => $TeamID3
);
my $TeamName3 = $Team3{Name};

## prepare state mapping
my $StateID1   = 1;
my %State1     = $Kernel::OM->Get('State')->StateGet(
    ID => $StateID1
);
my $StateName1 = $State1{Name};
my $StateID2   = 2;
my %State2     = $Kernel::OM->Get('State')->StateGet(
    ID => $StateID2
);
my $StateName2 = $State2{Name};
my $StateID3   = 3;
my %State3     = $Kernel::OM->Get('State')->StateGet(
    ID => $StateID3
);
my $StateName3 = $State3{Name};

# begin transaction on database
$Helper->BeginWork();

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2014-01-01 12:00:00',
);
$Helper->FixedTimeSet($SystemTime);

## prepare test ticket ##
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => $TeamID1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => $StateID1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID,
    'Created ticket with team id ' . $TeamID1
);

$Helper->FixedTimeAddSeconds(60);
my $Success = $Kernel::OM->Get('Ticket')->TicketQueueSet(
    QueueID   => $TeamID2,
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Changed ticket team to id ' . $TeamID2
);
$Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
    StateID   => $StateID2,
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Changed ticket state to id ' . $StateID2
);

$Helper->FixedTimeAddSeconds(60);
$Success = $Kernel::OM->Get('Ticket')->TicketQueueSet(
    QueueID   => $TeamID1,
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Changed ticket team to id ' . $TeamID1
);

$Helper->FixedTimeAddSeconds(60);
$Success = $Kernel::OM->Get('Ticket')->TicketQueueSet(
    QueueID   => $TeamID2,
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Changed ticket team to id ' . $TeamID2
);
$Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
    StateID   => $StateID3,
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Changed ticket state to id ' . $StateID3
);

$Helper->FixedTimeAddSeconds(60);
$Success = $Kernel::OM->Get('Ticket')->TicketQueueSet(
    QueueID   => $TeamID1,
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Changed ticket team to id ' . $TeamID1
);
$Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
    StateID   => $StateID2,
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Changed ticket state to id ' . $StateID2
);

$Helper->FixedTimeAddSeconds(60);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Ticket'],
);

my @DataTests = (
    {
        Name   => 'simple test',
        Config => {
            Columns => ['col1', 'col2', 'col3'],
            Teams   => [ $TeamName1, $TeamName2, $TeamName3 ]
        },
        Data   => {
            Columns => ['col1','col2','col3','col4'],
            Data => [
                {
                    col1 => $TicketID,
                    col2 => $TicketID,
                    col3 => $TicketID,
                    col4 => 'Test'
                },
            ]
        },
        Expect => {
            Columns => ['col1', 'col2', 'col3', 'col4'],
            Data    => [
                {
                    col1 => 180,
                    col2 => 120,
                    col3 => 0,
                    col4 => 'Test'
                },
            ]
        }
    },
    {
        Name   => 'simple test with OutputZeroAsEmptyString',
        Config => {
            Columns                 => ['col1', 'col2', 'col3'],
            Teams                   => [ $TeamName1, $TeamName2, $TeamName3 ],
            OutputZeroAsEmptyString => 1
        },
        Data   => {
            Columns => ['col1','col2','col3','col4'],
            Data => [
                {
                    col1 => $TicketID,
                    col2 => $TicketID,
                    col3 => $TicketID,
                    col4 => 'Test'
                },
            ]
        },
        Expect => {
            Columns => ['col1', 'col2', 'col3', 'col4'],
            Data    => [
                {
                    col1 => 180,
                    col2 => 120,
                    col3 => '',
                    col4 => 'Test'
                },
            ]
        }
    },
    {
        Name   => 'test with RelevantStates',
        Config => {
            Columns        => ['col1', 'col2', 'col3'],
            Teams          => [ $TeamName1, $TeamName2, $TeamName3 ],
            RelevantStates => [ $StateName2 ]
        },
        Data   => {
            Columns => ['col1','col2','col3','col4'],
            Data => [
                {
                    col1 => $TicketID,
                    col2 => $TicketID,
                    col3 => $TicketID,
                    col4 => 'Test'
                },
            ]
        },
        Expect => {
            Columns => ['col1', 'col2', 'col3', 'col4'],
            Data    => [
                {
                    col1 => 120,
                    col2 => 60,
                    col3 => 0,
                    col4 => 'Test'
                },
            ]
        }
    },
    {
        Name   => 'test with StopStates',
        Config => {
            Columns    => ['col1', 'col2', 'col3'],
            Teams      => [ $TeamName1, $TeamName2, $TeamName3 ],
            StopStates => [ $StateName3 ]
        },
        Data   => {
            Columns => ['col1','col2','col3','col4'],
            Data => [
                {
                    col1 => $TicketID,
                    col2 => $TicketID,
                    col3 => $TicketID,
                    col4 => 'Test'
                },
            ]
        },
        Expect => {
            Columns => ['col1', 'col2', 'col3', 'col4'],
            Data    => [
                {
                    col1 => 120,
                    col2 => 60,
                    col3 => 0,
                    col4 => 'Test'
                },
            ]
        }
    },
    {
        Name   => 'test with RelevantStates and StopStates',
        Config => {
            Columns        => ['col1', 'col2', 'col3'],
            Teams          => [ $TeamName1, $TeamName2, $TeamName3 ],
            RelevantStates => [ $StateName2 ],
            StopStates     => [ $StateName3 ]
        },
        Data   => {
            Columns => ['col1','col2','col3','col4'],
            Data => [
                {
                    col1 => $TicketID,
                    col2 => $TicketID,
                    col3 => $TicketID,
                    col4 => 'Test'
                },
            ]
        },
        Expect => {
            Columns => ['col1', 'col2', 'col3', 'col4'],
            Data    => [
                {
                    col1 => 60,
                    col2 => 60,
                    col3 => 0,
                    col4 => 'Test'
                },
            ]
        }
    }
);
for my $Test ( @DataTests ) {
    my $Result = $OutputHandlerObject->Run(
        Config => $Test->{Config},
        Data   => $Test->{Data},
    );

    $Self->IsDeeply(
        $Result,
        $Test->{Expect},
        $OutputHandler . ' - Run() - ' . $Test->{Name},
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
