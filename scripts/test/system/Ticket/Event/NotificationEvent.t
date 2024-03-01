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

use Kernel::System::Role::Permission;
use Kernel::System::VariableCheck qw(:all);

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# disable rich text editor
my $Success = $Helper->ConfigSettingChange(
    Key   => 'Frontend::RichText',
    Value => 0,
);
$Self->True(
    $Success,
    "Disable RichText with true",
);

# use Test email backend
$Success = $Helper->ConfigSettingChange(
    Key   => 'SendmailModule',
    Value => 'Kernel::System::Email::Test',
);
$Self->True(
    $Success,
    "Set Email Test backend with true",
);

# set default language to English
$Success = $Helper->ConfigSettingChange(
    Key   => 'DefaultLanguage',
    Value => 'en',
);
$Self->True(
    $Success,
    "Set default language to English",
);

# set not self notify
$Success = $Helper->ConfigSettingChange(
    Key   => 'AgentSelfNotifyOnAction',
    Value => 0,
);
$Self->True(
    $Success,
    "Disable Agent Self Notify On Action",
);

# disable async notifications
$Success = $Helper->ConfigSettingChange(
    Key   => 'TicketNotification::SendAsynchronously',
    Value => 0,
);

$Self->True(
    $Success,
    "Deactivate asynchronous notifications",
);

my $TestEmailObject = $Kernel::OM->Get('Email::Test');

$Success = $TestEmailObject->CleanUp();
$Self->True(
    $Success,
    'Initial cleanup',
);

$Self->IsDeeply(
    $TestEmailObject->EmailsGet(),
    [],
    'Test backend empty after initial cleanup',
);

# enable responsible
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::Responsible',
    Value => 1,
);

# disable asynchron notification
$Kernel::OM->Get('Config')->Set(
    Key   => 'TicketNotification::SendAsynchronously',
    Value => 0,
);

# get a random id
my $RandomID = $Helper->GetRandomID();

# create role without permissions
my $RoleID = $Kernel::OM->Get('UnitTest::Helper')->TestRoleCreate(
    Name        => "example-role$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
            }
        ],
        'Base::Ticket' => [
            {
                Target => 1,
                Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
            }
        ]
    }
);

# create role with DENY on tickets
my $TicketDenyRoleID = $Helper->TestRoleCreate(
    Name        => "ticket_deny_$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission::PERMISSION->{DENY},
            }
        ],
        'Base::Ticket' => [
            {
                Target => 1,
                Value  => Kernel::System::Role::Permission::PERMISSION->{DENY},
            }
        ]
    }
);

# create role with READ on tickets
my $TicketReadRoleID = $Helper->TestRoleCreate(
    Name        => "ticket_read_$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
            }
        ],
        'Base::Ticket' => [
            {
                Target => 1,
                Value  => Kernel::System::Role::Permission::PERMISSION->{READ},
            }
        ]
    }
);

# create role with WRITE on tickets
my $TicketWriteRoleID = $Helper->TestRoleCreate(
    Name        => "ticket_write_$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission::PERMISSION->{UPDATE},
            }
        ],
        'Base::Ticket' => [
            {
                Target => 1,
                Value  => Kernel::System::Role::Permission::PERMISSION->{WRITE} + Kernel::System::Role::Permission::PERMISSION->{READ},
            }
        ]
    }
);

# create a new user for current test
my $UserLogin = $Helper->TestUserCreate(
    Roles => ["example-role$RandomID", "ticket_read_$RandomID", "ticket_write_$RandomID"],
);

my %UserData = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin,
);

my $UserID = $UserData{UserID};

my %UserContactData = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $UserID,
);

# create a new user without permissions
my $UserLogin2 = $Helper->TestUserCreate(
    Roles => ["ticket_deny_$RandomID"],
);

my %UserData2 = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin2,
);

my %UserContactData2 = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $UserData2{UserID},
);

# create a new user with read permissions but invalid
my $UserLogin3 = $Helper->TestUserCreate(
    Roles => ["ticket_read_$RandomID"],
);

my %UserData3 = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin3,
);

my %UserContactData3 = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $UserData3{UserID},
);

# set User3 invalid
my $SetInvalid = $Kernel::OM->Get('User')->UserUpdate(
    %UserData3,
    ValidID      => 2,
    ChangeUserID => 1,
);

# create a new user with role without explicit permissions
my $UserLogin4 = $Helper->TestUserCreate(
    Roles => ["example-role$RandomID", "ticket_read_$RandomID"]
);

my %UserContactData4 = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin4,
);

%UserContactData4 = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $UserContactData4{UserID},
);

# create a new contact for current test
my $ContactID = $Helper->TestContactCreate();

my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID
);

#create a new organisation for current test
my $OrgID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Name    => 'Dummy Orga',
    Number  => 'DUMMY',
    ValidID => 1,
    UserID  => 1,
);

# get queue data
my %Queue = $Kernel::OM->Get('Queue')->QueueGet(
    ID => 1,
);

# create ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Ticket One Title',
    QueueID        => 1,
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'new',
    OrganisationID => $OrgID,
    ContactID      => $ContactID,
    OwnerID        => $UserID,
    ResponsibleID  => $UserID,
    UserID         => $UserID,
);

# sanity check
$Self->True(
    $TicketID,
    "TicketCreate() successful for Ticket ID $TicketID",
);

my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID => $TicketID
);

# create article
my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID      => $TicketID,
    Channel       => 'note',
    SenderType    => 'external',
    Charset       => 'utf-8',
    ContentType   => 'text/plain',
    CustomerVisible => 1,
    From          => 'test@example.com',
    To            => 'test123@example.com',
    Subject       => 'article subject test',
    Body          => 'article body test',
    HistoryType   => 'NewTicket',
    HistoryComment => q{%%},
    UserID        => $UserID,
);

# sanity check
$Self->True(
    $ArticleID,
    "ArticleCreate() successful for Article ID $ArticleID",
);

# create article with html body
my $HTMLArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    Channel         => 'note',
    SenderType      => 'external',
    Charset         => 'utf-8',
    ContentType     => 'text/html',
    CustomerVisible => 1,
    From            => 'test@example.com',
    To              => 'test123@example.com',
    Subject         => 'article subject test',
    Body            => <<'END',
<p>...text here...</p>
<p>this is a URL: <a href="https://kixdesk.com">KIXDesk</a></p>
<p>...and here...</p>
END
    HistoryType     => 'NewTicket',
    HistoryComment  => q{%%},
    UserID          => $UserID,
);

# sanity check
$Self->True(
    $HTMLArticleID,
    "ArticleCreate() successful for Article ID $HTMLArticleID with html body",
);

# Create test ticket dynamic field of type text.
my $FieldID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    Name       => "DFT1$RandomID",
    Label      => 'Description',
    FieldOrder => 9991,
    FieldType  => 'Text',
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue => 1,
    },
    ValidID => 1,
    UserID  => 1,
    Reorder => 0,
);
$Self->True(
    $Success,
    "DynamicFieldAdd - Added Text field ($FieldID)",
);

# Set ticket dynamic field text value to unchecked.
$Success = $Kernel::OM->Get('DynamicFieldValue')->ValueSet(
    FieldID  => $FieldID,
    ObjectID => $TicketID,
    Value    => [
        {
            ValueText => 0,
        },
    ],
    UserID => 1,
);
$Self->True(
    $Success,
    'ValueSet - Text value set to 0',
);

my $SuccessWatcher = $Kernel::OM->Get('Watcher')->WatcherAdd(
    Object      => 'Ticket',
    ObjectID    => $TicketID,
    WatchUserID => $UserID,
    UserID      => $UserID,
);

# sanity check
$Self->True(
    $SuccessWatcher,
    "WatcherAdd() successful for Ticket ID $TicketID",
);

# Make sure that ticket events are handled
$Kernel::OM->ObjectsDiscard(
    Objects => [ 'Ticket' ],
);

$Success = $TestEmailObject->CleanUp();
$Self->True(
    $Success,
    'Initial cleanup',
);
$Self->IsDeeply(
    $TestEmailObject->EmailsGet(),
    [],
    'Test backend empty after initial cleanup',
);

my @Tests = (
    {
        Name => 'Missing Event',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Data => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [],
        Success         => 0,
        Silent          => 1,
    },
    {
        Name => 'Missing Data',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event  => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [],
        Success         => 0,
        Silent          => 1,
    },
    {
        Name => 'Missing Config',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Data  => {
                TicketID => $TicketID,
            },
            UserID => 1,
        },
        ExpectedResults => [],
        Success         => 0,
        Silent          => 1,
    },
    {
        Name => 'Missing UserID',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
        },
        ExpectedResults => [],
        Success         => 0,
        Silent          => 1,
    },
    {
        Name => 'RecipientAgent PostMasterUserID',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults     => [],
        SetPostMasterUserID => $UserID,
        Success             => 1,
    },
    {
        Name => 'RecipientAgent Event Trigger',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => $UserData{UserID},
        },
        ExpectedResults => [],
        Success         => 1,
    },
    {
        Name => 'RecipientAgent OutOfOffice (in the past)',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        SetOutOfOfficeDiffStart => -3 * 60 * 60 * 24,
        SetOutOfOfficeDiffEnd   => -1 * 60 * 60 * 24,
        Success                 => 1,
    },
    {
        Name => 'RecipientAgent OutOfOffice (currently)',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults         => [],
        SetOutOfOfficeDiffStart => -1 * 60 * 60 * 24,
        SetOutOfOfficeDiffEnd   => 1 * 60 * 60 * 24,
        Success                 => 1,
    },
    {
        Name => 'RecipientAgent OutOfOffice (in the future)',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        SetOutOfOfficeDiffStart => 1 * 60 * 60 * 24,
        SetOutOfOfficeDiffEnd   => 3 * 60 * 60 * 24,
        Success                 => 1,
    },
    {
        Name => 'RecipientAgent Customizable / No preference',
        Data => {
            Events                => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents       => [$UserID],
            VisibleForAgent       => [1],
            Transports            => ['Email'],
            AgentEnabledByDefault => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'RecipientAgent Customizable / Enabled preference',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            VisibleForAgent => [1],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        SetUserNotificationPreference => {
            Value => 1,
        },
        Success => 1,
    },
    {
        Name => 'RecipientAgent Customizable / Disabled preference',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            VisibleForAgent => [1],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults               => [],
        SetUserNotificationPreference => {
            Value => 0,
        },
        Success => 1,
    },
    {
        Name => 'RecipientAgent OncePerDay',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            OncePerDay      => [1],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults  => [],
        SetTicketHistory => 1,
        Success          => 1,
    },
    {
        Name => 'RecipientAgent Without Permissions',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [ $UserData2{UserID} ],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [],
        Success         => 1,
    },
    {
        Name => 'Recipients Owner',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['AgentOwner'],
            Transports => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'Recipients Responsible',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['AgentResponsible'],
            Transports => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'Recipients Watcher',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['AgentWatcher'],
            Transports => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'Recipients Read Permissions',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['AgentReadPermissions'],
            Transports => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
            {
                ToArray => [ $UserContactData4{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'Recipients Write Permissions',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['AgentWritePermissions'],
            Transports => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'RecipientAgent invalid',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [ $UserID, $UserData3{UserID} ],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'Single RecipientAgent',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'RecipientAgent + RecipientEmail',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            RecipientEmail  => ['test@kixexample.com'],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
            {
                ToArray => ['test@kixexample.com'],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'RecipientAgent SkipRecipients',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID       => $TicketID,
                SkipRecipients => [$UserID],
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [],
        Success         => 1,
    },
    {
        Name => 'RecipientRoles',
        Data => {
            Events         => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientRoles => [$RoleID],
            Transports     => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
            {
                ToArray => [ $UserContactData4{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'RecipientAgents + RecipientRoles',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            RecipientRoles  => [$RoleID],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
            {
                ToArray => [ $UserContactData4{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'RecipientCustomer + Channel email',
        Data => {
            Events             => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients         => ['Customer'],
            Channel            => ['email'],
            VisibleForCustomer => [1],
            Transports         => ['Email'],
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
                ToArray => [$Contact{Email}],
            },
        ],
        Success => 1,
    },
    {
        Name => 'RecipientEmail filter by unchecked dynamic field',
        Data => {
            Events         => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientEmail => ['test@kixexample.com'],
            Transports     => ['Email'],
        },
        Filter => {
            AND => [
                # Filter by text dynamic field value. Note that the search value (-1) is
                #   different than the match value (0). See bug#12257 for more information.
                { Field => 'DynamicField_DFT1' . $RandomID, Operator => 'EQ', Value => 0 }
            ]
        },
        Config => {
            Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => ['test@kixexample.com'],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'article subject match',
        Data => {
            Events         => [ 'ArticleCreate' ],
            RecipientEmail => ['test@kixexample.com'],
            Transports     => ['Email'],
        },
        Filter => {
            AND => [
                { Field => 'Subject', Operator => 'CONTAINS', Value => 'subject te' }
            ]
        },
        Config => {
            Event => 'ArticleCreate',
            Data  => {
                ArticleID => $ArticleID,
                TicketID  => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ 'test@kixexample.com' ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'article ChannelID match',
        Data => {
            Events         => [ 'ArticleCreate' ],
            RecipientEmail => ['test@kixexample.com'],
            Transports     => ['Email'],
        },
        Filter => {
            AND => [
                { Field => 'ChannelID', Operator => 'EQ', Value => 1 }
            ]
        },
        Config => {
            Event => 'ArticleCreate',
            Data  => {
                ArticleID => $ArticleID,
                TicketID  => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ 'test@kixexample.com' ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'create article - agent notification',
        Data => {
            Events          => [ 'ArticleCreate' ],
            RecipientAgents => [$UserID],
            CreateArticle   => [1],
            Transports      => ['Email'],
        },
        Filter => {
            AND => [
                { Field => 'ChannelID', Operator => 'EQ', Value => 1 }
            ]
        },
        Config => {
            Event => 'ArticleCreate',
            Data  => {
                TicketID => $TicketID,
                ArticleID => $ArticleID
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
                ToArray => [ $UserContactData{Email} ],
            },
        ],
        Success => 1,
    },
    {
        Name => 'create article - customer notification',
        Data => {
            Events        => [ 'ArticleCreate' ],
            Recipients    => ['Customer'],
            CreateArticle => [1],
            Transports    => ['Email'],
        },
        Filter => {
            AND => [
                { Field => 'ChannelID', Operator => 'EQ', Value => 1 }
            ]
        },
        Config => {
            Event => 'ArticleCreate',
            Data  => {
                TicketID => $TicketID,
                ArticleID => $ArticleID
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
                ToArray => [$Contact{Email}],
            },
        ],
        Success => 1,
    },
    {
        Name => 'create article - agent notification (visible for customer)',
        Data => {
            Events          => [ 'ArticleCreate' ],
            RecipientAgents => [$UserID],
            CreateArticle   => [1],
            Transports      => ['Email'],
        },
        Filter => {
            AND => [
                { Field => 'ChannelID', Operator => 'EQ', Value => 1 },
                { Field => 'CustomerVisible', Operator => 'EQ', Value => 1 },
            ]
        },
        Config => {
            Event => 'ArticleCreate',
            Data  => {
                TicketID => $TicketID,
                ArticleID => $ArticleID
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
                ToArray => [ $UserContactData{Email} ],
            },
        ],
        Success => 1,
    },
    {
        Name => 'create article - customer notification (visible for customer)',
        Data => {
            Events        => [ 'ArticleCreate' ],
            Recipients    => ['Customer'],
            CreateArticle => [1],
            Transports    => ['Email'],
        },
        Filter => {
            AND => [
                { Field => 'ChannelID', Operator => 'EQ', Value => 1 },
                { Field => 'CustomerVisible', Operator => 'EQ', Value => 1 },
            ]
        },
        Config => {
            Event => 'ArticleCreate',
            Data  => {
                TicketID => $TicketID,
                ArticleID => $ArticleID
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
                ToArray => [$Contact{Email}],
            },
        ],
        Success => 1,
    },
    {
        Name => 'HTML email',
        ContentType => 'text/html',
        Data => {
            Events          => [ 'TicketPriorityUpdate' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        Config => {
            Event => 'TicketPriorityUpdate',
            Data  => {
                TicketID => $TicketID,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
            },
        ],
        Success => 1,
    },
    {
        Name => 'create article - plain notification with HTML article body',
        Data => {
            Events        => [ 'ArticleCreate' ],
            Recipients    => ['Customer'],
            CreateArticle => [1],
            Transports    => ['Email'],
        },
        Filter => {
            AND => [
                { Field => 'ChannelID', Operator => 'EQ', Value => 1 },
                { Field => 'CustomerVisible', Operator => 'EQ', Value => 1 },
            ]
        },
        Config => {
            Event => 'ArticleCreate',
            Data  => {
                TicketID  => $TicketID,
                ArticleID => $HTMLArticleID
            },
            Config => {},
            UserID => 1,
        },
        Message => {
            en => {
                Subject     => 'Subject = article subject',
                Body        => "someone wrote:
<KIX_ARTICLE_Body>",
                ContentType => 'text/plain',
            },
            de => {
                Subject     => 'Subject = article subject',
                Body        => "someone wrote:
<KIX_ARTICLE_Body>",
                ContentType => 'text/plain',
            },
        },
        ExpectedResults => [
            {
                Body    => "someone wrote:

...text here...

this is a URL: [1]KIXDesk

...and here...

=20

[1] https://kixdesk.com
",
                ToArray => [$Contact{Email}],
            },
        ],
        Success => 1,
    },
);

my $SetPostMasterUserID = sub {
    my %Param = @_;

    my $IsSuccess = $Helper->ConfigSettingChange(
        Key   => 'PostmasterUserID',
        Value => $Param{UserID},
    );

    $Self->True(
        $IsSuccess,
        "PostmasterUserID set to $Param{UserID}",
    );
};

my $SetOutOfOffice = sub {
    my %Param = @_;

    if ( $Param{OutOfOffice} ) {

        my ( $StartSec, $StartMin, $StartHour, $StartDay, $StartMonth, $StartYear, $StartWeekDay ) = $Kernel::OM->Get('Time')->SystemTime2Date(
            SystemTime => $Kernel::OM->Get('Time')->SystemTime() + $Param{SetOutOfOfficeDiffStart},
        );
        my ( $EndSec, $EndMin, $EndHour, $EndDay, $EndMonth, $EndYear, $EndWeekDay ) = $Kernel::OM->Get('Time')->SystemTime2Date(
            SystemTime => $Kernel::OM->Get('Time')->SystemTime() + $Param{SetOutOfOfficeDiffEnd},
        );

        my %Preferences = (
            OutOfOfficeStart => sprintf( '%04d-%02d-%02d', $StartYear, $StartMonth, $StartDay ),
            OutOfOfficeEnd   => sprintf( '%04d-%02d-%02d', $EndYear, $EndMonth, $EndDay ),
        );

        for my $Key ( qw( OutOfOfficeStart OutOfOfficeEnd ) ) {
            # pref update db
            my $PreferenceSet = $Kernel::OM->Get('User')->SetPreferences(
                UserID => $Param{UserID},
                Key    => $Key,
                Value  => $Preferences{ $Key },
            );
            $Self->True(
                $PreferenceSet,
                "User preference $Key set to $Preferences{ $Key }",
            );

            if ( !$PreferenceSet ) {
                return;
            }
        }
    }
    else {
        for my $Key ( qw( OutOfOfficeStart OutOfOfficeEnd ) ) {
            # pref update db
            my $IsSuccess = $Kernel::OM->Get('User')->DeletePreferences(
                UserID => $Param{UserID},
                Key    => $Key,
            );
            $Self->True(
                $IsSuccess,
                "User preference $Key deleted",
            );
        }
    }

    return 1;

};

my $SetTicketHistory = sub {
    my %Param = @_;

    my $IsSuccess = $Kernel::OM->Get('Ticket')->HistoryAdd(
        TicketID     => $TicketID,
        HistoryType  => 'SendAgentNotification',
        Name         => "\%\%$Param{NotificationName}\%\%$Param{UserLogin}\%\%Email",
        CreateUserID => $Param{UserID},
    );

    $Self->True(
        $IsSuccess,
        "Ticket HistoryAdd() for User $Param{UserID}",
    );
};

my $SetUserNotificationPreference = sub {
    my %Param = @_;

    my $Value = $Kernel::OM->Get('JSON')->Encode(
        Data => {
            "Notification-$Param{NotificationID}-Email" => $Param{Value},
        },
    );

    my $IsSuccess = $Kernel::OM->Get('User')->SetPreferences(
        Key    => 'NotificationTransport',
        Value  => $Value,
        UserID => $Param{UserID},
    );

    $Self->True(
        $IsSuccess,
        "Updated notification $Param{NotificationID} preference with value $Param{Value} for User $Param{UserID}",
    );
};

my $PostmasterUserID = $Kernel::OM->Get('Config')->Get('PostmasterUserID') || 1;

my $Count = 0;
my $NotificationID;
TEST:
for my $Test (@Tests) {

    # save article count of ticket for later use
    my @ArticleBoxInitial = $Kernel::OM->Get('Ticket')->ArticleContentIndex(
        TicketID => $TicketID,
        UserID   => 1,
    );

    if ( $Test->{ContentType} && $Test->{ContentType} eq 'text/html' ) {
        # enable RichText
        $Kernel::OM->Get('TemplateGenerator')->{RichText} = 1;
        my $IsSuccess = $Kernel::OM->Get('Config')->Set(
            Key   => 'Frontend::RichText',
            Value => 1,
        );
    }
    elsif ( $Kernel::OM->Get('Config')->Get('Frontend::RichText' )) {
        # disable RichText
        $Kernel::OM->Get('TemplateGenerator')->{RichText} = 0;
        my $IsSuccess = $Kernel::OM->Get('Config')->Set(
            Key   => 'Frontend::RichText',
            Value => 0,
        );
    }

    my $Message = $Test->{Message};

    if ( !$Test->{Message} && (!$Test->{ContentType} || $Test->{ContentType} ne 'text/html') ) {
        $Message = {
            en => {
                Subject     => 'JobName',
                Body        => 'JobName <KIX_TICKET_TicketID> <KIX_CONFIG_SendmailModule> <KIX_OWNER_Firstname>',
                ContentType => 'text/plain',
            },
            de => {
                Subject     => 'JobName',
                Body        => 'JobName <KIX_TICKET_TicketID> <KIX_CONFIG_SendmailModule> <KIX_OWNER_Firstname>',
                ContentType => 'text/plain',
            }
        }
    } 
    elsif ( !$Test->{Message} ) {
        $Message = {
            en => {
                Subject     => 'JobName',
                Body        => 'JobName &lt;KIX_TICKET_TicketID&gt; &lt;KIX_CONFIG_SendmailModule&gt; &lt;KIX_OWNER_Firstname&gt;',
                ContentType => 'text/html',
            },
            de => {
                Subject     => 'JobName',
                Body        => 'JobName &lt;KIX_TICKET_TicketID&gt; &lt;KIX_CONFIG_SendmailModule&gt; &lt;KIX_OWNER_Firstname&gt;',
                ContentType => 'text/html',
            },
        }
    }

    $NotificationID = $Kernel::OM->Get('NotificationEvent')->NotificationAdd(
        Name    => "JobName$Count-$RandomID",
        Comment => 'An optional comment',
        Data    => $Test->{Data},
        Filter  => $Test->{Filter},
        Message => $Message,
        ValidID => 1,
        UserID  => 1,
        Silent  => $Test->{Silent},
    );

    # sanity check
    $Self->IsNot(
        $NotificationID,
        undef,
        "$Test->{Name} - NotificationAdd() should not be undef",
    );

    if ( $Test->{SetPostMasterUserID} ) {
        $SetPostMasterUserID->(
            UserID => $Test->{SetPostMasterUserID},
        );
    }

    if ( $Test->{SetTicketHistory} ) {
        $SetTicketHistory->(
            UserID           => $UserID,
            UserLogin        => $UserLogin,
            NotificationName => "JobName$Count-$RandomID",
        );
    }

    if ( $Test->{SetUserNotificationPreference} ) {
        $SetUserNotificationPreference->(
            UserID         => $UserID,
            NotificationID => $NotificationID,
            %{ $Test->{SetUserNotificationPreference} },
        );
    }

    if (
        defined( $Test->{SetOutOfOfficeDiffStart} )
        && defined( $Test->{SetOutOfOfficeDiffEnd} )
    ) {
        my $SuccessOOO = $SetOutOfOffice->(
            SetOutOfOfficeDiffStart => $Test->{SetOutOfOfficeDiffStart},
            SetOutOfOfficeDiffEnd   => $Test->{SetOutOfOfficeDiffEnd},
            UserID                  => $UserID,
            OutOfOffice             => 1,
        );

        # set out of office should always be true
        next TEST if !$SuccessOOO;
    }

    # Make sure that the NotificationEvent-Handler gets recreated for each loop.
    $Kernel::OM->ObjectsDiscard(
        Objects => [ 'Kernel::System::Ticket::Event::NotificationEvent' ],
    );

    my $Result = $Kernel::OM->Get('Kernel::System::Ticket::Event::NotificationEvent')->Run(
        %{ $Test->{Config} },
        Silent => $Test->{Silent}
    );

    if ( !$Test->{Success} ) {
        $Self->False(
            $Result,
            "$Test->{Name} - NotificationEvent Run() with false",
        );

        # notification will be deleted in "continue" statement
        next TEST;
    }

    $Self->True(
        $Result,
        "$Test->{Name} - NotificationEvent Run() with true",
    );

    my $Emails = $TestEmailObject->EmailsGet();

    # remove not needed data
    for my $Email ( @{$Emails} ) {
        for my $Attribute (qw(From Header)) {
            delete $Email->{$Attribute};
        }

        # de-reference body
        $Email->{Body} = ${ $Email->{Body} };

        if ( $Test->{ContentType} && $Test->{ContentType} eq 'text/html' ) {
            # at the moment we are not able to check the HTML body
            delete $Email->{Body};
        }
    }

    my @EmailSorted           = sort { $a->{ToArray}->[0] cmp $b->{ToArray}->[0] } @{$Emails};
    my @ExpectedResultsSorted = sort { $a->{ToArray}->[0] cmp $b->{ToArray}->[0] } @{ $Test->{ExpectedResults} };

    $Self->IsDeeply(
        \@EmailSorted,
        \@ExpectedResultsSorted,
        "$Test->{Name} - Recipients",
    );

    # check if there is a new article if one has to be created
    if ( IsArrayRefWithData($Test->{Data}->{CreateArticle}) && $Test->{Data}->{CreateArticle}->[0] ) {
        my @ArticleBox = $Kernel::OM->Get('Ticket')->ArticleContentIndex(
            TicketID => $TicketID,
            UserID   => 1,
        );
        $Self->Is(
            scalar @ArticleBox,
            (scalar @ArticleBoxInitial) + 1,
            "$Test->{Name} - article created",
        );

        # check if the new article is customer visible
        if ( IsArrayRefWithData($Test->{Data}->{VisibleForCustomer}) && $Test->{Data}->{VisibleForCustomer}->[0] ) {
            $Self->True(
                ($ArticleBox[-1]->{CustomerVisible} == 1),
                "$Test->{Name} - article is visible for the customer",
            );
        }
        else {
            $Self->True(
                ($ArticleBox[-1]->{CustomerVisible} == 0),
                "$Test->{Name} - article is not visible for the customer",
            );
        }
    }
}
continue {

    # delete notification event
    my $NotificationDelete = $Kernel::OM->Get('NotificationEvent')->NotificationDelete(
        ID     => $NotificationID,
        UserID => 1,
    );

    # sanity check
    $Self->True(
        $NotificationDelete,
        "$Test->{Name} - NotificationDelete() successful for Notification ID $NotificationID",
    );

    $TestEmailObject->CleanUp();

    # reset PostMasterUserID to the original value
    if ( $Test->{SetPostMasterUserID} ) {
        $SetPostMasterUserID->(
            UserID => $PostmasterUserID,
        );
    }

    # reset OutOfOffice status
    if (
        defined( $Test->{SetOutOfOfficeDiffStart} )
        && defined( $Test->{SetOutOfOfficeDiffEnd} )
    ) {
        $SetOutOfOffice->(
            UserID      => $UserID,
            OutOfOffice => 0,
        );
    }

    $Count++;
    undef $NotificationID;
}

# delete the ticket to cleanup file system
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
