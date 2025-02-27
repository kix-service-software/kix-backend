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

# get needed objects
$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $RandomID = $Helper->GetRandomID();

# create template generator after the dynamic field are created as it gathers all DF in the
# constructor

my $TestContactID = $Helper->TestContactCreate(
    Language => 'en',
);

my %TestContact = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $TestContactID,
);

# add SystemAddress
my $SystemAddressEmail    = $Helper->GetRandomID() . '@example.com';
my $SystemAddressRealname = "KIX-Team";

my $SystemAddressID = $Kernel::OM->Get('SystemAddress')->SystemAddressAdd(
    Name     => $SystemAddressEmail,
    Realname => $SystemAddressRealname,
    Comment  => 'some comment',
    QueueID  => 1,
    ValidID  => 1,
    UserID   => 1,
);
my %SystemAddressData = $Kernel::OM->Get('SystemAddress')->SystemAddressGet(
    ID => $SystemAddressID
);

my $QueueRand = $Helper->GetRandomID();
my $QueueID   = $Kernel::OM->Get('Queue')->QueueAdd(
    Name                => $QueueRand,
    ValidID             => 1,
    GroupID             => 1,
    SystemAddressID     => $SystemAddressID,
    UserID              => 1,
    Comment             => 'Some Comment',
);

my @Tests = (
    {
        Name              => 'Simple replace',
        AgentFirstname    => 'John',
        AgentLastname     => 'Doe',
        SystemAddressName => 'Test',
        Result            => {
            SystemAddressName          => "Test <$SystemAddressEmail>",
            AgentNameSystemAddressName => "John Doe via Test <$SystemAddressEmail>",
            AgentName                  => "John Doe <$SystemAddressEmail>",
        },

    },
    {
        Name              => 'Company with dot, requires escaping',
        AgentFirstname    => 'John',
        AgentLastname     => 'Doe',
        SystemAddressName => 'company.com',
        Result            => {
            SystemAddressName          => qq|"company.com" <$SystemAddressEmail>|,
            AgentNameSystemAddressName => qq|"John Doe via company.com" <$SystemAddressEmail>|,
            AgentName                  => "John Doe <$SystemAddressEmail>",
        },
    },
    {
        Name              => 'Username with special character, requires escaping',
        AgentFirstname    => 'Jack (the)',
        AgentLastname     => 'Ripper',
        SystemAddressName => 'Test',
        Result            => {
            SystemAddressName          => "Test <$SystemAddressEmail>",
            AgentNameSystemAddressName => qq|"Jack (the) Ripper via Test" <$SystemAddressEmail>|,
            AgentName                  => qq|"Jack (the) Ripper" <$SystemAddressEmail>|,
        },
    },
);

for my $Test (@Tests) {

    $Kernel::OM->Get('SystemAddress')->SystemAddressUpdate(
        %SystemAddressData,
        Realname => $Test->{SystemAddressName},
        UserID   => 1,
    );
    $Kernel::OM->Get('Contact')->ContactUpdate(
        %TestContact,
        Firstname => $Test->{AgentFirstname},
        Lastname  => $Test->{AgentLastname},
        UserID    => 1,
    );

    for my $DefineEmailFrom (
        qw(
            SystemAddressName
            AgentNameSystemAddressName
            AgentName
        )
    ) {

        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::DefineEmailFrom',
            Value => $DefineEmailFrom,
        );

        my $Result = $Kernel::OM->Get('TemplateGenerator')->Sender(
            QueueID => $QueueID,
            UserID  => $TestContact{AssignedUserID}
        );

        $Self->Is(
            $Result,
            $Test->{Result}->{$DefineEmailFrom},
            "$Test->{Name} - $DefineEmailFrom - Sender()",
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
