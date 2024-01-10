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
my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::Article::StorageSwitch');
my $TicketObject  = $Kernel::OM->Get('Ticket');

my $HelperObject = $Kernel::OM->Get('UnitTest::Helper');

# make sure ticket is created in ArticleStorageDB
$HelperObject->ConfigSettingChange(
    Valid => 1,
    Key   => 'Ticket::StorageModule',
    Value => 'Kernel::System::Ticket::ArticleStorageDB',
);

# create isolated time environment during test
$HelperObject->FixedTimeSet(
    $Kernel::OM->Get('Time')->TimeStamp2SystemTime( String => '2000-10-20 00:00:00' ),
);

# create test ticket with attachments
my $TicketID = $TicketObject->TicketCreate(
    Title        => 'Some Ticket_Title',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'closed',
    OwnerID      => 1,
    UserID       => 1,
);
$Self->True(
    $TicketID,
    'TicketCreate()',
);

my $ArticleID = $TicketObject->ArticleCreate(
    TicketID       => $TicketID,
    Channel        => 'note',
    SenderType     => 'agent',
    From           => 'Some Agent <email@example.com>',
    To             => 'Some Customer <customer-a@example.com>',
    Subject        => 'some short description',
    Body           => 'the message text',
    ContentType    => 'text/plain; charset=ISO-8859-15',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'Some free text!',
    UserID         => 1,
    Attachment     => [
        {
            Content     => 'empty',
            ContentType => 'text/csv',
            Filename    => 'Test 1.txt',
        },
        {
            Content     => 'empty',
            ContentType => 'text/csv',
            Filename    => 'Test_1.txt',
        },
        {
            Content     => 'empty',
            ContentType => 'text/csv',
            Filename    => 'Test-1.txt',
        },
        {
            Content     => 'empty',
            ContentType => 'text/csv',
            Filename    => 'Test_1-1.txt',
        },
    ],
    NoAgentNotify => 1,
);
$Self->True(
    $ArticleID,
    'ArticleCreate()',
);

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

for my $Backend (qw(FS DB)) {

    # try to execute command without any options
    my $ExitCode = $CommandObject->Execute();
    $Self->Is(
        $ExitCode,
        1,
        "$Backend No options",
    );

    # provide options
    $ExitCode = $CommandObject->Execute(
        '--target',
        'ArticleStorage' . $Backend,
        '--tickets-closed-before-date',
        '2000-10-21 00:00:00'
    );
    $Self->Is(
        $ExitCode,
        0,
        "$Backend with option: --target ArticleStorage$Backend --tickets-closed-before-date 2000-10-21 00:00:00",
    );
}

# delete test ticket
$TicketObject->TicketDelete(
    TicketID => $TicketID,
    UserID   => 1,
);
$Self->True(
    $TicketID,
    'TicketDelete()',
);

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
