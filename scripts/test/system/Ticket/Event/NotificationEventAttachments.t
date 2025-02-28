# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get a random id
my $RandomID = $Helper->GetRandomID();

my $Success = $Kernel::OM->Get('Config')->Set(
    Key   => 'Frontend::RichText',
    Value => 1,
);
$Self->True(
    $Success,
    "Enable RichText",
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

# disable asynchron notification
$Kernel::OM->Get('Config')->Set(
    Key   => 'TicketNotification::SendAsynchronously',
    Value => 0,
);

# create role with WRITE on tickets
my $TicketWriteRoleID = $Helper->TestRoleCreate(
    Name        => "ticket_write_$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission::PERMISSION->{WRITE},
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
    Roles => ["ticket_write_$RandomID"],
);
my %UserData = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin,
);
my $UserID = $UserData{UserID};

# get queue data
my %Queue = $Kernel::OM->Get('Queue')->QueueGet(
    ID => 1,
);

# set queue to special group
$Success = $Kernel::OM->Get('Queue')->QueueUpdate(
    QueueID => 1,
    %Queue,
    UserID  => 1,
);

$Self->True(
    $Success,
    "Set Queue ID 1 to Group ID ",
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
    ResponsibleID  => $UserID,
    UserID         => 1,
);

# sanity check
$Self->True(
    $TicketID,
    "TicketCreate() successful for Ticket ID $TicketID",
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

# define params for sending as CustomerMessageParams
my $CustomerMessageParams = {
    A => 'AAAAA',
    B => 'BBBBB',
    C => 'CCCCC',
};

my %OriginalCustomerMessageParams = %{$CustomerMessageParams};

my @Tests = (
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
                TicketID              => $TicketID,
                CustomerMessageParams => $CustomerMessageParams,
            },
            Config => {},
            UserID => 1,
        },
        ExpectedResults => {
            '0' => 'text/plain; charset="utf-8"',
            '1' => 'text/html; charset="utf-8"'
        },
        Success => 1,
    },

);

my $Count = 0;
my $NotificationID;
TEST:
for my $Test (@Tests) {

    $NotificationID = $Kernel::OM->Get('NotificationEvent')->NotificationAdd(
        Name    => "JobName$Count-$RandomID",
        Comment => 'An optional comment',
        Data    => $Test->{Data},
        Message => {
            en => {
                Subject     => 'JobName',
                Body        => 'JobName <KIX_TICKET_TicketID> <KIX_CONFIG_SendmailModule> <KIX_OWNER_Firstname>',
                ContentType => 'text/plain',
            },
            de => {
                Subject     => 'JobName',
                Body        => 'JobName <KIX_TICKET_TicketID> <KIX_CONFIG_SendmailModule> <KIX_OWNER_Firstname>',
                ContentType => 'text/plain',
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

    # Make sure that the NotificationEvent-Handler gets recreated for each loop.
    $Kernel::OM->ObjectsDiscard(
        Objects => [ 'Kernel::System::Ticket::Event::NotificationEvent' ],
    );

    my $Result = $Kernel::OM->Get('Kernel::System::Ticket::Event::NotificationEvent')->Run( %{ $Test->{Config} } );

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
        my $Counter = 0;
        my %Result;
        for my $Header ( split '\n', ${ $Email->{Body} } ) {

            if ( $Header =~ /^Content\-Type\:\ (.*?)\;.*?\"(.*?)\"/x ) {
                $Result{$Counter} = ( split ': ', $Header )[1];
                $Counter++;
            }
        }

        $Self->Is(
            $Counter,
            2,
            "Attachment number should be 2, plain and html.",
        );

        $Self->IsDeeply(
            \%Result,
            $Test->{ExpectedResults},
            "$Test->{Name} - Attachments",
        );

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

    $Count++;
    undef $NotificationID;
}

# verify CustomerMessageParams reference have
# the same content as the beginning of this test
$Self->IsDeeply(
    $CustomerMessageParams,
    \%OriginalCustomerMessageParams,
    "CustomerMessageParams didn't grow after sending emails.",
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
