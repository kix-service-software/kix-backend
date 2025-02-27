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

use Kernel::System::Role::Permission;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# disable rich text editor
my $Success = $Kernel::OM->Get('Config')->Set(
    Key   => 'Frontend::RichText',
    Value => 0,
);
$Self->True(
    $Success,
    "Disable RichText with true",
);

# use Test email backend
$Success = $Kernel::OM->Get('Config')->Set(
    Key   => 'SendmailModule',
    Value => 'Kernel::System::Email::Test',
);
$Self->True(
    $Success,
    "Set Email Test backend with true",
);

# set not self notify
$Success = $Kernel::OM->Get('Config')->Set(
    Key   => 'AgentSelfNotifyOnAction',
    Value => 0,
);
$Self->True(
    $Success,
    "Disable Agent Self Notify On Action",
);

# disable asynchron notification
$Kernel::OM->Get('Config')->Set(
    Key   => 'TicketNotification::SendAsynchronously',
    Value => 0,
);

# get a random id
my $RandomID = $Helper->GetRandomID();


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

my $RoleID = $Helper->TestRoleCreate(
    Name        => "ticket_write_$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission::PERMISSION->{UPDATE},
            },
        ],
        'Base::Ticket' => [
            {
                Target => '1',
                Value  => Kernel::System::Role::Permission::PERMISSION->{WRITE},
            },
        ],
    }
);

# create a new user for current test
my $UserLogin = $Helper->TestUserCreate(
    Roles => ["ticket_read_$RandomID","ticket_write_$RandomID"],
);
my %UserData = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin,
);
my $UserID = $UserData{UserID};
my %UserContactData = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $UserID,
);

# create ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Ticket One Title',
    QueueID        => 1,
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'new',
    OrganisationID => 'example.com',
    OwnerID        => $UserID,
    UserID         => 1,
);

# sanity check
$Self->True(
    $TicketID,
    "TicketCreate() successful for Ticket ID $TicketID",
);

my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID       => $TicketID,
    Channel        => 'note',
    CustomerVisible => 1,
    SenderType     => 'external',
    From           => 'customerOne@example.com, customerTwo@example.com',
    To             => 'Some Agent A <agent-a@example.com>',
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

# create a dynamic field
my $FieldID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    Name       => "DFT1$RandomID",
    Label      => 'Description',
    FieldOrder => 9991,
    FieldType  => 'Text',
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue => 'Default',
    },
    ValidID => 1,
    UserID  => 1,
    Reorder => 0,
);

# Make sure that ticket events are handled
$Kernel::OM->ObjectsDiscard(
    Objects => [ 'Ticket' ],
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

my @Tests = (
    {
        Name => 'Single RecipientAgent',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            Transports      => ['Email'],
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
    },
    {
        Name => 'RecipientAgent + RecipientEmail',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            RecipientEmail  => ['test@kixexample.com'],
            Transports      => ['Email'],
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
    },
    {
        Name => 'Recipient Customer - JustToRealCustomer enabled',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['Customer'],
            Transports => ['Email'],
        },
        ExpectedResults    => [],
        JustToRealCustomer => 1,
    },
    {
        Name => 'Recipient Customer - JustToRealCustomer disabled',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['Customer'],
            Transports => ['Email'],
        },
        ExpectedResults => [
            {
                ToArray => [ 'customerOne@example.com', 'customerTwo@example.com' ],
                Body => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        JustToRealCustomer => 0,
    },
);

my $Count = 0;
for my $Test (@Tests) {

    # set just to real customer
    my $JustToRealCustomer = $Test->{JustToRealCustomer} || 0;
    $Success = $Kernel::OM->Get('Config')->Set(
        Key   => 'CustomerNotifyJustToRealCustomer',
        Value => $JustToRealCustomer,
    );

    $Self->True(
        $Success,
        "Set notifications just to real customer: $JustToRealCustomer.",
    );

    my $NotificationID = $Kernel::OM->Get('NotificationEvent')->NotificationAdd(
        Name    => "JobName$Count-$RandomID",
        Data    => $Test->{Data},
        Message => {
            en => {
                Subject     => 'JobName',
                Body        => 'JobName <KIX_TICKET_TicketID> <KIX_CONFIG_SendmailModule> <KIX_OWNER_Firstname>',
                ContentType => 'text/plain',
            },
        },
        Comment => 'An optional comment',
        ValidID => 1,
        UserID  => 1,
        Silent  => $Test->{Silent} || 0,
    );

    # sanity check
    $Self->IsNot(
        $NotificationID,
        undef,
        "$Test->{Name} - NotificationAdd() should not be undef",
    );

    # Make sure that the NotificationEvent-Handler gets recreated for each loop.
    $Kernel::OM->ObjectsDiscard(
        Objects => [ 'Kernel::System::Ticket::Event::NotificationEvent' ],
    );

    my $Result = $Kernel::OM->Get('Kernel::System::Ticket::Event::NotificationEvent')->Run(
        Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
        Data  => {
            TicketID => $TicketID,
        },
        Config => {},
        UserID => 1,
        Silent => $Test->{Silent} || 0,
    );
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

    $Count++;
}

# cleanup

# delete the dynamic field
my $DFDelete = $Kernel::OM->Get('DynamicField')->DynamicFieldDelete(
    ID      => $FieldID,
    UserID  => 1,
    Reorder => 0,
);

# sanity check
$Self->True(
    $DFDelete,
    "DynamicFieldDelete() successful for Field ID $FieldID",
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
