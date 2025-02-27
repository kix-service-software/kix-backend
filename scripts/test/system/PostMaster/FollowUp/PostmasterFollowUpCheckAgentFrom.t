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

use Kernel::System::PostMaster;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create agent
my $AgentUserID = $Helper->TestUserCreate(Result => 'ID');
my %AgentContact = $Kernel::OM->Get('Contact')->ContactGet(
    UserID        => $AgentUserID,
    DynamicFields => 0
);

# create customer
my $CustomerContactID = $Helper->TestContactCreate();
my %CustomerContact = $Kernel::OM->Get('Contact')->ContactGet(
    ID            => $CustomerContactID,
    DynamicFields => 0
);

# create ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'PostMaster FollowUp PostmasterFollowUpCheckAgentFrom test ticket',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'open',
    OwnerID        => 1,
    UserID         => 1,
);
$Self->True(
    $TicketID,
    'TicketCreate',
);

my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID      => $TicketID,
    DynamicFields => 0,
    UserID        => 1,
    Silent        => 0,
);

if (IsHashRefWithData(\%Ticket)) {

    my @Tests = (
        {
            Name          => 'Not active - From customer',
            ExpectedType  => 'external',
            ConfigActive  => 0,
            Email         => <<"END",
From: "Customer Contact" <$CustomerContact{Email}>
To: System <test\@localhost>
Subject: Not active - From customer Ticket#$Ticket{TicketNumber}

Some Content in Body
END
        },
        {
            Name         => 'Not active - From agent',
            ExpectedType => 'external',
            ConfigActive => 0,
            Email        => <<"END",
From: "Agent Contact" <$AgentContact{Email}>
To: System <test\@localhost>
Subject: Not active - From agent Ticket#$Ticket{TicketNumber}

Some Content in Body
END
        },
        {
            Name          => 'Active - From customer',
            ExpectedType  => 'external',
            ConfigActive  => 1,
            Email         => <<"END",
From: "Customer Contact" <$CustomerContact{Email}>
To: System <test\@localhost>
Subject: Active - From customer Ticket#$Ticket{TicketNumber}

Some Content in Body
END
        },
        {
            Name         => 'Active - From agent',
            ExpectedType => 'agent',
            ConfigActive => 1,
            Email        => <<"END",
From: "Agent Contact" <$AgentContact{Email}>
To: System <test\@localhost>
Subject: Active - From agent Ticket#$Ticket{TicketNumber}

Some Content in Body
END
        },
        {
            Name         => 'Active - From agent but header is external',
            ExpectedType => 'external',
            ConfigActive => 1,
            Email        => <<"END",
From: "Agent Contact" <$AgentContact{Email}>
To: System <test\@localhost>
X-KIX-FollowUp-SenderType: external
Subject: Active - From agent but header is external Ticket#$Ticket{TicketNumber}

Some Content in Body
END
        },
    );

    for my $Test (@Tests) {

        # prepare config
        $Helper->ConfigSettingChange(
            Valid => 1,
            Key   => 'TicketStateWorkflow::PostmasterFollowUpCheckAgentFrom',
            Value => $Test->{ConfigActive} || 0
        );

        # process email
        my @Return;
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => $Test->{Email},
        );
        @Return = $PostMasterObject->Run();
        @Return = @{ $Return[0] || [] };
        $Self->Is(
            $Return[0] || 0,
            2,
            "$Test->{Name} - Check followup",
        );

        # get last article of ticket
        my %LastArticle = $Kernel::OM->Get('Ticket')->ArticleLastArticle(
            TicketID      => $TicketID,
            Extended      => 0,
            DynamicFields => 0,
        );

        # check sender type of article
        $Self->Is(
            $LastArticle{SenderType},
            $Test->{ExpectedType},
            "$Test->{Name} - Check SenderType",
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
