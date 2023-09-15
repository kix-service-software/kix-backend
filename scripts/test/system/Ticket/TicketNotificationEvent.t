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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# force rich text editor
my $Success = $Kernel::OM->Get('Config')->Set(
    Key   => 'Frontend::RichText',
    Value => 1,
);
$Self->True(
    $Success,
    'Force RichText with true',
);

# use DoNotSendEmail email backend
$Success = $Kernel::OM->Get('Config')->Set(
    Key   => 'SendmailModule',
    Value => 'Kernel::System::Email::DoNotSendEmail',
);
$Self->True(
    $Success,
    'Set DoNotSendEmail backend with true',
);

# send notifications without daemon
$Success = $Kernel::OM->Get('Config')->Set(
    Key   => 'TicketNotification::SendAsynchronously',
    Value => '0',
);
$Self->True(
    $Success,
    'Set TicketNotification::SendAsynchronously with false',
);

# create a new user for current test
my $UserLogin = $Helper->TestUserCreate(
    Groups => ['users'],
);

my %UserData = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin,
);

my $UserID = $UserData{UserID};

my %UserContactData = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $UserID,
);

# create new customer user for current test
my $ContactID = $Helper->TestContactCreate();

my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID,
);

# create ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Ticket One Title',
    QueueID        => 1,
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'new',
    OrganisationID => 'example.com',
    ContactID      => $ContactData{Email},
    OwnerID        => $UserID,
    UserID         => $UserID,
);

# sanity check
$Self->True(
    $TicketID,
    "TicketCreate() successful for Ticket ID $TicketID",
);

# get ticket number
my $TicketNumber = $Kernel::OM->Get('Ticket')->TicketNumberLookup(
    TicketID => $TicketID,
    UserID   => $UserID,
);

$Self->True(
    $TicketNumber,
    "TicketNumberLookup() successful for Ticket# $TicketNumber",
);

my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID       => $TicketID,
    Channel        => 'note',
    CustomerVisible => 1,
    SenderType     => 'external',
    From           => $ContactData{Email},
    To             => $UserContactData{Email},
    Subject        => 'some short description',
    Body           => 'the message text',
    Charset        => 'utf8',
    MimeType       => 'text/plain',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'Some free text!',
    UserID         => 1,
);

# sanity check
$Self->True(
    $ArticleID,
    "ArticleCreate() successful for Article ID $ArticleID",
);

# create add note notification
my $NotificationID = $Kernel::OM->Get('NotificationEvent')->NotificationAdd(
    Name => 'Customer notification',
    Data => {
        Events             => ['ArticleCreate'],
        Recipients         => ['Customer'],
        Transports         => ['Email'],
        CreateArticle      => ['1'],
        Channel            => ['email'],
        VisibleForCustomer => ['1'],
    },
    Message => {
        en => {
            Subject => 'Test external note',

            # include non-breaking space (bug#10970)
            Body => 'Ticket:&nbsp;<KIX_TICKET_TicketID>&nbsp;<KIX_OWNER_Firstname>',

            ContentType => 'text/html',
        },
    },
    Comment => 'An optional comment',
    ValidID => 1,
    UserID  => 1,
);

# sanity check
$Self->IsNot(
    $NotificationID,
    undef,
    'NotificationAdd() should not be undef',
);

my $Result = $Kernel::OM->Get('Kernel::System::Ticket::Event::NotificationEvent')->Run(
    Event => 'ArticleCreate',
    Data  => {
        TicketID => $TicketID,
    },
    Config => {},
    UserID => 1,
);

$Self->True(
    $Result,
    'ArticleCreate event raised'
);

# get ticket article IDs
my @ArticleIDs = $Kernel::OM->Get('Ticket')->ArticleIndex(
    TicketID => $TicketID,
);

$Self->Is(
    scalar @ArticleIDs,
    2,
    'ArticleIndex() should return two elements',
);

# get last article
my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
    ArticleID => $ArticleIDs[-1],    # last
    UserID    => $UserID,
);

$Self->Is(
    $Article{Channel}.'-'.$Article{CustomerVisible},
    'email-1',
    'ArticleGet() should return external notification',
);

$Self->Is(
    $Article{Subject},
    'Test external note [' . $Kernel::OM->Get('Config')->Get('Ticket::Hook') . $TicketNumber . ']' ,
    'ArticleGet() subject contains notification subject',
);

# delete notification event
my $NotificationDelete = $Kernel::OM->Get('NotificationEvent')->NotificationDelete(
    ID     => $NotificationID,
    UserID => 1,
);

# sanity check
$Self->True(
    $NotificationDelete,
    "NotificationDelete() successful for Notification ID $NotificationID",
);

# delete the ticket
my $TicketDelete = $Kernel::OM->Get('Ticket')->TicketDelete(
    TicketID => $TicketID,
    UserID   => $UserID,
);

# sanity check
$Self->True(
    $TicketDelete,
    "TicketDelete() successful for Ticket ID $TicketID",
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
