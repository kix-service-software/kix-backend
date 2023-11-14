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
my $ContactObject = $Kernel::OM->Get('Contact');
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

my $ContactID = $Helper->TestContactCreate();
my %Contact = $ContactObject->ContactGet(
    ID => $ContactID
);

my $TestUserLogin = $Helper->TestUserCreate(
    Roles => ['Ticket Agent'],
);
my $TestUserID = $UserObject->UserLookup(
    UserLogin => $TestUserLogin,
);

my $TicketID = $TicketObject->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => $Contact{PrimaryOrganisationID},
    ContactID      => $ContactID,
    OwnerID        => $TestUserID,
    UserID         => 1,
);
$Self->True(
    $TicketID,
    'TicketCreate()',
);

my %Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID,
    Extended => 1,
);
$Self->Is(
    $Ticket{Title},
    'Some Ticket_Title',
    'TicketGet() (Title)',
);
$Self->Is(
    $Ticket{Queue},
    'Junk',
    'TicketGet() (Queue)',
);
$Self->Is(
    $Ticket{Priority},
    '3 normal',
    'TicketGet() (Priority)',
);
$Self->Is(
    $Ticket{State},
    'closed',
    'TicketGet() (State)',
);
$Self->Is(
    $Ticket{Owner},
    $TestUserLogin,
    'TicketGet() (Owner)',
);
$Self->Is(
    $Ticket{CreateBy},
    1,
    'TicketGet() (CreateBy)',
);
$Self->Is(
    $Ticket{ChangeBy},
    1,
    'TicketGet() (ChangeBy)',
);
$Self->Is(
    $Ticket{Title},
    'Some Ticket_Title',
    'TicketGet() (Title)',
);
$Self->Is(
    $Ticket{Responsible},
    'admin',
    'TicketGet() (Responsible)',
);
$Self->Is(
    $Ticket{Lock},
    'unlock',
    'TicketGet() (Lock)',
);

my $DefaultTicketType = $Kernel::OM->Get('Config')->Get('Ticket::Type::Default');
$Self->Is(
    $Ticket{TypeID},
    $TypeObject->TypeLookup( Type => $DefaultTicketType ),
    'TicketGet() (TypeID)',
);

my $TicketIDCreatedBy = $TicketObject->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => $Contact{PrimaryOrganisationID},
    ContactID      => $ContactID,
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
    $CheckCreatedBy{OwnerID},
    $TestUserID,
    'TicketOwnerSet()',
);

$Self->Is(
    $CheckCreatedBy{ChangeBy},
    1,
    'TicketOwnerSet() (ChangeBy - System ID 1 now)',
);

my $ArticleID = $TicketObject->ArticleCreate(
    TicketID    => $TicketID,
    Channel     => 'note',
    SenderType  => 'agent',
    From =>
        'Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent <email@example.com>',
    To =>
        'Some Customer A Some Customer A Some Customer A Some Customer A Some Customer A Some Customer A  Some Customer ASome Customer A Some Customer A <customer-a@example.com>',
    Cc =>
        'Some Customer B Some Customer B Some Customer B Some Customer B Some Customer B Some Customer B Some Customer B Some Customer B Some Customer B <customer-b@example.com>',
    ReplyTo =>
        'Some Customer B Some Customer B Some Customer B Some Customer B Some Customer B Some Customer B Some Customer B Some Customer B Some Customer B <customer-b@example.com>',
    Subject =>
        'some short description some short description some short description some short description some short description some short description some short description some short description ',
    Body => (
        'the message text
Perl modules provide a range of features to help you avoid reinventing the wheel, and can be downloaded from CPAN ( http://www.cpan.org/ ). A number of popular modules are included with the Perl distribution itself.

Categories of modules range from text manipulation to network protocols to database integration to graphics. A categorized list of modules is also available from CPAN.

To learn how to install modules you download from CPAN, read perlmodinstall

To learn how to use a particular module, use perldoc Module::Name . Typically you will want to use Module::Name , which will then give you access to exported functions or an OO interface to the module.

perlfaq contains questions and answers related to many common tasks, and often provides suggestions for good CPAN modules to use.

perlmod describes Perl modules in general. perlmodlib lists the modules which came with your Perl installation.

If you feel the urge to write Perl modules, perlnewmod will give you good advice.
' x 200
    ),    # create a really big string by concatenating 200 times

    ContentType    => 'text/plain; charset=ISO-8859-15',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'Some free text!',
    UserID         => 1,
    NoAgentNotify  => 1,                                   # if you don't want to send agent notifications
);

$Self->True(
    $ArticleID,
    'ArticleCreate()',
);

$Self->Is(
    $TicketObject->ArticleCount( TicketID => $TicketID ),
    1,
    'ArticleCount',
);

my %Article = $TicketObject->ArticleGet( ArticleID => $ArticleID );
$Self->True(
    $Article{From} eq
        'Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent Some Agent <email@example.com>',
    'ArticleGet()',
);

for my $Key (qw( Body Subject From To ReplyTo )) {
    my $Success = $TicketObject->ArticleUpdate(
        ArticleID => $ArticleID,
        Key       => $Key,
        Value     => "New $Key",
        UserID    => 1,
        TicketID  => $TicketID,
    );
    $Self->True(
        $Success,
        'ArticleUpdate()',
    );
    my %Article2 = $TicketObject->ArticleGet( ArticleID => $ArticleID );
    $Self->Is(
        $Article2{$Key},
        "New $Key",
        'ArticleUpdate()',
    );

    # set old value
    $Success = $TicketObject->ArticleUpdate(
        ArticleID => $ArticleID,
        Key       => $Key,
        Value     => $Article{$Key},
        UserID    => 1,
        TicketID  => $TicketID,
    );
}

my $TicketSearchTicketNumber = substr $Ticket{TicketNumber}, 0, 10;
my %TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        OR => [
            {
                Field    => 'TicketNumber',
                Value    => $TicketSearchTicketNumber,
                Operator => 'STARTSWITH',
            },
            {
                Field    => 'TicketNumber',
                Value    => 'not existing',
                Operator => 'CONTAINS',
            }
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);

$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketNumber STARTSWITH or CONTAINS)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field    => 'TicketNumber',
                Value    => $Ticket{TicketNumber},
                Operator => 'EQ',
            },
        ]
    },
    UserID       => 1,
    Permission   => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketNumber EQUALS)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field    => 'Age',
                Value    => 3600,
                Operator => 'LT',
            },
        ]
    },
    UserID       => 1,
    Permission   => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Age LT)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'HASH',
    Limit        => 100,
    Search       => {
        AND => [
            {
                Field => 'Age',
                Value => 3600,
                Operator => 'GT',
            },
        ]
    },
    UserID       => 1,
    Permission   => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Age GT)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search       => {
        AND => [
            {
                Field => 'TicketID',
                Value => $TicketID,
                Operator => 'EQ',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);

$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketID EQUALS)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        OR => [
            {
                Field => 'TicketID',
                Value => $TicketID,
                Operator => 'EQ',
            },
            {
                Field => 'TicketID',
                Value => 42,
                Operator => 'EQ',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);

$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketID EQUALS A or B)',
);

my $Count = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'COUNT',
    Search       => {
        OR => [
            {
                Field => 'TicketNumber',
                Value => $Ticket{TicketNumber},
                Operator => 'EQ',
            },
        ]
    },
    UserID       => 1,
    Permission   => 'rw',
);
$Self->Is(
    $Count,
    1,
    'TicketSearch() (COUNT:TicketNumber EQUALS)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'HASH',
    Limit        => 100,
    Search       => {
        OR => [
            {
                Field => 'TicketNumber',
                Value => [ $Ticket{TicketNumber}, '1234' ],
                Operator => 'IN',
            },
        ]
    },
    UserID       => 1,
    Permission   => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketNumber IN)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        OR => [
            {
                Field => 'Title',
                Value => $Ticket{Title},
                Operator => 'EQ',
            },
        ]
    },
    Title      => $Ticket{Title},
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Title EQUALS)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        OR => [
            {
                Field => 'Title',
                Value => $Ticket{Title},
                Operator => 'EQ',
            },
            {
                Field => 'Title',
                Value => 'SomeTitleABC',
                Operator => 'EQ',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Title EQUALS A or B)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        OR => [
            {
                Field => 'OrganisationID',
                Value => $Ticket{OrganisationID},
                Operator => 'EQ',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:OrganisationID EQUALS)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        OR => [
            {
                Field => 'OrganisationID',
                Value => [ $Ticket{OrganisationID}, 12_345 ],
                Operator => 'IN',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:OrganisationID IN)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'OrganisationID',
                Value => $Ticket{OrganisationID},
                Operator => 'EQ',
            },
            {
                Field => 'OrganisationID',
                Value => 12_345,
                Operator => 'EQ',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);
$Self->False(
    scalar $TicketIDs{$TicketID},
    'TicketSearch() (HASH:OrganisationID EQUALS A and B)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result            => 'HASH',
    Limit             => 100,
    Search     => {
        OR => [
            {
                Field => 'ContactID',
                Value => $Ticket{ContactID},
                Operator => 'EQ',
            },
        ]
    },
    UserID            => 1,
    Permission        => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:ContactID EQUALS)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result            => 'HASH',
    Limit             => 100,
    Search     => {
        OR => [
            {
                Field => 'ContactID',
                Value => [ $Ticket{ContactID}, '1234' ],
                Operator => 'IN',
            },
        ]
    },
    UserID            => 1,
    Permission        => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:ContactID IN)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result            => 'HASH',
    Limit             => 100,
    Search     => {
        AND => [
            {
                Field => 'TicketNumber',
                Value => $Ticket{TicketNumber},
                Operator => 'EQ',
            },
            {
                Field => 'Title',
                Value => $Ticket{Title},
                Operator => 'EQ',
            },
            {
                Field => 'ContactID',
                Value => $Ticket{ContactID},
                Operator => 'EQ',
            },
            {
                Field => 'OrganisationID',
                Value => $Ticket{OrganisationID},
                Operator => 'EQ',
            },
        ]
    },
    UserID            => 1,
    Permission        => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketNumber and Title and OrganisationID and ContactID EQUALS)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result            => 'HASH',
    Limit             => 100,
    Search     => {
        AND => [
            {
                Field => 'TicketNumber',
                Value => [ $Ticket{TicketNumber}, 'ABC' ],
                Operator => 'IN',
            },
            {
                Field => 'Title',
                Value => [ $Ticket{Title}, '123' ],
                Operator => 'IN',
            },
            {
                Field => 'ContactID',
                Value => [ $Ticket{ContactID}, 12_345 ],
                Operator => 'IN',
            },
            {
                Field => 'OrganisationID',
                Value => [ $Ticket{OrganisationID}, 12_345 ],
                Operator => 'IN',
            },
        ]
    },
    UserID            => 1,
    Permission        => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketNumber and Title and OrganisationID and ContactID IN)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result            => 'HASH',
    Limit             => 100,
    Search     => {
        OR => [
            {
                Field => 'TicketNumber',
                Value => [ $Ticket{TicketNumber}, 'ABC' ],
                Operator => 'IN',
            },
            {
                Field => 'Title',
                Value => [ $Ticket{Title}, '123' ],
                Operator => 'IN',
            },
            {
                Field => 'ContactID',
                Value => [ $Ticket{ContactID}, 12_345 ],
                Operator => 'IN',
            },
            {
                Field => 'OrganisationID',
                Value => [ $Ticket{OrganisationID}, 12_345 ],
                Operator => 'IN',
            },
        ]
    },
    UserID            => 1,
    Permission        => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketNumber or Title or OrganisationID or ContactID IN)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'HASH',
    Limit        => 100,
    Search     => {
        AND => [
            {
                Field => 'TicketNumber',
                Value => [ $Ticket{TicketNumber}, 'ABC' ],
                Operator => 'IN',
            },
            {
                Field => 'StateType',
                Value => 'Closed',
                Operator => 'EQ',
            },
        ]
    },
    UserID       => 1,
    Permission   => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketNumber,StateType:Closed)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'HASH',
    Limit        => 100,
    Search     => {
        AND => [
            {
                Field => 'TicketNumber',
                Value => [ $Ticket{TicketNumber}, 'ABC' ],
                Operator => 'IN',
            },
            {
                Field => 'StateType',
                Value => 'Open',
                Operator => 'EQ',
            },
        ]
    },
    UserID       => 1,
    Permission   => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketNumber,StateType:Open)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result              => 'HASH',
    Limit               => 100,
    Search     => {
        AND => [
            {
                Field => 'Body',
                Value => 'perl modules',
                Operator => 'CONTAINS',
            },
            {
                Field => 'StateType',
                Value => 'Closed',
                Operator => 'EQ',
            },
        ]
    },
    UserID              => 1,
    Permission          => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Body,StateType:Closed)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result              => 'HASH',
    Limit               => 100,
    Search     => {
        AND => [
            {
                Field => 'Body',
                Value => 'perl modules',
                Operator => 'CONTAINS',
            },
            {
                Field => 'StateType',
                Value => 'Open',
                Operator => 'EQ',
            },
        ]
    },
    UserID              => 1,
    Permission          => 'rw',
);
$Self->True(
    !$TicketIDs{$TicketID},
    'TicketSearch() (HASH:Body,StateType:Open)',
);

$TicketObject->TicketQueueSet(
    Queue              => 'Junk',
    TicketID           => $TicketID,
    SendNoNotification => 1,
    UserID             => 1,
);

$TicketObject->TicketQueueSet(
    Queue              => 'Junk',
    TicketID           => $TicketID,
    SendNoNotification => 1,
    UserID             => 1,
);

my %HD = $TicketObject->HistoryTicketGet(
    StopYear  => 4000,
    StopMonth => 1,
    StopDay   => 1,
    TicketID  => $TicketID,
    Force     => 1,
);
my $QueueLookupID = $QueueObject->QueueLookup( Queue => $HD{Queue} );
$Self->Is(
    $QueueLookupID,
    $HD{QueueID},
    'HistoryTicketGet() Check history queue',
);

my $TicketMove = $TicketObject->TicketQueueSet(
    Queue              => 'Junk',
    TicketID           => $TicketID,
    SendNoNotification => 1,
    UserID             => 1,
);
$Self->True(
    $TicketMove,
    'MoveTicket()',
);

my $TicketState = $TicketObject->TicketStateSet(
    State    => 'open',
    TicketID => $TicketID,
    UserID   => 1,
);
$Self->True(
    $TicketState,
    'StateSet()',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'HASH',
    Limit        => 100,
    Search       => {
        AND => [
            {
                Field => 'TicketNumber',
                Value => [$Ticket{TicketNumber}, 'ABC'],
                Operator => 'IN',
            },
            {
                Field => 'StateType',
                Value => 'Open',
                Operator => 'EQ',
            }
        ]
    },
    UserID       => 1,
    Permission   => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketNumber,StateType:Open)',
);

%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'HASH',
    Limit        => 100,
    Search       => {
        AND => [
            {
                Field => 'TicketNumber',
                Value => [$Ticket{TicketNumber}, 'ABC'],
                Operator => 'IN',
            },
            {
                Field => 'StateType',
                Value => 'Closed',
                Operator => 'EQ',
            }
        ]
    },
    UserID       => 1,
    Permission   => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:TicketNumber,StateType:Closed)',
);

my $TicketPriority = $TicketObject->TicketPrioritySet(
    Priority => '4 low',
    TicketID => $TicketID,
    UserID   => 1,
);
$Self->True(
    $TicketPriority,
    'PrioritySet()',
);

# get ticket data
my %TicketData = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

# save current change_time
my $ChangeTime = $TicketData{Changed};

# wait 5 seconds
$Helper->FixedTimeAddSeconds(5);

my $TicketTitle = $TicketObject->TicketTitleUpdate(
    Title => 'Very long title 01234567890123456789012345678901234567890123456789'
        . '0123456789012345678901234567890123456789012345678901234567890123456789'
        . '0123456789012345678901234567890123456789012345678901234567890123456789'
        . '0123456789012345678901234567890123456789',
    TicketID => $TicketID,
    UserID   => 1,
);
$Self->True(
    $TicketTitle,
    'TicketTitleUpdate()',
);

# get updated ticket data
%TicketData = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

# compare current change_time with old one
$Self->IsNot(
    $ChangeTime,
    $TicketData{Changed},
    'Change_time updated in TicketTitleUpdate()',
);

# check if we have a Ticket Title Update history record
my @HistoryLines = $TicketObject->HistoryGet(
    TicketID => $TicketID,
    UserID   => 1,
);
my $HistoryItem = pop @HistoryLines;
$Self->Is(
    $HistoryItem->{HistoryType},
    'TitleUpdate',
    "TicketTitleUpdate - found HistoryItem",
);

$Self->Is(
    $HistoryItem->{Name},
    '%%Some Ticket_Title%%Very long title 0123456789012345678901234567890123...',
    "TicketTitleUpdate - Found new title",
);

# get updated ticket data
%TicketData = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

# save current change_time
$ChangeTime = $TicketData{Changed};

# wait 5 seconds
$Helper->FixedTimeAddSeconds(5);

# set unlock timeout
my $UnlockTimeout = $TicketObject->TicketUnlockTimeoutUpdate(
    UnlockTimeout => $TimeObject->SystemTime() + 10_000,
    TicketID      => $TicketID,
    UserID        => 1,
);

$Self->True(
    $UnlockTimeout,
    'TicketUnlockTimeoutUpdate()',
);

# get updated ticket data
%TicketData = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

# compare current change_time with old one
$Self->IsNot(
    $ChangeTime,
    $TicketData{Changed},
    'Change_time updated in TicketUnlockTimeoutUpdate()',
);

# save current change_time
$ChangeTime = $TicketData{Changed};

# save current queue
my $CurrentQueueID = $TicketData{QueueID};

# wait 5 seconds
$Helper->FixedTimeAddSeconds(5);

my $NewQueue = $CurrentQueueID != 1 ? 1 : 2;

# set queue
my $TicketQueueSet = $TicketObject->TicketQueueSet(
    QueueID  => $NewQueue,
    TicketID => $TicketID,
    UserID   => 1,
);

$Self->True(
    $TicketQueueSet,
    'TicketQueueSet()',
);

# get updated ticket data
%TicketData = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

# compare current change_time with old one
$Self->IsNot(
    $ChangeTime,
    $TicketData{Changed},
    'Change_time updated in TicketQueueSet()',
);

# restore queue
$TicketQueueSet = $TicketObject->TicketQueueSet(
    QueueID  => $CurrentQueueID,
    TicketID => $TicketID,
    UserID   => 1,
);

# save current change_time
$ChangeTime = $TicketData{Changed};

# save current type
my $CurrentTicketType = $TicketData{TypeID};

# wait 5 seconds
$Helper->FixedTimeAddSeconds(5);

# create a test type
my $TypeID = $TypeObject->TypeAdd(
    Name    => 'Type' . $Helper->GetRandomID(),
    ValidID => 1,
    UserID  => 1,
);

# set type
my $TicketTypeSet = $TicketObject->TicketTypeSet(
    TypeID   => $TypeID,
    TicketID => $TicketID,
    UserID   => 1,
);

$Self->True(
    $TicketTypeSet,
    'TicketTypeSet()',
);

# get updated ticket data
%TicketData = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

# compare current change_time with old one
$Self->IsNot(
    $ChangeTime,
    $TicketData{Changed},
    'Change_time updated in TicketTypeSet()',
);

# restore type
$TicketTypeSet = $TicketObject->TicketTypeSet(
    TypeID   => $CurrentTicketType,
    TicketID => $TicketID,
    UserID   => 1,
);

# set as invalid the test type
$TypeObject->TypeUpdate(
    ID      => $TypeID,
    Name    => 'Type' . $Helper->GetRandomID(),
    ValidID => 2,
    UserID  => 1,
);

# wait 1 seconds
$Helper->FixedTimeAddSeconds(1);

# save current change_time
$ChangeTime = $TicketData{Changed};

# wait 5 seconds
$Helper->FixedTimeAddSeconds(5);

# save current change_time
$ChangeTime = $TicketData{Changed};

# wait 5 seconds
$Helper->FixedTimeAddSeconds(5);

# get updated ticket data
%TicketData = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

my $TicketLock = $TicketObject->TicketLockSet(
    Lock               => 'lock',
    TicketID           => $TicketID,
    SendNoNotification => 1,
    UserID             => 1,
);
$Self->True(
    $TicketLock,
    'TicketLockSet()',
);

# Test CreatedUserIDs
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result         => 'HASH',
    Limit          => 100,
    Search         => {
        AND => [
            {
                Field    => 'CreatedUserID',
                Value    => [ 1, 455, 32 ],
                Operator => 'IN',
            },
        ]
    },
    Sort => [
        {
            Field => "TicketID",
            Direction => 'descending',
        },
    ],
    UserID         => 1,
    Permission     => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:CreatedUserID IN)',
);

# Test CreatedPriorityIDs
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result             => 'HASH',
    Limit              => 100,
    Search             => {
        AND => [
            {
                Field    => 'CreatedPriorityID',
                Value    => [ 2, 3 ],
                Operator => 'IN',
            },
        ]
    },
    Sort => [
        {
            Field     => "TicketID",
            Direction => 'descending',
        },
    ],
    UserID             => 1,
    Permission         => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:CreatedPriorityID IN)',
);

# Test CreatedStateIDs
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result          => 'HASH',
    Limit           => 100,
    Search       => {
        AND => [
            {
                Field    => 'CreatedStateID',
                Value    => [ 4 ],
                Operator => 'IN',
            },
        ]
    },
    Sort => [
        {
            Field => "TicketID",
            Direction => 'descending',
        },
    ],
    UserID          => 1,
    Permission      => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:CreatedStateID IN)',
);

# Test CreatedQueueIDs
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result          => 'HASH',
    Limit           => 100,
    Search       => {
        AND => [
            {
                Field => 'CreatedQueueID',
                Value => [ 2, 3 ],
                Operator => 'IN',
            },
        ]
    },
    Sort => [
        {
            Field => "TicketID",
            Direction => 'descending',
        },
    ],
    UserID          => 1,
    Permission      => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:CreatedQueueID IN)',
);

# Test CreateTime
my $CreateTime = $TimeObject->SystemTime2TimeStamp(
    SystemTime => $TimeObject->SystemTime() - 3600,
);
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result                       => 'HASH',
    Limit                        => 100,
    Search       => {
        AND => [
            {
                Field => 'CreateTime',
                Value => $CreateTime,
                Operator => 'GTE',
            },
        ]
    },
    UserID                       => 1,
    Permission                   => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Ticket CreateTime >= now()-60 min)',
);

# Test LastChangeTime
$CreateTime = $TimeObject->SystemTime2TimeStamp(
    SystemTime => $TimeObject->SystemTime() - 3600,
);
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result                           => 'HASH',
    Limit                            => 100,
    Search       => {
        AND => [
            {
                Field => 'LastChangeTime',
                Value => $ChangeTime,
                Operator => 'GTE',
            },
        ]
    },
    UserID                           => 1,
    Permission                       => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Ticket LastChangeTime >= now()-60 min)',
);

# Test ArticleCreateTime
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result                        => 'HASH',
    Limit                         => 100,
    Search       => {
        AND => [
            {
                Field => 'ArticleCreateTime',
                Value => $CreateTime,
                Operator => 'GTE',
            },
        ]
    },
    UserID                        => 1,
    Permission                    => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Article CreateTime >= now()-60 min)',
);

# Test CreateTime
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result                       => 'HASH',
    Limit                        => 100,
    Search       => {
        AND => [
            {
                Field => 'CreateTime',
                Value => $CreateTime,
                Operator => 'LT',
            },
        ]
    },
    UserID                       => 1,
    Permission                   => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Ticket CreateTime < now()-60 min)',
);

# Test TicketLastChangeOlderMinutes
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result                           => 'HASH',
    Limit                            => 100,
    Search       => {
        AND => [
            {
                Field => 'LastChangeTime',
                Value => $ChangeTime,
                Operator => 'LT',
            },
        ]
    },
    UserID                           => 1,
    Permission                       => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Ticket LastChangeTime < now()-60 min)',
);

# Test ArticleCreateTime
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result                        => 'HASH',
    Limit                         => 100,
    Search       => {
        AND => [
            {
                Field => 'ArticleCreateTime',
                Value => $CreateTime,
                Operator => 'LT',
            },
        ]
    },
    UserID                        => 1,
    Permission                    => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Article CreateTime < now()-60 min)',
);

# Test CloseTime
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'CloseTime',
                Value => $CreateTime,
                Operator => 'GTE',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);
$Self->True(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Ticket CloseTime >= now()-60 min)',
);

# Test TicketCloseOlderDate
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'CloseTime',
                Value => $CreateTime,
                Operator => 'LT',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Ticket CreateTime < now()-60 min)',
);

my %Ticket2 = $TicketObject->TicketGet( TicketID => $TicketID );
$Self->Is(
    $Ticket2{Title},
    'Very long title 01234567890123456789012345678901234567890123456789'
        . '0123456789012345678901234567890123456789012345678901234567890123456789'
        . '0123456789012345678901234567890123456789012345678901234567890123456789'
        . '0123456789012345678901234567890123456789',
    'TicketGet() (Title)',
);
$Self->Is(
    $Ticket2{Queue},
    'Junk',
    'TicketGet() (Queue)',
);
$Self->Is(
    $Ticket2{Priority},
    '4 low',
    'TicketGet() (Priority)',
);
$Self->Is(
    $Ticket2{State},
    'open',
    'TicketGet() (State)',
);
$Self->Is(
    $Ticket2{Lock},
    'lock',
    'TicketGet() (Lock)',
);

my @MoveQueueList = $TicketObject->TicketMoveQueueList(
    TicketID => $TicketID,
    Type     => 'Name',
);

$Self->Is(
    $MoveQueueList[0],
    'Junk',
    'MoveQueueList() (Raw)',
);
$Self->Is(
    $MoveQueueList[$#MoveQueueList],
    'Junk',
    'MoveQueueList() (Junk)',
);

my $TicketAccountTime = $TicketObject->TicketAccountTime(
    TicketID  => $TicketID,
    ArticleID => $ArticleID,
    TimeUnit  => '4.5',
    UserID    => 1,
);

$Self->True(
    $TicketAccountTime,
    'TicketAccountTime() 1',
);

my $TicketAccountTime2 = $TicketObject->TicketAccountTime(
    TicketID  => $TicketID,
    ArticleID => $ArticleID,
    TimeUnit  => '4123.53',
    UserID    => 1,
);

$Self->True(
    $TicketAccountTime2,
    'TicketAccountTime() 2',
);

my $TicketAccountTime3 = $TicketObject->TicketAccountTime(
    TicketID  => $TicketID,
    ArticleID => $ArticleID,
    TimeUnit  => '4,53',
    UserID    => 1,
);

$Self->True(
    $TicketAccountTime3,
    'TicketAccountTime() 3',
);

my $AccountedTime = $TicketObject->TicketAccountedTimeGet( TicketID => $TicketID );

$Self->Is(
    $AccountedTime,
    4132,
    'TicketAccountedTimeGet()',
);

my $AccountedTime2 = $TicketObject->ArticleAccountedTimeGet(
    ArticleID => $ArticleID,
);

$Self->Is(
    $AccountedTime2,
    4132.56,
    'ArticleAccountedTimeGet()',
);

my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $TimeObject->SystemTime2Date(
    SystemTime => $TimeObject->SystemTime(),
);

my ( $StopSec, $StopMin, $StopHour, $StopDay, $StopMonth, $StopYear ) = $TimeObject->SystemTime2Date(
    SystemTime => $TimeObject->SystemTime() - 60 * 60 * 24,
);

my %TicketStatus = $TicketObject->HistoryTicketStatusGet(
    StopYear   => $Year,
    StopMonth  => $Month,
    StopDay    => $Day,
    StartYear  => $StopYear,
    StartMonth => $StopMonth,
    StartDay   => $StopDay,
);

if ( $TicketStatus{$TicketID} ) {
    my %TicketHistory = %{ $TicketStatus{$TicketID} };
    $Self->Is(
        $TicketHistory{TicketNumber},
        $Ticket{TicketNumber},
        "HistoryTicketStatusGet() (TicketNumber)",
    );
    $Self->Is(
        $TicketHistory{TicketID},
        $TicketID,
        "HistoryTicketStatusGet() (TicketID)",
    );
    $Self->Is(
        $TicketHistory{CreateUserID},
        1,
        "HistoryTicketStatusGet() (CreateUserID)",
    );
    $Self->Is(
        $TicketHistory{Queue},
        'Junk',
        "HistoryTicketStatusGet() (Queue)",
    );
    $Self->Is(
        $TicketHistory{CreateQueue},
        'Junk',
        "HistoryTicketStatusGet() (CreateQueue)",
    );
    $Self->Is(
        $TicketHistory{State},
        'open',
        "HistoryTicketStatusGet() (State)",
    );
    $Self->Is(
        $TicketHistory{CreateState},
        'closed',
        "HistoryTicketStatusGet() (CreateState)",
    );
    $Self->Is(
        $TicketHistory{Priority},
        '4 low',
        "HistoryTicketStatusGet() (Priority)",
    );
    $Self->Is(
        $TicketHistory{CreatePriority},
        '3 normal',
        "HistoryTicketStatusGet() (CreatePriority)",
    );

}
else {
    $Self->True(
        0,
        'HistoryTicketStatusGet()',
    );
}

my $Delete = $TicketObject->TicketDelete(
    TicketID => $TicketID,
    UserID   => 1,
);
$Self->True(
    $Delete,
    'TicketDelete()',
);

my $DeleteCheck = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
    Silent   => 1,
);

$Self->False(
    $DeleteCheck,
    'TicketDelete() worked',
);

# ticket search sort/order test
my $TicketIDSortOrder1 = $TicketObject->TicketCreate(
    Title        => 'Some Ticket_Title - ticket sort/order by tests',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'new',
    OrganisationID => $Contact{PrimaryOrganisationID},
    ContactID    => $ContactID,
    OwnerID      => 1,
    UserID       => 1,
);

my %TicketCreated = $TicketObject->TicketGet(
    TicketID => $TicketIDSortOrder1,
    UserID   => 1,
);

# wait 5 seconds
$Helper->FixedTimeAddSeconds(2);

my $TicketIDSortOrder2 = $TicketObject->TicketCreate(
    Title        => 'Some Ticket_Title - ticket sort/order by tests2',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'new',
    OrganisationID => $Contact{PrimaryOrganisationID},
    ContactID    => $ContactID,
    OwnerID      => 1,
    UserID       => 1,
);

# wait 5 seconds
$Helper->FixedTimeAddSeconds(2);

my $Success = $TicketObject->TicketStateSet(
    State    => 'open',
    TicketID => $TicketIDSortOrder1,
    UserID   => 1,
);

my %TicketUpdated = $TicketObject->TicketGet(
    TicketID => $TicketIDSortOrder1,
    UserID   => 1,
);

$Self->IsNot(
    $TicketCreated{Changed},
    $TicketUpdated{Changed},
    'TicketUpdated for sort - change time was updated'
        . " $TicketCreated{Changed} ne $TicketUpdated{Changed}",
);

# find newest ticket by priority, age
my $QueueID = $QueueObject->QueueLookup( Queue => 'Junk' );
my @TicketIDsSortOrder = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'ARRAY',
    Search       => {
        AND => [
            {
                Field    => 'Title',
                Value    => 'sort/order by test',
                Operator => 'CONTAINS',
            },
            {
                Field    => 'QueueID',
                Value    => $QueueID,
                Operator => 'EQ',
            },
            {
                Field    => 'OrganisationID',
                Value    => $Contact{PrimaryOrganisationID},
                Operator => 'EQ',
            },
            {
                Field    => 'ContactID',
                Value    => $ContactID,
                Operator => 'EQ',
            }
        ]
    },
    Sort => [
        {
            Field     => "PriorityID",
            Direction => 'descending',
        },
        {
            Field     => "Age",
            Direction => 'ascending',
        }
    ],
    UserID       => 1,
    Limit        => 1,
);

$Self->Is(
    $TicketIDsSortOrder[0],
    $TicketIDSortOrder2,
    'TicketTicketSearch() - ticket sort/order by (PriorityID (Down), Age (Up))',
);

# find oldest ticket by priority, age
@TicketIDsSortOrder = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'ARRAY',
    Search       => {
        AND => [
            {
                Field => 'Title',
                Value => 'sort/order by test',
                Operator => 'CONTAINS',
            },
            {
                Field => 'QueueID',
                Value => $QueueID,
                Operator => 'EQ',
            },
            {
                Field => 'OrganisationID',
                Value => $Contact{PrimaryOrganisationID},
                Operator => 'EQ',
            },
            {
                Field => 'ContactID',
                Value => $ContactID,
                Operator => 'EQ',
            }
        ]
    },
    Sort => [
        {
            Field => "PriorityID",
            Direction => 'descending',
        },
        {
            Field => "Age",
            Direction => 'descending',
        }
    ],
    UserID       => 1,
    Limit        => 1,
);
$Self->Is(
    $TicketIDsSortOrder[0],
    $TicketIDSortOrder1,
    'TicketTicketSearch() - ticket sort/order by (PriorityID (Down), Age (Down))',
);

# find last modified ticket by changed time
@TicketIDsSortOrder = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'ARRAY',
    Search       => {
        AND => [
            {
                Field => 'Title',
                Value => 'sort/order by test',
                Operator => 'CONTAINS',
            },
            {
                Field => 'QueueID',
                Value => $QueueID,
                Operator => 'EQ',
            },
            {
                Field => 'OrganisationID',
                Value => $Contact{PrimaryOrganisationID},
                Operator => 'EQ',
            },
            {
                Field => 'ContactID',
                Value => $ContactID,
                Operator => 'EQ',
            }
        ]
    },
    Sort => [
        {
            Field => "ChangeTime",
            Direction => 'descending',
        },
    ],
    UserID       => 1,
    Limit        => 1,
);
$Self->Is(
    $TicketIDsSortOrder[0],
    $TicketIDSortOrder1,
    'TicketTicketSearch() - ticket sort/order by (ChangeTime (Down))'
        . "$TicketIDsSortOrder[0] instead of $TicketIDSortOrder1",
);

# find oldest modified by changed time
@TicketIDsSortOrder = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'ARRAY',
    Search       => {
        AND => [
            {
                Field => 'Title',
                Value => 'sort/order by test',
                Operator => 'CONTAINS',
            },
            {
                Field => 'QueueID',
                Value => $QueueID,
                Operator => 'EQ',
            },
            {
                Field => 'OrganisationID',
                Value => $Contact{PrimaryOrganisationID},
                Operator => 'EQ',
            },
            {
                Field => 'ContactID',
                Value => $ContactID,
                Operator => 'EQ',
            }
        ]
    },
    Sort => [
        {
            Field => "ChangeTime",
            Direction => 'ascending',
        },
    ],
    UserID       => 1,
    Limit        => 1,
);
$Self->Is(
    $TicketIDsSortOrder[0],
    $TicketIDSortOrder2,
    'TicketTicketSearch() - ticket sort/order by (ChangeTime (Up)))'
        . "$TicketIDsSortOrder[0]  instead of $TicketIDSortOrder2",
);

my $TicketIDSortOrder3 = $TicketObject->TicketCreate(
    Title        => 'Some Ticket_Title - ticket sort/order by tests2',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '4 low',
    State        => 'new',
    OrganisationID => $Contact{PrimaryOrganisationID},
    ContactID    => $ContactID,
    OwnerID      => 1,
    UserID       => 1,
);

# wait 2 seconds
$Helper->FixedTimeAddSeconds(2);

my $TicketIDSortOrder4 = $TicketObject->TicketCreate(
    Title        => 'Some Ticket_Title - ticket sort/order by tests2',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '4 low',
    State        => 'new',
    OrganisationID => $Contact{PrimaryOrganisationID},
    ContactID    => $ContactID,
    OwnerID      => 1,
    UserID       => 1,
);

# find oldest ticket by priority, age
@TicketIDsSortOrder = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'ARRAY',
    Search       => {
        AND => [
            {
                Field    => 'Title',
                Value    => 'sort/order by test',
                Operator => 'CONTAINS',
            },
            {
                Field    => 'QueueID',
                Value    => $QueueID,
                Operator => 'EQ',
            },
            {
                Field    => 'OrganisationID',
                Value    => $Contact{PrimaryOrganisationID},
                Operator => 'EQ',
            },
            {
                Field => 'ContactID',
                Value => $ContactID,
                Operator => 'EQ',
            }
        ]
    },
    Sort => [
        {
            Field     => "PriorityID",
            Direction => 'descending',
        },
        {
            Field     => "Age",
            Direction => 'descending',
        }
    ],
    UserID       => 1,
    Limit        => 1,
);
$Self->Is(
    $TicketIDsSortOrder[0],
    $TicketIDSortOrder1,
    'TicketTicketSearch() - ticket sort/order by (Priority (Down), Age (Down))',
);

# find oldest ticket by priority, age
@TicketIDsSortOrder = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'ARRAY',
    Search       => {
        AND => [
            {
                Field    => 'Title',
                Value    => 'sort/order by test',
                Operator => 'CONTAINS',
            },
            {
                Field    => 'QueueID',
                Value    => $QueueID,
                Operator => 'EQ',
            },
            {
                Field    => 'OrganisationID',
                Value    => $Contact{PrimaryOrganisationID},
                Operator => 'EQ',
            },
            {
                Field    => 'ContactID',
                Value    => $ContactID,
                Operator => 'EQ',
            }
        ]
    },
    Sort => [
        {
            Field     => "PriorityID",
            Direction => 'ascending',
        },
        {
            Field     => "Age",
            Direction => 'descending',
        }
    ],
    UserID       => 1,
    Limit        => 1,
);
$Self->Is(
    $TicketIDsSortOrder[0],
    $TicketIDSortOrder3,
    'TicketTicketSearch() - ticket sort/order by (Priority (Up), Age (Down))',
);

# find newest ticket
@TicketIDsSortOrder = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'ARRAY',
    Search       => {
        AND => [
            {
                Field    => 'Title',
                Value    => 'sort/order by test',
                Operator => 'CONTAINS',
            },
            {
                Field    => 'QueueID',
                Value    => $QueueID,
                Operator => 'EQ',
            },
            {
                Field    => 'OrganisationID',
                Value    => $Contact{PrimaryOrganisationID},
                Operator => 'EQ',
            },
            {
                Field    => 'ContactID',
                Value    => $ContactID,
                Operator => 'EQ',
            }
        ]
    },
    Sort => [
        {
            Field     => "Age",
            Direction => 'descending',
        }
    ],
    UserID       => 1,
    Limit        => 1,
);
$Self->Is(
    $TicketIDsSortOrder[0],
    $TicketIDSortOrder1,
    'TicketTicketSearch() - ticket sort/order by (Age (Down))',
);

# find oldest ticket
@TicketIDsSortOrder = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'ARRAY',
    Search       => {
        AND => [
            {
                Field    => 'Title',
                Value    => 'sort/order by test',
                Operator => 'CONTAINS',
            },
            {
                Field    => 'QueueID',
                Value    => $QueueID,
                Operator => 'EQ',
            },
            {
                Field    => 'OrganisationID',
                Value    => $Contact{PrimaryOrganisationID},
                Operator => 'EQ',
            },
            {
                Field    => 'ContactID',
                Value    => $ContactID,
                Operator => 'EQ',
            }
        ]
    },
    Sort => [
        {
            Field     => "Age",
            Direction => 'ascending',
        }
    ],
    UserID       => 1,
    Limit        => 1,
);
$Self->Is(
    $TicketIDsSortOrder[0],
    $TicketIDSortOrder4,
    'TicketTicketSearch() - ticket sort/order by (Age (Up))',
);

$Count = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'COUNT',
    Search       => {
        AND => [
            {
                Field    => 'Title',
                Value    => 'sort/order by test',
                Operator => 'CONTAINS',
            },
            {
                Field    => 'QueueID',
                Value    => $QueueID,
                Operator => 'EQ',
            },
            {
                Field    => 'OrganisationID',
                Value    => $Contact{PrimaryOrganisationID},
                Operator => 'EQ',
            },
            {
                Field    => 'ContactID',
                Value    => $ContactID,
                Operator => 'EQ',
            }
        ]
    },
    UserID       => 1,
);
$Self->Is(
    $Count,
    4,
    'TicketTicketSearch() - ticket count for created tickets',
);

for my $TicketIDDelete (
    $TicketIDSortOrder1, $TicketIDSortOrder2, $TicketIDSortOrder3,
    $TicketIDSortOrder4
    )
{
    $Self->True(
        $TicketObject->TicketDelete(
            TicketID => $TicketIDDelete,
            UserID   => 1,
        ),
        "TicketDelete()",
    );
}

# avoid StateType and StateTypeID problems in TicketSearch()

my %StateTypeList = $StateObject->StateTypeList(
    UserID => 1,
);

# you need a hash with the state as key and the related StateType and StateTypeID as
# reference
my %StateAsKeyAndStateTypeAsValue;
for my $StateTypeID ( sort keys %StateTypeList ) {
    my @List = $StateObject->StateGetStatesByType(
        StateType => [ $StateTypeList{$StateTypeID} ],
        Result    => 'Name',                             # HASH|ID|Name
    );
    for my $Index (@List) {
        $StateAsKeyAndStateTypeAsValue{$Index}->{Name} = $StateTypeList{$StateTypeID};
        $StateAsKeyAndStateTypeAsValue{$Index}->{ID}   = $StateTypeID;
    }
}

# to be sure that you have a result ticket create one
$TicketID = $TicketObject->TicketCreate(
    Title        => 'StateTypeTest',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'new',
    OrganisationID => $Contact{PrimaryOrganisationID},
    ContactID    => $ContactID,
    OwnerID      => 1,
    UserID       => 1,
);

my %StateList = $StateObject->StateList( UserID => 1 );

# now check every possible state
for my $State ( values %StateList ) {
    $TicketObject->TicketStateSet(
        State              => $State,
        TicketID           => $TicketID,
        SendNoNotification => 1,
        UserID             => 1,
    );

    my @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
        Result       => 'ARRAY',
        Search       => {
            AND => [
                {
                    Field    => 'Title',
                    Value    => 'StateTypeTest',
                    Operator => 'CONTAINS',
                },
                {
                    Field    => 'QueueID',
                    Value    => $QueueID,
                    Operator => 'EQ',
                },
                {
                    Field    => 'StateTypeID',
                    Value    => [ $StateAsKeyAndStateTypeAsValue{$State}->{ID} ],
                    Operator => 'IN',
                }
            ]
        },
        UserID       => 1,
    );

    my @TicketIDsType = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
        Result    => 'ARRAY',
        Search       => {
            AND => [
                {
                    Field    => 'Title',
                    Value    => 'StateTypeTest',
                    Operator => 'CONTAINS',
                },
                {
                    Field    => 'QueueID',
                    Value    => $QueueID,
                    Operator => 'EQ',
                },
                {
                    Field    => 'StateType',
                    Value    => [ $StateAsKeyAndStateTypeAsValue{$State}->{Name} ],
                    Operator => 'IN',
                }
            ]
        },
        UserID    => 1,
    );

    if ( $TicketIDs[0] ) {
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketIDs[0],
            UserID   => 1,
        );
    }

    # if there is no result the StateTypeID hasn't worked
    # Test if there is a result, if I use StateTypeID $StateAsKeyAndStateTypeAsValue{$State}->{ID}
    $Self->True(
        $TicketIDs[0],
        "TicketSearch() - StateTypeID - found ticket",
    );

# if it is not equal then there is in the using of StateType or StateTypeID an error
# check if you get the same result if you use the StateType attribute or the StateTypeIDs attribute.
# State($State) StateType($StateAsKeyAndStateTypeAsValue{$State}->{Name}) and StateTypeIDs($StateAsKeyAndStateTypeAsValue{$State}->{ID})
    $Self->Is(
        scalar @TicketIDs,
        scalar @TicketIDsType,
        "TicketSearch() - StateType",
    );
}

my %TicketPending = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

$Self->Is(
    $TicketPending{UntilTime},
    '0',
    "TicketPendingTimeSet() - Pending Time - not set",
);

my $Diff               = 60;
my $CurrentSystemTime  = $TimeObject->SystemTime();
my $PendingTimeSetDiff = $TicketObject->TicketPendingTimeSet(
    Diff     => $Diff,
    TicketID => $TicketID,
    UserID   => 1,
);

$Self->True(
    $PendingTimeSetDiff,
    "TicketPendingTimeSet() - Pending Time - set diff",
);

%TicketPending = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

$Self->Is(
    $TicketPending{PendingTimeUnix},
    $CurrentSystemTime + $Diff * 60,
    "TicketPendingTimeSet() - diff time check",
);

my $PendingTimeSet = $TicketObject->TicketPendingTimeSet(
    TicketID => $TicketID,
    UserID   => 1,
    Year     => '2003',
    Month    => '08',
    Day      => '14',
    Hour     => '22',
    Minute   => '05',
);

$Self->True(
    $PendingTimeSet,
    "TicketPendingTimeSet() - Pending Time - set",
);

%TicketPending = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

my $PendingUntilTime = $TimeObject->Date2SystemTime(
    Year   => '2003',
    Month  => '08',
    Day    => '14',
    Hour   => '22',
    Minute => '05',
    Second => '00',
);

$PendingUntilTime = $TimeObject->SystemTime() - $PendingUntilTime;

$Self->Is(
    $TicketPending{UntilTime},
    q{-} . $PendingUntilTime,
    "TicketPendingTimeSet() - Pending Time - read back",
);

$PendingTimeSet = $TicketObject->TicketPendingTimeSet(
    TicketID => $TicketID,
    UserID   => 1,
    Year     => '0',
    Month    => '0',
    Day      => '0',
    Hour     => '0',
    Minute   => '0',
);

$Self->True(
    $PendingTimeSet,
    "TicketPendingTimeSet() - Pending Time - reset",
);

%TicketPending = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

$Self->Is(
    $TicketPending{UntilTime},
    '0',
    "TicketPendingTimeSet() - Pending Time - not set",
);

$PendingTimeSet = $TicketObject->TicketPendingTimeSet(
    TicketID => $TicketID,
    UserID   => 1,
    String   => '2003-09-14 22:05:00',
);

$Self->True(
    $PendingTimeSet,
    "TicketPendingTimeSet() - Pending Time - set string",
);

%TicketPending = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

$PendingUntilTime = $TimeObject->TimeStamp2SystemTime(
    String => '2003-09-14 22:05:00',
);

$PendingUntilTime = $TimeObject->SystemTime() - $PendingUntilTime;

$Self->Is(
    $TicketPending{UntilTime},
    q{-} . $PendingUntilTime,
    "TicketPendingTimeSet() - Pending Time - read back",
);

$PendingTimeSet = $TicketObject->TicketPendingTimeSet(
    TicketID => $TicketID,
    UserID   => 1,
    String   => '0000-00-00 00:00:00',
);

$Self->True(
    $PendingTimeSet,
    "TicketPendingTimeSet() - Pending Time - reset string",
);

%TicketPending = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

$Self->Is(
    $TicketPending{UntilTime},
    '0',
    "TicketPendingTimeSet() - Pending Time - not set",
);

$PendingTimeSet = $TicketObject->TicketPendingTimeSet(
    TicketID => $TicketID,
    UserID   => 1,
    String   => '2003-09-14 22:05:00',
);

$Self->True(
    $PendingTimeSet,
    "TicketPendingTimeSet() - Pending Time - set string",
);

my $TicketStateUpdate = $TicketObject->TicketStateSet(
    TicketID => $TicketID,
    UserID   => 1,
    State    => 'pending reminder',
);

%TicketPending = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

$Self->True(
    $TicketPending{UntilTime},
    "TicketPendingTimeSet() - Set to pending - time should still be there",
);

$TicketStateUpdate = $TicketObject->TicketStateSet(
    TicketID => $TicketID,
    UserID   => 1,
    State    => 'new',
);

%TicketPending = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => 1,
);

$Self->Is(
    $TicketPending{UntilTime},
    '0',
    "TicketPendingTimeSet() - Set to new - Pending Time not set",
);

# Test CreateTime (future date)
my $FutureTime = $TimeObject->SystemTime2TimeStamp(
    SystemTime => $TimeObject->SystemTime() + ( 60 * 60 ),
);
%TicketIDs  = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field    => 'CreateTime',
                Value    => $FutureTime,
                Operator => 'GTE',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Ticket CreateTime >= now()+60 min)',
);

# Test ArticleCreateTime (future date)
%TicketIDs  = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field    => 'ArticleCreateTime',
                Value    => $FutureTime,
                Operator => 'GTE',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Article CreateTime >= now()+60 min)',
);

# Test CloseTime (future date)
%TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field    => 'CloseTime',
                Value    => $FutureTime,
                Operator => 'GTE',
            },
        ]
    },
    UserID     => 1,
    UserType   => 'Agent',
    Permission => 'rw',
);
$Self->False(
    $TicketIDs{$TicketID},
    'TicketSearch() (HASH:Ticket CloseTime >= now()+60 min)',
);

# the ticket is no longer needed
$TicketObject->TicketDelete(
    TicketID => $TicketID,
    UserID   => 1,
);

# tests for searching StateTypes that might not have states
# this should return an empty list rather then a big SQL error
# the problem is, we can't really test if there is an SQL error or not
# ticket search returns an empty list anyway

my @NewStates = $StateObject->StateGetStatesByType(
    StateType => ['new'],
    Result    => 'ID',
);

# make sure we don't have valid states for state type new
for my $NewStateID (@NewStates) {
    my %State = $StateObject->StateGet(
        ID => $NewStateID,
    );
    $StateObject->StateUpdate(
        %State,
        ValidID => 2,
        UserID  => 1,
    );
}

my @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result       => 'LIST',
    Limit        => 100,
    Search       => {
        AND => [
            {
                Field    => 'TicketNumber',
                Value    => [ $Ticket{TicketNumber}, 'ABC' ],
                Operator => 'IN',
            },
            {
                Field    => 'StateType',
                Value    => 'New',
                Operator => 'EQ',
            },
        ]
    },
    UserID       => 1,
    Permission   => 'rw',
);
$Self->False(
    $TicketIDs[0],
    'TicketSearch() (LIST:TicketNumber,StateType:new (no valid states of state type new)',
);

# activate states again
for my $NewStateID (@NewStates) {
    my %State = $StateObject->StateGet(
        ID => $NewStateID,
    );
    $StateObject->StateUpdate(
        %State,
        ValidID => 1,
        UserID  => 1,
    );
}

# check response of ticket search for invalid timestamps
for my $SearchParam (qw(ArticleCreateTime CreateTime PendingTime)) {
    for my $ParamOption (qw(LT GTE)) {
        $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
            Search       => {
                AND => [
                    {
                        Field    => $SearchParam,
                        Value    => '2000-02-31 00:00:00',
                        Operator => $ParamOption,
                    },
                ]
            },
            UserID                      => 1,
        );
        my $ErrorMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        $Self->Is(
            $ErrorMessage,
            "Attribute module for $SearchParam returned an error!",
            "TicketSearch() (Handling invalid timestamp in '$SearchParam $ParamOption')",
        );
    }
}

# cleanup the filesystem
my @DeleteTicketList = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    Result            => 'ARRAY',
    Search       => {
        AND => [
            {
                Field    => 'ContactID',
                Value    => $ContactID,
                Operator => 'EQ',
            },
        ]
    },
    UserID            => 1,
);
for my $TicketID (@DeleteTicketList) {
    $TicketObject->TicketDelete(
        TicketID => $TicketID,
        UserID   => 1,
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
