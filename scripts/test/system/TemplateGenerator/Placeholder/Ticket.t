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

# sets a fix time to get no problem with age check.
$Helper->FixedTimeSet();

my $TestUser = $Helper->TestUserCreate(
    Language => 'de',
    Roles    => [
        'Ticket Agent'
    ]
);

my %User = $Kernel::OM->Get('User')->GetUserData(
    User  => $TestUser
);

my $TestContactID = $Helper->TestContactCreate(
    Language => 'de',
);

my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $TestContactID
);

my %Ticket = _CreateTicket(
    Contact  => \%Contact,
    User     => \%User,
    TestName => '_CreateTicket(): ticket create'
);

my @UnitTests;
# placeholder of KIX_TICKET_
for my $Attribute ( sort keys %Ticket ) {

    my $Expection = $Ticket{$Attribute};
    if (
        $Attribute eq 'AccountedTime'
        && !defined $Ticket{$Attribute}
    ) {
        $Expection = 0;
    }
    elsif ( !defined $Ticket{$Attribute} ) {
        $Expection = q{-};
    }
    elsif ( $Attribute =~ /^(State|Type|Priority|StateType|Lock)$/ ) {
        $Expection = $Kernel::OM->Get('Language')->Translate($Ticket{$Attribute});
    }
    elsif ( $Attribute =~ /^(Changed|Created)$/ ) {
        $Expection = $Kernel::OM->Get('Language')->FormatTimeString(
            $Ticket{$Attribute},
            'DateFormat',
            'NoSeconds',
        );
    }

    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_TICKET_$Attribute>",
            TicketID  => $Ticket{TicketID},
            Test      => "<KIX_TICKET_$Attribute>",
            Expection => $Expection,
        },
        {
            TestName  => "Placeholder: <KIX_TICKET_$Attribute!>",
            TicketID  => $Ticket{TicketID},
            Test      => "<KIX_TICKET_$Attribute!>",
            Expection => defined $Ticket{$Attribute} ? $Ticket{$Attribute} : '-',
        }
    );
}

# special placeholder
push(
    @UnitTests,
    {
        TestName  => "Placeholder: <KIX_TICKET_QUEUE>",
        TicketID  => $Ticket{TicketID},
        Test      => "<KIX_TICKET_QUEUE>",
        Expection => $Ticket{Queue},
    },
    {
        TestName  => "Placeholder: <KIX_TICKET_ID>",
        TicketID  => $Ticket{TicketID},
        Test      => "<KIX_TICKET_ID>",
        Expection => $Ticket{TicketID},
    },
    {
        TestName  => "Placeholder: <KIX_TICKET_NUMBER>",
        TicketID  => $Ticket{TicketID},
        Test      => "<KIX_TICKET_NUMBER>",
        Expection => $Ticket{TicketNumber},
    },
    {
        TestName  => 'Placeholder: <KIX_TICKET_StatePrevious>',
        TicketID  => $Ticket{TicketID},
        Test      => '<KIX_TICKET_StatePrevious>',
        Expection => 'new',
    },
    {
        TestName  => 'Placeholder: <KIX_TICKET_StateIDPrevious>',
        TicketID  => $Ticket{TicketID},
        Test      => '<KIX_TICKET_StateIDPrevious>',
        Expection => 1,
    }
);


# negative placeholder
push(
    @UnitTests,
    {
        TestName  => "Placeholder: <KIX_TICKET_Channel> not exists",
        TicketID  => $Ticket{TicketID},
        Test      => "<KIX_TICKET_Channel>",
        Expection => q{-},
    },
    {
        TestName  => "Placeholder: <KIX_TICKET_ArticleType>  not exists",
        TicketID  => $Ticket{TicketID},
        Test      => "<KIX_TICKET_ArticleType>",
        Expection => q{-},
    },
    {
        TestName  => "Placeholder: <KIX_TICKET_CustomerVisible>  not exists",
        TicketID  => $Ticket{TicketID},
        Test      => "<KIX_TICKET_CustomerVisible>",
        Expection => q{-},
    }
);

# run tests
_TestRun(
    Tests => \@UnitTests
);

# update ticket
%Ticket = _UpdateTicket(
    TicketID => $Ticket{TicketID},
    TestName => '_UpdateTicket(): ticket update'
);

# prepare test cases after update
@UnitTests = (
    {
        TestName  => 'Placeholder: <KIX_TICKET_StatePrevious>',
        TicketID  => $Ticket{TicketID},
        Test      => '<KIX_TICKET_StatePrevious>',
        Expection => 'new',
    },
    {
        TestName  => 'Placeholder: <KIX_TICKET_StateIDPrevious>',
        TicketID  => $Ticket{TicketID},
        Test      => '<KIX_TICKET_StateIDPrevious>',
        Expection => 1,
    }
);

# run tests
_TestRun(
    Tests => \@UnitTests
);

# prepare test cases after update
@UnitTests = (
    {
        TestName  => 'Placeholder: <KIX_TICKET_AttachmentCount>',
        Ticket    => {
            AttachmentCount => 5
        },
        Test      => '<KIX_TICKET_AttachmentCount>',
        Expection => '5',
    },
);

# run tests
_TestRun(
    Tests => \@UnitTests
);

sub _TestRun {
    my (%Param) = @_;

    for my $Test ( @{$Param{Tests}} ) {
        my $Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
            RichText  => 0,
            Text      => $Test->{Test},
            Data      => $Test->{Ticket} ? {Ticket => $Test->{Ticket}} : {},
            TicketID  => $Test->{TicketID} || undef,
            Translate => 1,
            UserID    => 1,

        );

        $Self->Is(
            $Result,
            $Test->{Expection},
            $Test->{TestName}
        );
    }

    return 1;
}

sub _CreateTicket {
    my (%Param) = @_;

    my $ID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title           => 'UnitTest Ticket ' . $Helper->GetRandomID(),
        Queue           => 'Junk',
        Lock            => 'unlock',
        Priority        => '3 normal',
        State           => 'new',
        OrganisationID  => $Contact{PrimaryOrganisationID},
        ContactID       => $Contact{UserID},
        OwnerID         => $User{UserID},
        UserID          => 1
    );

    $Self->True(
        $ID,
        $Param{TestName}
    );

    $Kernel::OM->Get('Ticket')->TicketStateSet(
        TicketID => $ID,
        State    => 'open',
        UserID   => 1
    );

    my %Data = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID => $ID,
        UserID   => 1
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Ticket'
        ]
    );

    return %Data;
}

sub _UpdateTicket {
    my (%Param) = @_;

    my $NewStateID = $Kernel::OM->Get('Ticket')->TicketStateSet(
        TicketID => $Param{TicketID},
        State    => 'open',
        UserID   => 1
    );

    $Self->True(
        $NewStateID,
        $Param{TestName}
    );

    my %Data = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID => $Param{TicketID},
        UserID   => 1
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Ticket'
        ]
    );

    return %Data;
}

# removed fixed time
$Helper->FixedTimeUnset();

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
