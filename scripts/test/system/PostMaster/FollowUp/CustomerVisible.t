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

use Kernel::System::PostMaster;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create and get first test contact
my $ContactID1 = $Helper->TestContactCreate();
my %Contact1   = $Kernel::OM->Get('Contact')->ContactGet(
    ID            => $ContactID1,
    DynamicFields => 0,
);

# create and get second test contact
my $ContactID2 = $Helper->TestContactCreate();
my %Contact2   = $Kernel::OM->Get('Contact')->ContactGet(
    ID            => $ContactID2,
    DynamicFields => 0,
);

# add organisation of first contact to second contact
$Kernel::OM->Get('Contact')->ContactUpdate(
    %Contact2,
    OrganisationIDs => [ $Contact2{PrimaryOrganisationID}, $Contact1{PrimaryOrganisationID} ],
    UserID          => 1,
);

# create ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'PostMaster FollowUp CustomerVisible test ticket',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'open',
    OrganisationID => $Contact1{PrimaryOrganisationID},
    ContactID      => $ContactID1,
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

my @Tests = (
    {
        Name                  => 'Foreign contact, CheckFromOrganisation active',
        CheckFromOrganisation => '1',
        Email                 => <<"END",
From: Foreign Contact <foreign\@contact>
To: System <test\@localhost>
Subject: FollowUp Ticket#$Ticket{TicketNumber}

Some Content in Body
END
        CustomerVisible       => 0,
    },
    {
        Name                  => 'Foreign contact, header',
        CheckFromOrganisation => '0',
        Email                 => <<"END",
From: Foreign Contact <foreign\@contact>
To: System <test\@localhost>
X-KIX-FollowUp-CustomerVisible: 1
Subject: FollowUp Ticket#$Ticket{TicketNumber}

Some Content in Body
END
        CustomerVisible       => 1,
    },
    {
        Name                  => 'Ticket contact, CheckFromOrganisation inactive',
        CheckFromOrganisation => '0',
        Email                 => <<"END",
From: Foreign Contact <$Contact1{Email}>
To: System <test\@localhost>
Subject: FollowUp Ticket#$Ticket{TicketNumber}

Some Content in Body
END
        CustomerVisible       => 1,
    },
    {
        Name                  => 'Organisation contact, CheckFromOrganisation inactive',
        CheckFromOrganisation => '0',
        Email                 => <<"END",
From: Foreign Contact <$Contact2{Email}>
To: System <test\@localhost>
Subject: FollowUp Ticket#$Ticket{TicketNumber}

Some Content in Body
END
        CustomerVisible       => 0,
    },
    {
        Name                  => 'Organisation contact, CheckFromOrganisation active',
        CheckFromOrganisation => '1',
        Email                 => <<"END",
From: Foreign Contact <$Contact2{Email}>
To: System <test\@localhost>
Subject: FollowUp Ticket#$Ticket{TicketNumber}

Some Content in Body
END
        CustomerVisible       => 1,
    },
);

for my $Test (@Tests) {
    # prepare config
    $Kernel::OM->Get('Config')->Set(
        Key   => 'PostMaster::FollowUp::CheckFromOrganisation',
        Value => $Test->{CheckFromOrganisation} || 0,
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

    # check CustomerVisible of article
    $Self->Is(
        $LastArticle{CustomerVisible},
        $Test->{CustomerVisible},
        "$Test->{Name} - Check CustomerVisible",
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
