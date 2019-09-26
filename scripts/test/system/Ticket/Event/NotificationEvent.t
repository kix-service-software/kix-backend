# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
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

# get config object
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# disable rich text editor
my $Success = $ConfigObject->Set(
    Key   => 'Frontend::RichText',
    Value => 0,
);

$Self->True(
    $Success,
    "Disable RichText with true",
);

# use Test email backend
$Success = $ConfigObject->Set(
    Key   => 'SendmailModule',
    Value => 'Kernel::System::Email::Test',
);

$Self->True(
    $Success,
    "Set Email Test backend with true",
);

# set default language to English
$Success = $ConfigObject->Set(
    Key   => 'DefaultLanguage',
    Value => 'en',
);

$Self->True(
    $Success,
    "Set default language to English",
);

# set not self notify
$Success = $ConfigObject->Set(
    Key   => 'AgentSelfNotifyOnAction',
    Value => 0,
);

$Self->True(
    $Success,
    "Disable Agent Self Notify On Action",
);

my $TestEmailObject = $Kernel::OM->Get('Kernel::System::Email::Test');

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
$ConfigObject->Set(
    Key   => 'Ticket::Responsible',
    Value => 1,
);

# get a random id
my $RandomID = $Helper->GetRandomID();

# create role without permissions
my $RoleID = $Kernel::OM->Get('Kernel::System::UnitTest::Helper')->TestRoleCreate(
    Name        => "example-role$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission->PERMISSION->{READ},
            }
        ]
    }
);

# create role with DENY on tickets
my $TicketDenyRoleID = $Kernel::OM->Get('Kernel::System::UnitTest::Helper')->TestRoleCreate(
    Name        => "ticket_deny_$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission->PERMISSION->{DENY},
            }
        ]
    }
);

# create role with READ on tickets
my $TicketReadRoleID = $Kernel::OM->Get('Kernel::System::UnitTest::Helper')->TestRoleCreate(
    Name        => "ticket_read_$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission->PERMISSION->{READ},
            }
        ]
    }
);

# create role with WRITE on tickets
my $TicketWriteRoleID = $Kernel::OM->Get('Kernel::System::UnitTest::Helper')->TestRoleCreate(
    Name        => "ticket_write_$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission->PERMISSION->{UPDATE},
            }
        ]
    }
);

# get objects
my $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');
my $UserObject = $Kernel::OM->Get('Kernel::System::User');

# create a new user for current test
my $UserLogin = $Helper->TestUserCreate(
    Roles => ["example-role$RandomID", "ticket_read_$RandomID", "ticket_write_$RandomID"],
);

my %UserData = $UserObject->GetUserData(
    User => $UserLogin,
);

my $UserID = $UserData{UserID};

# create a new user without permissions
my $UserLogin2 = $Helper->TestUserCreate(
    Roles => ["ticket_deny_$RandomID"],
);

my %UserData2 = $UserObject->GetUserData(
    User => $UserLogin2,
);

# create a new user with read permissions but invalid
my $UserLogin3 = $Helper->TestUserCreate(
    Roles => ["ticket_read_$RandomID"],
);

my %UserData3 = $UserObject->GetUserData(
    User => $UserLogin3,
);

# set User3 invalid
my $SetInvalid = $UserObject->UserUpdate(
    %UserData3,
    ValidID      => 2,
    ChangeUserID => 1,
);

# create a new user with role without explicit permissions
my $UserLogin4 = $Helper->TestUserCreate(
    Roles => ["example-role$RandomID", "ticket_read_$RandomID"]
);

my %UserData4 = $UserObject->GetUserData(
    User => $UserLogin4,
);

# create a new contact for current test
my $ContactID = $Helper->TestContactCreate();

my %Contact = $ContactObject->ContactGet(
    ID => $ContactID
);

# get queue object
my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');

# get queue data
my %Queue = $QueueObject->QueueGet(
    ID => 1,
);

# get ticket object
my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

# create ticket
my $TicketID = $TicketObject->TicketCreate(
    Title         => 'Ticket One Title',
    QueueID       => 1,
    Lock          => 'unlock',
    Priority      => '3 normal',
    State         => 'new',
    OrganisationID => 'example.com',
    ContactID     => $ContactID,
    OwnerID       => $UserID,
    ResponsibleID => $UserID,
    UserID        => $UserID,
);

# sanity check
$Self->True(
    $TicketID,
    "TicketCreate() successful for Ticket ID $TicketID",
);

# create article
my $ArticleID = $TicketObject->ArticleCreate(
    TicketID      => $TicketID,
    Channel       => 'note',
    SenderType    => 'external',
    Charset       => 'utf-8',
    ContentType   => 'text/plain',
    From          => 'test@example.com',
    To            => 'test123@example.com',
    Subject       => 'article subject test',
    Body          => 'article body test',
    HistoryType   => 'NewTicket',
    HistoryComment => '%%',
    UserID        => $UserID,
);

# sanity check
$Self->True(
    $ArticleID,
    "ArticleCreate() successful for Article ID $ArticleID",
);

my $DynamicFieldObject      = $Kernel::OM->Get('Kernel::System::DynamicField');
my $DynamicFieldValueObject = $Kernel::OM->Get('Kernel::System::DynamicFieldValue');

# Create test ticket dynamic field of type checkbox.
my $FieldID = $DynamicFieldObject->DynamicFieldAdd(
    Name       => "DFT1$RandomID",
    Label      => 'Description',
    FieldOrder => 9991,
    FieldType  => 'Checkbox',
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
    "DynamicFieldAdd - Added checkbox field ($FieldID)",
);

# Set ticket dynamic field checkbox value to unchecked.
$Success = $DynamicFieldValueObject->ValueSet(
    FieldID  => $FieldID,
    ObjectID => $TicketID,
    Value    => [
        {
            ValueInt => 0,
        },
    ],
    UserID => 1,
);
$Self->True(
    $Success,
    'ValueSet - Checkbox value set to unchecked',
);

my $SuccessWatcher = $TicketObject->TicketWatchSubscribe(
    TicketID    => $TicketID,
    WatchUserID => $UserID,
    UserID      => $UserID,
);

# sanity check
$Self->True(
    $SuccessWatcher,
    "TicketWatchSubscribe() successful for Ticket ID $TicketID",
);

my @Tests = (
    {
        Name => 'Missing Event',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
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
    },
    {
        Name => 'Missing Data',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
        },
        Config => {
            Event  => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Config => {},
            UserID => 1,
        },
        ExpectedResults => [],
        Success         => 0,
    },
    {
        Name => 'Missing Config',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
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
    },
    {
        Name => 'Missing UserID',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
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
    },
    {
        Name => 'RecipientAgent PostMasteruserID',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        SetOutOfOffice          => 1,
        SetOutOfOfficeDiffStart => -3 * 60 * 60 * 24,
        SetOutOfOfficeDiffEnd   => -1 * 60 * 60 * 24,
        Success                 => 1,
    },
    {
        Name => 'RecipientAgent OutOfOffice (currently)',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
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
        SetOutOfOffice          => 1,
        SetOutOfOfficeDiffStart => -1 * 60 * 60 * 24,
        SetOutOfOfficeDiffEnd   => 1 * 60 * 60 * 24,
        Success                 => 1,
    },
    {
        Name => 'RecipientAgent OutOfOffice (in the future)',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        SetOutOfOffice          => 1,
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'Recipients Responsible',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['AgentResponsible'],
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'Recipients Watcher',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['AgentWatcher'],
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'Recipients Read Permissions',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['AgentReadPermissions'],
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
            {
                ToArray => [ $UserData4{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'Recipients Write Permissions',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['AgentWritePermissions'],
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'RecipientAgent invalid',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [ $UserID, $UserData3{UserID} ],
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'Single RecipientAgent',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
            {
                ToArray => ['test@kixexample.com'],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'RecipientAgent SkipRecipients',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
            {
                ToArray => [ $UserData4{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
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
                ToArray => [ $UserData{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
            {
                ToArray => [ $UserData4{UserEmail} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
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
            VisibleForCustomer => [1]
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
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
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

            # Filter by unchecked checkbox dynamic field value. Note that the search value (-1) is
            #   different than the match value (0). See bug#12257 for more information.
            'Ticket::DynamicField_DFT1' . $RandomID => [0],
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
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'article subject match',
        Data => {
            Events             => [ 'ArticleCreate' ],
            RecipientEmail     => ['test@kixexample.com'],
            'Article::Subject' => ['subject te'],
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
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'article ChannelID match',
        Data => {
            Events             => [ 'ArticleCreate' ],
            RecipientEmail     => ['test@kixexample.com'],
            'Article::ChannelID' => [1],
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
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
            },
        ],
        Success => 1,
    },
    {
        Name => 'create article - agent notification',
        Data => {
            Events             => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents    => [$UserID],
            Channel            => ['note'],
            CreateArticle      => [1],
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
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
                ToArray => [ $UserData{UserEmail} ],
            },
        ],
        Success => 1,
    },
    {
        Name => 'create article - customer notification',
        Data => {
            Events             => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients         => ['Customer'],
            Channel            => ['note'],
            CreateArticle      => [1],
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
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
                ToArray => [$Contact{Email}],
            },
        ],
        Success => 1,
    },
    {
        Name => 'create article - agent notification (visible for customer)',
        Data => {
            Events             => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents    => [$UserID],
            Channel            => ['note'],
            VisibleForCustomer => [1],
            CreateArticle      => [1],
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
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
                ToArray => [ $UserData{UserEmail} ],
            },
        ],
        Success => 1,
    },
    {
        Name => 'create article - customer notification (visible for customer)',
        Data => {
            Events             => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients         => ['Customer'],
            Channel            => ['note'],
            VisibleForCustomer => [1],
            CreateArticle      => [1],
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
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserData{UserFirstname}=\n",
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
                ToArray => [ $UserData{UserEmail} ],
            },
        ],
        Success => 1,
    },
);

my $SetPostMasterUserID = sub {
    my %Param = @_;

    my $Success = $ConfigObject->Set(
        Key   => 'PostmasterUserID',
        Value => $Param{UserID},
    );

    $Self->True(
        $Success,
        "PostmasterUserID set to $Param{UserID}",
    );
};

my $SetOutOfOffice = sub {
    my %Param = @_;

    if ( $Param{OutOfOffice} ) {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');
        my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
            SystemTime => $TimeObject->SystemTime() + $Param{SetOutOfOfficeDiffStart},
        );

        my ( $ESec, $EMin, $EHour, $EDay, $EMonth, $EYear, $EWeekDay ) = $TimeObject->SystemTime2Date(
            SystemTime => $TimeObject->SystemTime() + $Param{SetOutOfOfficeDiffEnd},
        );

        my %Preferences = (
            OutOfOfficeStartYear  => $Year,
            OutOfOfficeStartMonth => $Month,
            OutOfOfficeStartDay   => $Day,
            OutOfOfficeEndYear    => $EYear,
            OutOfOfficeEndMonth   => $EMonth,
            OutOfOfficeEndDay     => $EDay,
        );

        # pref update db
        my $Success = $UserObject->SetPreferences(
            UserID => $Param{UserID},
            Key    => 'OutOfOffice',
            Value  => 1,
        );

        for my $Key (
            qw( OutOfOfficeStartYear OutOfOfficeStartMonth OutOfOfficeStartDay OutOfOfficeEndYear OutOfOfficeEndMonth OutOfOfficeEndDay)
            )
        {

            # pref update db
            my $PreferenceSet = $UserObject->SetPreferences(
                UserID => $Param{UserID},
                Key    => $Key,
                Value  => $Preferences{$Key},
            );

            if ( !$PreferenceSet ) {
                $Success = 0;
            }
        }

        $Self->True(
            $Success,
            "User set OutOfOffice",
        );
    }
    else {

        # pref update db
        my $Success = $UserObject->SetPreferences(
            UserID => $Param{UserID},
            Key    => 'OutOfOffice',
            Value  => 0,
        );

        $Self->True(
            $Success,
            "User set Not OutOfOffice",
        );
    }

    my %UserPreferences = $UserObject->GetPreferences(
        UserID => $Param{UserID},
    );

    return $UserPreferences{OutOfOffice};

};

my $SetTicketHistory = sub {
    my %Param = @_;

    my $Success = $TicketObject->HistoryAdd(
        TicketID     => $TicketID,
        HistoryType  => 'SendAgentNotification',
        Name         => "\%\%$Param{NotificationName}\%\%$Param{UserLogin}\%\%Email",
        CreateUserID => $Param{UserID},
    );

    $Self->True(
        $Success,
        "Ticket HistoryAdd() for User $Param{UserID}",
    );
};

my $SetUserNotificationPreference = sub {
    my %Param = @_;

    my $Value = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
        Data => {
            "Notification-$Param{NotificationID}-Email" => $Param{Value},
        },
    );

    my $Success = $UserObject->SetPreferences(
        Key    => 'NotificationTransport',
        Value  => $Value,
        UserID => $Param{UserID},
    );

    $Self->True(
        $Success,
        "Updated notification $Param{NotificationID} preference with value $Param{Value} for User $Param{UserID}",
    );
};

my $PostmasterUserID = $ConfigObject->Get('PostmasterUserID') || 1;

my $NotificationEventObject      = $Kernel::OM->Get('Kernel::System::NotificationEvent');
my $EventNotificationEventObject = $Kernel::OM->Get('Kernel::System::Ticket::Event::NotificationEvent');

my $Count = 0;
my $NotificationID;
TEST:
for my $Test (@Tests) {

    # save article count of ticket for later use
    my @ArticleBoxInitial = $TicketObject->ArticleContentIndex(
        TicketID => $TicketID,
        UserID   => 1,
    );

    # add transport setting
    $Test->{Data}->{Transports} = ['Email'];

    if ( $Test->{ContentType} && $Test->{ContentType} eq 'text/html' ) {
        # enable RichText
        $Kernel::OM->Get('Kernel::System::TemplateGenerator')->{RichText} = 1;
        my $Success = $ConfigObject->Set(
            Key   => 'Frontend::RichText',
            Value => 1,
        );
    }
    elsif ( $ConfigObject->Get('Frontend::RichText' )) {
        # disable RichText
        $Kernel::OM->Get('Kernel::System::TemplateGenerator')->{RichText} = 0;
        my $Success = $ConfigObject->Set(
            Key   => 'Frontend::RichText',
            Value => 0,
        );
    }

    $NotificationID = $NotificationEventObject->NotificationAdd(
        Name    => "JobName$Count-$RandomID",
        Comment => 'An optional comment',
        Data    => $Test->{Data},
        Message => (!$Test->{ContentType} || $Test->{ContentType} ne 'text/html') ? {
            en => {
                Subject     => 'JobName',
                Body        => 'JobName <KIX_TICKET_TicketID> <KIX_CONFIG_SendmailModule> <KIX_OWNER_UserFirstname>',
                ContentType => 'text/plain',
            },
            de => {
                Subject     => 'JobName',
                Body        => 'JobName <KIX_TICKET_TicketID> <KIX_CONFIG_SendmailModule> <KIX_OWNER_UserFirstname>',
                ContentType => 'text/plain',
            },
        } : {
            en => {
                Subject     => 'JobName',
                Body        => 'JobName &lt;KIX_TICKET_TicketID&gt; &lt;KIX_CONFIG_SendmailModule&gt; &lt;KIX_OWNER_UserFirstname&gt;',
                ContentType => 'text/html',
            },
            de => {
                Subject     => 'JobName',
                Body        => 'JobName &lt;KIX_TICKET_TicketID&gt; &lt;KIX_CONFIG_SendmailModule&gt; &lt;KIX_OWNER_UserFirstname&gt;',
                ContentType => 'text/html',
            },
        },
        ValidID => 1,
        UserID  => 1,
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

    if ( $Test->{SetOutOfOffice} ) {
        my $SuccessOOO = $SetOutOfOffice->(
            SetOutOfOfficeDiffStart => $Test->{SetOutOfOfficeDiffStart},
            SetOutOfOfficeDiffEnd   => $Test->{SetOutOfOfficeDiffEnd},
            UserID                  => $UserID,
            OutOfOffice             => 1,
        );

        # set out of office should always be true
        next TEST if !$SuccessOOO;
    }

    my $Result = $EventNotificationEventObject->Run( %{ $Test->{Config} } );

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
        my @ArticleBox = $TicketObject->ArticleContentIndex(
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
    my $NotificationDelete = $NotificationEventObject->NotificationDelete(
        ID     => $NotificationID,
        UserID => 1,
    );

    # sanity check
    $Self->True(
        $NotificationDelete,
        "$Test->{Name} - NotificationDelete() successful for Notification ID $NotificationID",
    );

    $TestEmailObject->CleanUp();

    # reset PostMasteruserID to the original value
    if ( $Test->{SetPostMasterUserID} ) {
        $SetPostMasterUserID->(
            UserID => $PostmasterUserID,
        );
    }

    # reset OutOfOffice status
    if ( $Test->{SetOutOfOffice} ) {
        $SetOutOfOffice->(
            UserID      => $UserID,
            OutOfOffice => 0,
        );
    }

    $Count++;
    undef $NotificationID;
}

# cleanup is done by RestoreDatabase but we need to run cleanup
# code too to remove data if the FS backend is used

# delete the ticket
my $TicketDelete = $TicketObject->TicketDelete(
    TicketID => $TicketID,
    UserID   => $UserID,
);

# sanity check
$Self->True(
    $TicketDelete,
    "TicketDelete() successful for Ticket ID $TicketID",
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
