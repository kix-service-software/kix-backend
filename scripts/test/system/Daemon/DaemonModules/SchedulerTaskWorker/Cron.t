# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
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

my $ContactID = $Helper->TestContactCreate();
my %Contact   = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID,
);

my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => $Contact{PrimaryOrganisationID},
    ContactID      => $ContactID,
    OwnerID        => 1,
    UserID         => 1,
);

# prevent mails send
$Kernel::OM->Get('Config')->Set(
    Key   => 'SendmailModule',
    Value => 'Kernel::System::Email::DoNotSendEmail',
);

my @Tests = (
    {
        Name   => 'Empty',
        Config => {},
        Result => 0,
        Silent => 1,
    },
    {
        Name   => 'Missing TaskID',
        Config => {
            TaskName => 'UnitTest',
            Data     => {
                Module => 'Console::Command::Maint::Ticket::Test',
                Params => ['-h'],
            },
        },
        Result => 0,
        Silent => 1,
    },
    {
        Name   => 'Missing Data',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
        },
        Result => 0,
        Silent => 1,
    },
    {
        Name   => 'Wrong Data',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => 1,
        },
        Result => 0,
        Silent => 1,
    },
    {
        Name   => 'Empty Data',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {},
        },
        Result => 0,
        Silent => 1,
    },
    {
        Name   => 'Missing Module',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {
                Params => ['-h'],
            },
        },
        Result => 0,
        Silent => 1,
    },
    {
        Name   => 'Wrong Console Module',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {
                Module   => 'Kernel::System::Console::Command::Maint::Ticket::Test',
                Function => 'Execute',
                Params   => ['-h'],
            },
        },
        Result => 0,
        Silent => 1,
    },
    {
        Name   => 'Wrong Console Module Function',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {
                Module   => 'Kernel::System::Console::Command::Admin::Role::Add',
                Function => 'Test',
                Params   => ['--no-ansi'],
            },
        },
        Result => 0,
    },
    {
        Name   => 'Wrong Console Module Params',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {
                Module   => 'Console::Command::Admin::Role::Add',
                Function => 'Execute',
                Params   => ['-h'],
            },
        },
        Result => 0,
    },
    {
        Name   => 'Wrong Core Module Function',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {
                Module   => 'Priority',
                Function => 'Test',
                Params   => [ 'PriorityID', '1' ],
            },
        },
        Result => 0,
    },
    {
        Name   => 'Wrong Core Module Params',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {
                Module   => 'Priority',
                Function => 'PriorityLookup',
                Params   => [ 'TicketID', '1' ],
            },
        },
        Result => 0,
    },
    {
        Name   => 'Console Command Module (wrong params format)',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {
                Module   => 'Console::Command::Maint::Ticket::Dump',
                Function => 'Execute',
                Params   => '--article-limit 2 1',
            },
        },
        Result => 0,
        Silent => 1,
    },
    {
        Name   => 'Core Module (wrong params format)',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {
                Module   => 'Priority',
                Function => 'PriorityLookup',
                Params   => 'PriorityID 1',
            },
        },
        Result => 0,
        Silent => 1,
    },
    {
        Name   => 'Console Command Module',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {
                Module   => 'Console::Command::Maint::Ticket::Dump',
                Function => 'Execute',
                Params   => [ '--article-limit', '2', $TicketID, '--quiet' ],
            },
        },
        Result => 1,
    },
    {
        Name   => 'Core Module',
        Config => {
            TaskID   => 123,
            TaskName => 'UnitTest',
            Data     => {
                Module   => 'Priority',
                Function => 'PriorityLookup',
                Params   => [ 'PriorityID', '1' ],
            },
        },
        Result => 1,
    },
);

# get task handler object
my $TaskHandlerObject = $Kernel::OM->Get('Daemon::DaemonModules::SchedulerTaskWorker::Cron');

for my $Test (@Tests) {

    # result task
    my $Result = $TaskHandlerObject->Run(
        %{ $Test->{Config} },
        Silent => $Test->{Silent},
    );

    $Self->Is(
        $Result || 0,
        $Test->{Result},
        "$Test->{Name} - execution result",
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
