# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
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

# check supported methods
for my $Method ( qw(Create Update Get Exists Updatable Delete) ) {
    $Self->True(
        $Kernel::OM->Get('TimeAccounting')->can("TimeAccounting$Method"),
        'TimeAccounting object can "TimeAccounting' . $Method . '"'
    );
}

# begin transaction on database
$Helper->BeginWork();

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2026-01-01 12:00:00',
);
$Helper->FixedTimeSet($SystemTime);

# prepare ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title     => 'UnitTest',
    OwnerID   => 1,
    Queue     => 'Junk',
    Lock      => 'unlock',
    Priority  => '3 normal',
    State     => 'open',
    UserID    => 1,
    ContactID => 1
);
$Self->True(
    $TicketID,
    'Create Ticket'
);

# prepare article
my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID         => $TicketID,
    ChannelID        => 1,
    CustomerVisible  => 0,
    SenderType       => 'agent',
    Subject          => 'UnitTest',
    Body             => '<p>UnitTest<p>',
    Charset          => 'utf-8',
    MimeType         => 'text/html; charset="utf-8"',
    HistoryType      => 'AddNote',
    HistoryComment   => 'unit test article!',
    UserID           => 1
);
$Self->True(
    $ArticleID,
    'Create Article'
);

## TimeAccountingCreate ##
my @TimeAccountingCreateTests = (
    {
        Name          => 'TimeAccountingCreate: No defined parameter',
        Parameter     => {
            Silent => 1
        },
        Expected     => undef,
    },
    {
        Name          => 'TimeAccountingCreate: Missing TicketID!',
        Parameter     => {
            TimeUnit           => 1,
            ExecutingContactID => 1,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need TicketID!'
    },
    {
        Name          => 'TimeAccountingCreate: Missing TimeUnit!',
        Parameter     => {
            TicketID           => $TicketID,
            ExecutingContactID => 1,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need TimeUnit!'
    },
    {
        Name          => 'TimeAccountingCreate: Missing IsInvoiced!',
        Parameter     => {
            TicketID           => $TicketID,
            TimeUnit           => 1,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need IsInvoiced!'
    },
    {
        Name          => 'TimeAccountingCreate: Missing ExecutingContactID!',
        Parameter     => {
            TicketID           => $TicketID,
            TimeUnit           => 1,
            StartTime          => '2026-01-01 12:00:00',
            IsInvoiced         => 0,
            UserID             => 1,
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need ExecutingContactID!'
    },
    {
        Name          => 'TimeAccountingCreate: Missing StartTime!',
        Parameter     => {
            TicketID           => $TicketID,
            TimeUnit           => 1,
            ExecutingContactID => 1,
            IsInvoiced         => 0,
            UserID             => 1,
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need StartTime!'
    },
    {
        Name          => 'TimeAccountingCreate: Missing UserID!',
        Parameter     => {
            TicketID           => $TicketID,
            TimeUnit           => 1,
            ExecutingContactID => 1,
            IsInvoiced         => 0,
            StartTime          => '2026-01-01 12:00:00',
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need UserID!'
    },
    {
        Name          => 'TimeAccountingCreate: Invalid ExecutingContactID',
        Parameter     => {
            TicketID           => $TicketID,
            TimeUnit           => 1,
            ExecutingContactID => -1,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            IsInvoiced         => 0,
            UserType           => 'Agent',
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Contact (-1) does not exist!'
    },
    {
        Name          => 'TimeAccountingCreate: Create time accounting entry for ticket',
        Parameter     => {
            TicketID           => $TicketID,
            TimeUnit           => 1,
            ExecutingContactID => 1,
            IsInvoiced         => 0,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
        },
        Expected     => 1,
        ErrorMessage => undef
    },
    {
        Name          => 'TimeAccountingCreate: Create time accounting entry for article',
        Parameter     => {
            TicketID           => $TicketID,
            ArticleID          => $ArticleID,
            TimeUnit           => 1,
            ExecutingContactID => 1,
            IsInvoiced         => 0,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
        },
        Expected     => 1,
        ErrorMessage => undef
    },
    {
        Name          => 'TimeAccountingCreate: Duplicate extended time accounting entry',
        Parameter     => {
            TicketID           => $TicketID,
            ArticleID          => $ArticleID,
            TimeUnit           => 1,
            ExecutingContactID => 1,
            IsInvoiced         => 0,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => "TimeAccounting for TicketID ($TicketID) and ArticleID ($ArticleID) already exists!"
    },
    {
        Name          => 'TimeAccountingCreate: Create time accounting entry with additional params',
        Parameter     => {
            TicketID           => $TicketID,
            TimeUnit           => 2,
            ExecutingContactID => 1,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            UserType           => 'Agent',
            Description        => 'UnitTest',
            IsInvoiced         => 1
        },
        Expected     => 1,
        ErrorMessage => undef
    },
);
my @TimeAccountingIDs = ();
for my $Test ( @TimeAccountingCreateTests ) {
    # clear logstack of error
    $Kernel::OM->Get('Log')->{LogStack}->{16} = [];

    my $Result = $Kernel::OM->Get('TimeAccounting')->TimeAccountingCreate(
        %{ $Test->{Parameter} }
    );
    if ( defined( $Test->{Expected} ) ) {
        $Self->True(
            $Result,
            $Test->{Name}
        );
    }
    else {
        $Self->Is(
            $Result,
            $Test->{Expected},
            $Test->{Name}
        );
    }

    if ( defined( $Result ) ) {
        push( @TimeAccountingIDs, $Result );
    }

    if ( exists( $Test->{ErrorMessage} ) ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        $Self->Is(
            $LogMessage,
            $Test->{ErrorMessage},
            $Test->{Name} . ' (ErrorMessage)'
        );
    }
}

## TimeAccountingGet ##
my @TimeAccountingGetTests = (
    {
        Name          => 'TimeAccountingGet: Missing TimeAccountingID',
        Parameter     => {
            Silent => 1
        },
        Expected     => {},
        ErrorMessage => 'Need TimeAccountingID!'
    },
    {
        Name          => 'TimeAccountingGet: Invalid TimeAccountingID',
        Parameter     => {
            TimeAccountingID => -1,
            Silent           => 1
        },
        Expected     => {},
        ErrorMessage => 'TimeAccounting with TimeAccountingID -1 not found!'
    },
    {
        Name          => 'TimeAccountingGet: Get first time accounting entry',
        Parameter     => {
            TimeAccountingID => $TimeAccountingIDs[0],
        },
        Expected     => {
            ID                 => $TimeAccountingIDs[0],
            TicketID           => $TicketID,
            ArticleID          => undef,
            TimeUnit           => '1.00',
            ExecutingContactID => 1,
            Description        => undef,
            StartTime          => '2026-01-01 12:00:00',
            IsInvoiced         => 0,
            CreateTime         => '2026-01-01 12:00:00',
            CreateBy           => 1,
            ChangeTime         => '2026-01-01 12:00:00',
            ChangeBy           => 1
        },
        ErrorMessage => undef
    },
    {
        Name          => 'TimeAccountingGet: Get second time accounting entry',
        Parameter     => {
            TimeAccountingID => $TimeAccountingIDs[1],
        },
        Expected     => {
            ID                 => $TimeAccountingIDs[1],
            TicketID           => $TicketID,
            ArticleID          => $ArticleID,
            TimeUnit           => '1.00',
            ExecutingContactID => 1,
            Description        => undef,
            StartTime          => '2026-01-01 12:00:00',
            IsInvoiced         => 0,
            CreateTime         => '2026-01-01 12:00:00',
            CreateBy           => 1,
            ChangeTime         => '2026-01-01 12:00:00',
            ChangeBy           => 1
        },
        ErrorMessage => undef
    },
    {
        Name          => 'TimeAccountingGet: Get third time accounting entry',
        Parameter     => {
            TimeAccountingID => $TimeAccountingIDs[2],
        },
        Expected     => {
            ID                 => $TimeAccountingIDs[2],
            TicketID           => $TicketID,
            ArticleID          => undef,
            TimeUnit           => '2.00',
            ExecutingContactID => 1,
            Description        => 'UnitTest',
            StartTime          => '2026-01-01 12:00:00',
            IsInvoiced         => 1,
            CreateTime         => '2026-01-01 12:00:00',
            CreateBy           => 1,
            ChangeTime         => '2026-01-01 12:00:00',
            ChangeBy           => 1
        },
        ErrorMessage => undef
    },
);
for my $Test ( @TimeAccountingGetTests ) {
    # clear logstack of error
    $Kernel::OM->Get('Log')->{LogStack}->{16} = [];

    my %Result = $Kernel::OM->Get('TimeAccounting')->TimeAccountingGet(
        %{ $Test->{Parameter} }
    );
    $Self->IsDeeply(
        \%Result,
        $Test->{Expected},
        $Test->{Name}
    );

    if ( exists( $Test->{ErrorMessage} ) ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        $Self->Is(
            $LogMessage,
            $Test->{ErrorMessage},
            $Test->{Name} . ' (ErrorMessage)'
        );
    }
}

## TimeAccountingUpdate ##
# set fixed time to have predetermined verifiable results
$SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2026-01-01 13:00:00',
);
$Helper->FixedTimeSet($SystemTime);
my @TimeAccountingUpdateTests = (
    {
        Name          => 'TimeAccountingUpdate: No defined parameter',
        Parameter     => {
            Silent => 1
        },
        Expected     => undef,
    },
    {
        Name          => 'TimeAccountingUpdate: Missing UserID',
        Parameter     => {
            TimeUnit           => 1,
            ExecutingContactID => 1,
            StartTime          => '2026-01-01 12:00:00',
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need UserID!'
    },
    {
        Name          => 'TimeAccountingUpdate: Missing TimeUnit',
        Parameter     => {
            ExecutingContactID => 1,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need TimeUnit!'
    },
    {
        Name          => 'TimeAccountingUpdate: Missing TimeAccountingID',
        Parameter     => {
            TimeUnit           => 1,
            ExecutingContactID => 1,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need TimeAccountingID or TicketID and ArticleID!'
    },
    {
        Name          => 'TimeAccountingUpdate: No TimeAccountingID, but given TicketID and invalid ArticleID',
        Parameter     => {
            TicketID           => $TicketID,
            ArticleID          => 0,
            TimeUnit           => 1,
            ExecutingContactID => 1,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need TimeAccountingID or TicketID and ArticleID!'
    },
    {
        Name          => 'TimeAccountingUpdate: Invalid TimeAccountingID',
        Parameter     => {
            TimeAccountingID   => -1,
            ExecutingContactID => 1,
            TimeUnit           => 1,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            UserType           => 'Agent',
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'TimeAccounting with TimeAccountingID (-1) not found!'
    },
    {
        Name          => 'TimeAccountingUpdate: Invalid ExecutingContactID',
        Parameter     => {
            TimeAccountingID   => $TimeAccountingIDs[0],
            ExecutingContactID => -1,
            TimeUnit           => 1,
            StartTime          => '2026-01-01 12:00:00',
            UserID             => 1,
            UserType           => 'Agent',
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Contact (-1) does not exist!'
    },
    {
        Name          => 'TimeAccountingUpdate: Update time accounting entry',
        Parameter     => {
            TimeAccountingID   => $TimeAccountingIDs[0],
            ExecutingContactID => 1,
            TimeUnit           => 3,
            StartTime          => '2026-01-01 11:00:00',
            UserID             => 1,
            UserType           => 'Agent',
            Description        => 'UnitTest',
            IsInvoiced         => 0,        },
        Expected     => $TimeAccountingIDs[0],
        ErrorMessage => undef
    },
    {
        Name          => 'TimeAccountingUpdate: Update invoiced time accounting entry',
        Parameter     => {
            TimeAccountingID   => $TimeAccountingIDs[2],
            ExecutingContactID => 1,
            TimeUnit           => 4,
            StartTime          => '2026-01-02 12:00:00',
            UserID             => 1,
            IsInvoiced         => 1,
            Silent             => 1
        },
        Expected     => undef,
        ErrorMessage => 'Time accounting (' . $TimeAccountingIDs[2] . ') is not updatable!'
    }
);
for my $Test ( @TimeAccountingUpdateTests ) {
    # clear logstack of error
    $Kernel::OM->Get('Log')->{LogStack}->{16} = [];

    my $Result = $Kernel::OM->Get('TimeAccounting')->TimeAccountingUpdate(
        %{ $Test->{Parameter} }
    );
    $Self->Is(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );

    if ( exists( $Test->{ErrorMessage} ) ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        $Self->Is(
            $LogMessage,
            $Test->{ErrorMessage},
            $Test->{Name} . ' (ErrorMessage)'
        );
    }
}

## TimeAccountingGet after update ##
my @TimeAccountingGetTests2 = (
    {
        Name          => 'TimeAccountingGet after update: Get first extended time accounting entry',
        Parameter     => {
            TimeAccountingID => $TimeAccountingIDs[0],
        },
        Expected     => {
            ID                 => $TimeAccountingIDs[0],
            TicketID           => $TicketID,
            ArticleID          => undef,
            TimeUnit           => '3.00',
            ExecutingContactID => 1,
            Description        => 'UnitTest',
            StartTime          => '2026-01-01 11:00:00',
            IsInvoiced         => 0,
            CreateTime         => '2026-01-01 12:00:00',
            CreateBy           => 1,
            ChangeTime         => '2026-01-01 13:00:00',
            ChangeBy           => 1
        },
        ErrorMessage => undef
    },
    {
        Name          => 'TimeAccountingGet after update: Get second extended time accounting entry',
        Parameter     => {
            TimeAccountingID => $TimeAccountingIDs[2],
        },
        Expected     => {
            ID                 => $TimeAccountingIDs[2],
            TicketID           => $TicketID,
            ArticleID          => undef,
            TimeUnit           => '2.00',
            ExecutingContactID => 1,
            Description        => 'UnitTest',
            StartTime          => '2026-01-01 12:00:00',
            IsInvoiced         => 1,
            CreateTime         => '2026-01-01 12:00:00',
            CreateBy           => 1,
            ChangeTime         => '2026-01-01 12:00:00',
            ChangeBy           => 1
        },
        ErrorMessage => undef
    },
);
for my $Test ( @TimeAccountingGetTests2 ) {
    # clear logstack of error
    $Kernel::OM->Get('Log')->{LogStack}->{16} = [];

    my %Result = $Kernel::OM->Get('TimeAccounting')->TimeAccountingGet(
        %{ $Test->{Parameter} }
    );
    $Self->IsDeeply(
        \%Result,
        $Test->{Expected},
        $Test->{Name}
    );

    if ( exists( $Test->{ErrorMessage} ) ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        $Self->Is(
            $LogMessage,
            $Test->{ErrorMessage},
            $Test->{Name} . ' (ErrorMessage)'
        );
    }
}

## TimeAccountingExists ##
my @TimeAccountingExistsTests = (
    {
        Name         => 'TimeAccountingExists: Missing UserID',
        Parameter    => {
            Silent => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need UserID'
    },
    {
        Name         => 'TimeAccountingExists: Missing TimeAccountingID',
        Parameter    => {
            UserID => 1,
            Silent => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need TimeAccountingID or TicketID and ArticleID!'
    },
    {
        Name         => 'TimeAccountingExists: Invalid TimeAccountingID',
        Parameter    => {
            UserID           => 1,
            TimeAccountingID => -1,
        },
        Expected     => undef,
        ErrorMessage => undef
    },
    {
        Name         => 'TimeAccountingExists: Valid TimeAccountingID',
        Parameter    => {
            UserID           => 1,
            TimeAccountingID => $TimeAccountingIDs[0],
        },
        Expected     => $TimeAccountingIDs[0],
        ErrorMessage => undef
    },
);
for my $Test ( @TimeAccountingExistsTests ) {
    # clear logstack of error
    $Kernel::OM->Get('Log')->{LogStack}->{16} = [];

    my $Result = $Kernel::OM->Get('TimeAccounting')->TimeAccountingExists(
        %{ $Test->{Parameter} }
    );
    $Self->Is(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );

    if ( exists( $Test->{ErrorMessage} ) ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        $Self->Is(
            $LogMessage,
            $Test->{ErrorMessage},
            $Test->{Name} . ' (ErrorMessage)'
        );
    }
}

## TimeAccountingUpdatable ##
my @TimeAccountingUpdatableTests = (
    {
        Name         => 'TimeAccountingUpdatable: Missing TimeAccountingID',
        Parameter    => {
            Silent => 1
        },
        Expected     => undef,
        ErrorMessage => 'Need TimeAccountingID'
    },
    {
        Name         => 'TimeAccountingUpdatable: Invalid TimeAccountingID',
        Parameter    => {
            TimeAccountingID => -1,
            Silent           => 1
        },
        Expected     => 0,
        ErrorMessage => 'Time accounting (-1) is not updatable!'
    },
    {
        Name         => 'TimeAccountingUpdatable: Invoiced TimeAccountingID',
        Parameter    => {
            TimeAccountingID => $TimeAccountingIDs[2],
            Silent           => 1
        },
        Expected     => 0,
        ErrorMessage => 'Time accounting (' . $TimeAccountingIDs[2] .') is not updatable!'
    },
    {
        Name         => 'TimeAccountingUpdatable: Valid TimeAccountingID',
        Parameter    => {
            TimeAccountingID => $TimeAccountingIDs[0],
        },
        Expected     => 1,
        ErrorMessage => undef
    },
);
for my $Test ( @TimeAccountingUpdatableTests ) {
    # clear logstack of error
    $Kernel::OM->Get('Log')->{LogStack}->{16} = [];

    my $Result = $Kernel::OM->Get('TimeAccounting')->TimeAccountingUpdatable(
        %{ $Test->{Parameter} }
    );
    $Self->Is(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );

    if ( exists( $Test->{ErrorMessage} ) ) {
        my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        $Self->Is(
            $LogMessage,
            $Test->{ErrorMessage},
            $Test->{Name} . ' (ErrorMessage)'
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
