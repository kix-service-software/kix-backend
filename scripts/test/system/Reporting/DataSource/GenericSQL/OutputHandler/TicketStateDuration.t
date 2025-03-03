# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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
my $OutputHandler       = 'TicketStateDuration';
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
            States => ['new'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - invalid Columns',
        Config => {
            Columns => { 'UnitTest1' => 1 },
            States  => ['new'],
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
            States  => { 'new' => 1 },
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - more entries in Columns than States',
        Config => {
            Columns => ['UnitTest1','UnitTest2'],
            States  => ['new'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'invalid Config - less entries in Columns than States',
        Config => {
            Columns => ['UnitTest1'],
            States  => ['new','open'],
        },
        Expect => undef,
        Silent => 1,
    },
    {
        Name   => 'valid Config',
        Config => {
            Columns => ['UnitTest1','UnitTest2'],
            States  => ['new','open'],
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
    QueueID        => 1,
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
    'Created ticket with state id ' . $StateID1
);

$Helper->FixedTimeAddSeconds(60);
my $Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
    StateID   => $StateID2,
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Changed ticket state to id ' . $StateID2
);

$Helper->FixedTimeAddSeconds(60);
$Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
    StateID   => $StateID1,
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Changed ticket state to id ' . $StateID1
);

$Helper->FixedTimeAddSeconds(60);
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
$Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
    StateID   => $StateID1,
    TicketID  => $TicketID,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Changed ticket state to id ' . $StateID1
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
            States  => [ $StateName1, $StateName2, $StateName3 ]
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
            States                  => [ $StateName1, $StateName2, $StateName3 ],
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
