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

use vars (qw($Self));

use Kernel::System::PostMaster;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# define needed variable
my $RandomID = $Helper->GetRandomID();

# create a dynamic field
my $FieldName = 'Text' . $RandomID;
my $FieldID   = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    Name       => $FieldName,
    Label      => $FieldName . "_test",
    FieldOrder => 9991,
    FieldType  => 'Text',
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue => 'a value',
    },
    ValidID => 1,
    UserID  => 1,
);

# verify dynamic field creation
$Self->True(
    $FieldID,
    "DynamicFieldAdd() successful for Field $FieldName",
);

# ensure that the appropriate X-Headers are available in the config
my %NeededXHeaders = (
#rbo - T2016121190001552 - renamed X-KIX headers
    "X-KIX-$FieldName"          => 1,
    "X-KIX-FollowUp-$FieldName" => 1,
);

my $XHeaders          = $Kernel::OM->Get('Config')->Get('PostmasterX-Header');
my @PostmasterXHeader = @{$XHeaders};

HEADER:
for my $Header ( sort keys %NeededXHeaders ) {
    next HEADER if ( grep $_ eq $Header, @PostmasterXHeader );
    push @PostmasterXHeader, $Header;
}

# filter test
my @Tests = (
    {
        Name  => "#1 - Body Test",
        Email => "From: Sender <sender\@example.com>
To: Some Name <recipient\@example.com>
Subject: A simple question
X-KIX-DynamicField-$FieldName: 1

This is a multiline
email for server: example.tld

The IP address: 192.168.0.1
        ",
        Return => 1,    # it's a new ticket
        Check  => {
            "DynamicField_$FieldName" => [ 1 ],
        },
    },
    {
        Name  => '#2 - Subject Test',
        Email => "From: Sender <sender\@example.com>
To: Some Name <recipient\@example.com>
Subject: [#1] Another question
X-KIX-FollowUp-DynamicField-$FieldName: 0

This is a multiline
email for server: example.tld

The IP address: 192.168.0.1
        ",
        Return => 2,    # it's a followup
        Check  => {
            "DynamicField_$FieldName" => [ 0 ],
        },
    },
    {
        Name  => '#3 - Body Test - 2',
        Email => "From: Sender <sender\@example.com>
To: Some Name <recipient\@example.com>
Subject: A simple question
X-KIX-DynamicField-$FieldName: 0

This is a multiline
email for server: example.tld

The IP address: 192.168.0.1
        ",
        Return => 1,    # it's a new ticket
        Check  => {
            "DynamicField_$FieldName" => [ 0 ],
        },
    },

);

my %TicketNumbers;
my %TicketIDs;

my $Index = 1;
for my $Test (@Tests) {
    my $Name  = $Test->{Name};
    my $Email = $Test->{Email};

    $Email =~ s{\[#([0-9]+)\]}{[Ticket#$TicketNumbers{$1}]};

    my @Return;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Trusted => 1,
            Email   => \$Email,
        );

        $Kernel::OM->Get('Config')->Set(
            Key   => 'PostmasterX-Header',
            Value => \@PostmasterXHeader
        );

        @Return = $PostMasterObject->Run();
        @Return = @{ $Return[0] || [] };
    }
    $Self->Is(
        $Return[0] || 0,
        $Test->{Return},
        "$Name - NewTicket/FollowUp",
    );
    $Self->True(
        $Return[1] || 0,
        "$Name - TicketID",
    );

    # new/clear ticket object
    $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    for my $Key ( sort keys %{ $Test->{Check} } ) {
        $Self->IsDeeply(
            $Ticket{$Key},
            $Test->{Check}->{$Key},
            "Run('$Test->{Name}') - $Key",
        );
    }

    $TicketNumbers{$Index} = $Ticket{TicketNumber};
    $TicketIDs{ $Return[1] }++;

    $Index++;
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
