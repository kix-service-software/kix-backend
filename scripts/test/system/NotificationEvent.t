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

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get notification event object
my $NotificationEventObject = $Kernel::OM->Get('NotificationEvent');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $RandomID = $Helper->GetRandomID();

my $UserID     = 1;
my $TestNumber = 1;

my $CacheObject = $Kernel::OM->Get('Cache');

$Kernel::OM->Get('Cache')->CleanUp(
    Type => 'NotificationEvent',
);

# workaround for oracle
# oracle databases can't determine the difference between NULL and ''
my $IsNotOracle = 1;
if ( $Kernel::OM->Get('DB')->GetDatabaseFunction('Type') eq 'oracle' ) {
    $IsNotOracle = 0;
}

my @Tests = (

    # notification add must fail - empty Name param
    {
        Name       => 'Test ' . $TestNumber++,
        SuccessAdd => 0,
        Add        => {
            Name    => '',
            Comment => 'Just something for test',
            Data    => {
                Events => ['TicketQueueUpdate'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject',
                    Body        => 'Body for notification',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel',
                    Body        => 'Textinhalt der Benachrichtigung',
                    ContentType => 'text/plain',
                },
            },
            ValidID => 1,
            Silent  => 1,
        },
    },

    # notification add must fail - missing Data param
    {
        Name       => 'Test ' . $TestNumber++,
        SuccessAdd => 0,
        Add        => {
            Name    => 'NotificationName' . $RandomID . $TestNumber,
            Comment => 'Just something for test',
            Message => {
                en => {
                    Subject     => 'Notification subject',
                    Body        => 'Body for notification',
                    ContentType => 'text/plain',
                },
            },
            ValidID => 1,
            Silent  => 1,
        },
    },

    # notification add must fail - missing Message param
    {
        Name       => 'Test ' . $TestNumber++,
        SuccessAdd => 0,
        Add        => {
            Name    => 'NotificationName' . $RandomID . $TestNumber,
            Comment => 'Just something for test',
            Data    => {
                Events => ['TicketQueueUpdate'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue' },
                ]
            },
            ValidID => 1,
            Silent  => 1,
        },
    },

    # notification add must fail - empty Message-Subject param
    {
        Name       => 'Test ' . $TestNumber++,
        SuccessAdd => 0,
        Add        => {
            Name    => 'NotificationName' . $RandomID . $TestNumber,
            Comment => 'Just something for test',
            Data    => {
                Events => ['TicketQueueUpdate'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject',
                    Body        => 'Body for notification',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject     => '',
                    Body        => 'Textinhalt der Benachrichtigung',
                    ContentType => 'text/plain',
                },
            },
            ValidID => 1,
            Silent  => 1,
        },
    },

    # notification add must fail - empty Message-Body param
    {
        Name       => 'Test ' . $TestNumber++,
        SuccessAdd => 0,
        Add        => {
            Name    => 'NotificationName' . $RandomID . $TestNumber,
            Comment => 'Just something for test',
            Data    => {
                Events => ['TicketQueueUpdate'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject',
                    Body        => 'Body for notification',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel',
                    Body        => '',
                    ContentType => 'text/plain',
                },
            },
            ValidID => 1,
            Silent  => 1,
        },
    },

    # notification add must fail - empty Message-ContentType param
    {
        Name       => 'Test ' . $TestNumber++,
        SuccessAdd => 0,
        Add        => {
            Name    => 'NotificationName' . $RandomID . $TestNumber,
            Comment => 'Just something for test',
            Data    => {
                Events => ['TicketQueueUpdate'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject',
                    Body        => 'Body for notification',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel',
                    Body        => 'Textinhalt der Benachrichtigung',
                    ContentType => '',
                },
            },
            ValidID => 1,
            Silent  => 1,
        },
    },

    # notification add must fail - missing ValidID parameter
    {
        Name       => 'Test ' . $TestNumber++,
        SuccessAdd => 0,
        Add        => {
            Name    => 'NotificationName' . $RandomID . $TestNumber,
            Comment => 'Just something for test',
            Data    => {
                Events => ['TicketQueueUpdate'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject',
                    Body        => 'Body for notification',
                    ContentType => 'text/plain',
                },
            },
            Silent  => 1,
        },
    },

    # first successful add and update
    {
        Name          => 'Test ' . $TestNumber++,
        SuccessAdd    => 1,
        SuccessUpdate => 1,
        Add           => {
            Name    => 'NotificationName' . $RandomID,
            Comment => 'This is a test comment.',
            Data    => {
                Events => [ 'AnEventForThisTest' . $RandomID ],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject',
                    Body        => 'Body for notification',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel',
                    Body        => 'Textinhalt der Benachrichtigung',
                    ContentType => 'text/plain',
                },
            },
            ValidID => 1,
        },
    },

    # add must fail because of duplicate name
    {
        Name       => 'Test ' . $TestNumber++,
        SuccessAdd => 0,
        Add        => {
            Name    => 'NotificationName' . $RandomID,
            Comment => 'This is a test comment.',
            Data    => {
                Events => [ 'AnEventForThisTest' . $RandomID ],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject',
                    Body        => 'Body for notification',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel',
                    Body        => 'Textinhalt der Benachrichtigung',
                    ContentType => 'text/plain',
                },
            },
            ValidID => 1,
            Silent  => 1,
        },
    },

    # successful add and update
    {
        Name          => 'Test ' . $TestNumber++,
        SuccessAdd    => 1,
        SuccessUpdate => 1,
        Add           => {
            Name    => 'NotificationNameSuccess' . $RandomID,
            Comment => 'This is a test comment.',
            Data    => {
                Events => [ 'AnEventForThisTest' . $RandomID ],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject',
                    Body        => 'Body for notification',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel',
                    Body        => 'Textinhalt der Benachrichtigung',
                    ContentType => 'text/plain',
                },
            },
            ValidID => 2,
        },

        Update => {
            Name    => 'NotificationNameModifiedSuccess' . $RandomID,
            Comment => 'Just something for test modified',
            Data    => {
                Events => [ 'AnEventForThisTest' . $RandomID ],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeOtherQueue' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Modified Notification subject',
                    Body        => 'Modified Body for notification',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject     => 'Geänderter Benachrichtigungs-Titel',
                    Body        => 'Geänderter Textinhalt der Benachrichtigung',
                    ContentType => 'text/plain',
                },
            },
            ValidID => 1,
        },
    },

    # another successful add and update
    {
        Name          => 'Test ' . $TestNumber++,
        SuccessAdd    => 1,
        SuccessUpdate => 1,
        Add           => {
            Name    => 'NotificationNameSuccess-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' . $RandomID,
            Comment => 'Just something for test-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
            Data    => {
                Events => ['TicketQueueUpdate'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Body for notification-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Textinhalt der Benachrichtigung-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/plain',
                },
            },
            ValidID => 2,
        },

        Update => {
            Name    => 'Notification-äüßÄÖÜ€исáéíúúÁÉÍÚñÑNameModifiedSuccess' . $RandomID,
            Comment => 'Just something modified for test-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
            Data    => {
                Events => [ 'AnEventForThisTest' . $RandomID ],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'ADifferentQueue-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Modified Notification subject-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Modified Body for notification-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/plain',
                },
                de => {
                    Subject => 'Geänderter Benachrichtigungs-Titel-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body    => 'Geänderter Textinhalt der Benachrichtigung-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/plain',
                },
            },
            ValidID => 1,
        },
    },
    {
        Name          => 'TestHTML ' . $TestNumber++,
        SuccessAdd    => 1,
        SuccessUpdate => 1,
        Add           => {
            Name    => 'NotificationHTMLNameSuccess-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' . $RandomID,
            Comment => 'Just something for test-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
            Data    => {
                Events => ['TicketQueueUpdate'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Body for notification-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Textinhalt der Benachrichtigung-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
            },
            ValidID => 2,
        },

        Update => {
            Name    => 'NotificationHTML-äüßÄÖÜ€исáéíúúÁÉÍÚñÑNameModifiedSuccess' . $RandomID,
            Comment => 'Just something modified for test-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
            Data    => {
                Events => [ 'AnEventForThisTest' . $RandomID ],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'ADifferentQueue-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Modified Notification subject-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Modified Body for notification-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
                de => {
                    Subject => 'Geänderter Benachrichtigungs-Titel-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body => 'Geänderter Textinhalt der Benachrichtigung-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
            },
            ValidID => 1,
        },
    },
    {
        Name          => 'TestHTML ' . $TestNumber++,
        SuccessAdd    => 1,
        SuccessUpdate => 1,
        Add           => {
            Name    => 'NotificationHTMLNameSuccess-TicketType' . $RandomID,
            Comment => 'Just something for test-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
            Data    => {
                Events           => ['TicketQueueUpdate'],
                NotificationType => ['Ticket'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Body for notification-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Textinhalt der Benachrichtigung-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
            },
            ValidID => 2,
        },

        Update => {
            Name    => 'NotificationHTML-TicketType' . $RandomID,
            Comment => 'Just something modified for test-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
            Data    => {
                Events           => [ 'AnEventForThisTest' . $RandomID ],
                NotificationType => ['Ticket'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'ADifferentQueue-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Modified Notification subject-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Modified Body for notification-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
                de => {
                    Subject => 'Geänderter Benachrichtigungs-Titel-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body => 'Geänderter Textinhalt der Benachrichtigung-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
            },
            ValidID => 1,
        },
    },
    {
        Name          => 'TestHTML ' . $TestNumber++,
        SuccessAdd    => 1,
        SuccessUpdate => 1,
        Add           => {
            Name    => 'NotificationHTMLNameSuccess-UnitTestType' . $RandomID,
            Comment => 'Just something for test-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
            Data    => {
                Events           => ['TicketQueueUpdate'],
                NotificationType => ['UnitTestType'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Body for notification-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Textinhalt der Benachrichtigung-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
            },
            ValidID => 2,
        },

        Update => {
            Name    => 'NotificationHTML-UnitTestType' . $RandomID,
            Comment => 'Just something modified for test-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
            Data    => {
                Events           => [ 'AnEventForThisTest' . $RandomID ],
                NotificationType => ['UnitTestType'],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'ADifferentQueue-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Modified Notification subject-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Modified Body for notification-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
                de => {
                    Subject => 'Geänderter Benachrichtigungs-Titel-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body => 'Geänderter Textinhalt der Benachrichtigung-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
            },
            ValidID => 1,
        },
    },
    {
        Name          => 'TestHTML ' . $TestNumber++,
        SuccessAdd    => 1,
        SuccessUpdate => 1,
        Add           => {
            Name    => 'NotificationHTMLNameSuccess-UnitTestType2' . $RandomID,
            Comment => 'Just something for test-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
            Data    => {
                Events           => ['TicketQueueUpdate'],
                NotificationType => [ 'UnitTestType' . $RandomID ],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'SomeQueue-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Notification subject-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Body for notification-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
                de => {
                    Subject     => 'Benachrichtigungs-Titel-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Textinhalt der Benachrichtigung-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
            },
            ValidID => 2,
        },

        Update => {
            Name    => 'NotificationHTML-UnitTestType2' . $RandomID,
            Comment => 'Just something modified for test-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
            Data    => {
                Events           => [ 'AnEventForThisTest' . $RandomID ],
                NotificationType => [ 'UnitTestType' . $RandomID ],
            },
            Filter => {
                AND => [
                    { Field => 'Queue', Operator => 'EQ', Value => 'ADifferentQueue-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ' },
                ]
            },
            Message => {
                en => {
                    Subject     => 'Modified Notification subject-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body        => 'Modified Body for notification-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
                de => {
                    Subject => 'Geänderter Benachrichtigungs-Titel-äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    Body => 'Geänderter Textinhalt der Benachrichtigung-<br>äüßÄÖÜ€исáéíúúÁÉÍÚñÑ',
                    ContentType => 'text/html',
                },
            },
            ValidID => 1,
        },
    },
);

my %NotificationIDs;
TEST:
for my $Test (@Tests) {

    # Add NotificationEvent
    my $NotificationID = $NotificationEventObject->NotificationAdd(
        %{ $Test->{Add} },
        UserID => $UserID,
    );

    if ( !$Test->{SuccessAdd} ) {
        $Self->False(
            $NotificationID,
            "$Test->{Name} - NotificationEventAdd()",
        );
        next TEST;
    }
    else {
        $Self->True(
            $NotificationID,
            "$Test->{Name} - NotificationEventAdd()",
        );
    }

    # determine notification type
    my $NotificationType = '';

    if (
        !$Test->{Add}->{Data}->{NotificationType}
        || !$Test->{Add}->{Data}->{NotificationType}->[0]
        )
    {
        $NotificationType = 'Ticket';
    }
    else {
        $NotificationType = $Test->{Add}->{Data}->{NotificationType}->[0];
    }

    if ( !IsHashRefWithData( $NotificationIDs{$NotificationType} ) ) {
        $NotificationIDs{$NotificationType} = ();
    }

    # remember ID to verify it later
    $NotificationIDs{$NotificationType}->{$NotificationID} = $Test->{Add}->{Name};

    # get NotificationEvent
    my %NotificationEvent = $NotificationEventObject->NotificationGet(
        Name => $Test->{Add}->{Name},
    );

    my %NotificationEventByID = $NotificationEventObject->NotificationGet(
        ID => $NotificationID,
    );

    $Self->IsDeeply(
        \%NotificationEvent,
        \%NotificationEventByID,
        "$Test->{Name} - NotificationEventGet() - By name and by ID",
    );

    # verify NotificationEvent
    $Self->Is(
        IsHashRefWithData( \%NotificationEvent ),
        1,
        "$Test->{Name} - NotificationEventGet() - Right structure",
    );

    $Self->Is(
        $NotificationEvent{ID},
        $NotificationID,
        "$Test->{Name} - NotificationEventGet() - ID",
    );

    $Self->Is(
        $NotificationEvent{Name},
        $Test->{Add}->{Name},
        "$Test->{Name} - NotificationEventGet() - Name",
    );

    # workaround for oracle
    # oracle databases can't determine the difference between NULL and ''
    if ( !defined $NotificationEvent{Comment} && !$IsNotOracle ) {
        $NotificationEvent{Comment} = '';
    }

    $Self->Is(
        $NotificationEvent{Comment},
        $Test->{Add}->{Comment},
        "$Test->{Name} - NotificationEventGet() - Comment",
    );

    $Self->Is(
        $NotificationEvent{ValidID},
        $Test->{Add}->{ValidID},
        "$Test->{Name} - NotificationEventGet() - ValidID",
    );

    $Self->IsDeeply(
        $NotificationEvent{Data},
        $Test->{Add}->{Data},
        "$Test->{Name} - NotificationEventGet() - Data",
    );

    $Self->IsDeeply(
        $NotificationEvent{Message},
        $Test->{Add}->{Message},
        "$Test->{Name} - NotificationEventGet() - Message",
    );

    $Self->True(
        $NotificationEvent{ChangeTime},
        "$Test->{Name} - NotificationEventGet() - ChangeTime",
    );

    $Self->True(
        $NotificationEvent{CreateTime},
        "$Test->{Name} - NotificationEventGet() - CreateTime",
    );

    $Self->Is(
        $NotificationEvent{ChangeBy},
        $UserID,
        "$Test->{Name} - NotificationEventGet() - ChangeBy",
    );

    $Self->Is(
        $NotificationEvent{CreateBy},
        $UserID,
        "$Test->{Name} - NotificationEventGet() - CreateBy",
    );

    # update NotificationEvent
    if ( !$Test->{Update} ) {
        $Test->{Update} = $Test->{Add};
    }

    # include ID on update data
    $Test->{Update}->{ID} = $NotificationID;

    my $SuccessUpdate = $NotificationEventObject->NotificationUpdate(
        %{ $Test->{Update} },
        UserID => $UserID,
    );
    if ( !$Test->{SuccessUpdate} ) {
        $Self->False(
            $SuccessUpdate,
            "$Test->{Name} - NotificationEventUpdate() False",
        );
        next TEST;
    }
    else {
        $Self->True(
            $SuccessUpdate,
            "$Test->{Name} - NotificationEventUpdate() True",
        );
    }

    # remember ID to verify it later
    $NotificationIDs{$NotificationType}->{$NotificationID} = $Test->{Update}->{Name};

    # get NotificationEvent
    %NotificationEvent = $NotificationEventObject->NotificationGet(
        Name => $Test->{Update}->{Name},
    );

    %NotificationEventByID = $NotificationEventObject->NotificationGet(
        ID => $NotificationID,
    );

    $Self->IsDeeply(
        \%NotificationEvent,
        \%NotificationEventByID,
        "$Test->{Name} - NotificationEventGet() - By name and by ID",
    );

    # verify NotificationEvent
    $Self->Is(
        IsHashRefWithData( \%NotificationEvent ),
        1,
        "$Test->{Name} - NotificationEventGet() - Right structure",
    );

    $Self->Is(
        $NotificationEvent{ID},
        $NotificationID,
        "$Test->{Name} - NotificationEventGet() - ID",
    );

    $Self->Is(
        $NotificationEvent{Name},
        $Test->{Update}->{Name},
        "$Test->{Name} - NotificationEventGet() - Name",
    );

    # workaround for oracle
    # oracle databases can't determine the difference between NULL and ''
    if ( !defined $NotificationEvent{Comment} && !$IsNotOracle ) {
        $NotificationEvent{Comment} = '';
    }

    $Self->Is(
        $NotificationEvent{Comment},
        $Test->{Update}->{Comment},
        "$Test->{Name} - NotificationEventGet() - Comment",
    );

    $Self->Is(
        $NotificationEvent{ValidID},
        $Test->{Update}->{ValidID},
        "$Test->{Name} - NotificationEventGet() - ValidID",
    );

    $Self->IsDeeply(
        $NotificationEvent{Data},
        $Test->{Update}->{Data},
        "$Test->{Name} - NotificationEventGet() - Data",
    );

    $Self->IsDeeply(
        $NotificationEvent{Message},
        $Test->{Update}->{Message},
        "$Test->{Name} - NotificationEventGet() - Message",
    );

    $Self->True(
        $NotificationEvent{ChangeTime},
        "$Test->{Name} - NotificationEventGet() - ChangeTime",
    );

    $Self->True(
        $NotificationEvent{CreateTime},
        "$Test->{Name} - NotificationEventGet() - CreateTime",
    );

    $Self->Is(
        $NotificationEvent{ChangeBy},
        $UserID,
        "$Test->{Name} - NotificationEventGet() - ChangeBy",
    );

    $Self->Is(
        $NotificationEvent{CreateBy},
        $UserID,
        "$Test->{Name} - NotificationEventGet() - CreateBy",
    );

}

# get ID from added notifications
my @AddedNotifications;

for my $NotificationType ( sort keys %NotificationIDs ) {
    push @AddedNotifications, sort keys %{ $NotificationIDs{$NotificationType} };
}

# verify IDs
$Self->Is(
    IsArrayRefWithData( \@AddedNotifications ),
    1,
    "Added Notification IDs- Right structure",
);

my @IDs = sort $NotificationEventObject->NotificationEventCheck( Event => 'AnEventForThisTest' . $RandomID );

# verify NotificationEventCheck
$Self->Is(
    IsArrayRefWithData( \@IDs ),
    1,
    "NotificationEventCheck() - Right structure",
);

$Self->IsDeeply(
    \@IDs,
    \@AddedNotifications,
    "NotificationEventCheck()",
);

# check notifications with type ticket
my %NotificationList = $NotificationEventObject->NotificationList( Type => 'Ticket' );
for my $NotificationID ( sort keys %NotificationIDs ) {
    $Self->Is(
        $NotificationList{$NotificationID},
        $NotificationIDs{Ticket}->{$NotificationID},
        "NotificationList() from DB with type 'Ticket' found NotificationEvent $NotificationID",
    );
}

# clear cache
$Kernel::OM->Get('Cache')->CleanUp(
    Type => 'NotificationEvent',
);

# check notifications with type ticket in details mode
%NotificationList = $NotificationEventObject->NotificationList(
    Type    => 'Ticket',
    Details => 1,
);

for my $NotificationID ( sort keys %NotificationIDs ) {
    $Self->Is(
        $NotificationList{$NotificationID}->{Name},
        $NotificationIDs{Ticket}->{$NotificationID},
        "NotificationList() from DB with type 'Ticket' in details mode found NotificationEvent $NotificationID",
    );
}

# check notifications with type ticket in details mode
%NotificationList = $NotificationEventObject->NotificationList(
    Type    => 'Ticket',
    Details => 1,
    All     => 1,
);

for my $NotificationID ( sort keys %NotificationIDs ) {

    my $NotificationType = '';

    if (
        !$NotificationList{$NotificationID}->{Data}->{NotificationType}
        || !$NotificationList{$NotificationID}->{Data}->{NotificationType}->[0]
        )
    {
        $NotificationType = 'Ticket';
    }
    else {
        $NotificationType = $NotificationList{$NotificationID}->{Data}->{NotificationType}->[0];
    }

    $Self->Is(
        $NotificationList{$NotificationID}->{Name},
        $NotificationIDs{$NotificationType}->{$NotificationID},
        "NotificationList() from DB with type 'Ticket' in details mode and all types found NotificationEvent $NotificationID",
    );
}

# clear cache
$Kernel::OM->Get('Cache')->CleanUp(
    Type => 'NotificationEvent',
);

# check notifications with type ticket in details mode
%NotificationList = $NotificationEventObject->NotificationList(
    Type    => 'Ticket',
    Details => 1,
);

for my $NotificationID ( sort keys %NotificationIDs ) {
    $Self->Is(
        $NotificationList{$NotificationID}->{Name},
        $NotificationIDs{Ticket}->{$NotificationID},
        "NotificationList() from DB with type 'Ticket' in details mode found NotificationEvent $NotificationID",
    );
}

# list check from DB without type and deletion
for my $NotificationType ( sort keys %NotificationIDs ) {

    %NotificationList = $NotificationEventObject->NotificationList( Type => $NotificationType );

    for my $NotificationID ( sort keys %{ $NotificationIDs{$NotificationType} } ) {

        $Self->Is(
            $NotificationList{$NotificationID},
            $NotificationIDs{$NotificationType}->{$NotificationID},
            "NotificationList() from DB found NotificationEvent $NotificationID",
        );

        # delete entry
        my $SuccesDelete = $NotificationEventObject->NotificationDelete(
            ID     => $NotificationID,
            UserID => $UserID,
        );

        $Self->True(
            $SuccesDelete,
            "NotificationDelete() - $NotificationID",
        );
    }
}

# list check deleted entries
for my $NotificationType ( sort keys %NotificationIDs ) {

    %NotificationList = $NotificationEventObject->NotificationList( Type => $NotificationType );

    for my $NotificationID ( sort keys %{ $NotificationIDs{$NotificationType} } ) {
        $Self->False(
            $NotificationList{$NotificationID},
            "NotificationList() deleted entry - $NotificationID",
        );
    }
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
