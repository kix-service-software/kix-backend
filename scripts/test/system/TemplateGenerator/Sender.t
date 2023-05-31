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

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $RandomID = $Helper->GetRandomID();

# create template generator after the dynamic field are created as it gathers all DF in the
# constructor
my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

my $TestContactID = $Helper->TestContactCreate(
    Language => 'en',
);

my $ContactObject = $Kernel::OM->Get('User');

my %TestContact = $ContactObject->ContactGet(
    ID => $TestContactID,
);

# add SystemAddress
my $SystemAddressEmail    = $Helper->GetRandomID() . '@example.com';
my $SystemAddressRealname = "KIX-Team";

my $SystemAddressObject = $Kernel::OM->Get('SystemAddress');

my $SystemAddressID = $SystemAddressObject->SystemAddressAdd(
    Name     => $SystemAddressEmail,
    Realname => $SystemAddressRealname,
    Comment  => 'some comment',
    QueueID  => 1,
    ValidID  => 1,
    UserID   => 1,
);
my %SystemAddressData = $SystemAddressObject->SystemAddressGet( ID => $SystemAddressID );

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

    $SystemAddressObject->SystemAddressUpdate(
        %SystemAddressData,
        Realname => $Test->{SystemAddressName},
        UserID   => 1,
    );
    $ContactObject->ContactUpdate(
        %TestContact,
        Firstname => $Test->{AgentFirstname},
        Lastname  => $Test->{AgentLastname},
        ChangeUserID  => 1,
    );

    for my $DefineEmailFrom (qw(SystemAddressName AgentNameSystemAddressName AgentName)) {

        $ConfigObject->Set(
            Key   => 'Ticket::DefineEmailFrom',
            Value => $DefineEmailFrom,
        );

        my $Result = $TemplateGeneratorObject->Sender(
            QueueID => $QueueID,
            UserID  => $TestContact{UserID}
        );

        $Self->Is(
            $Result,
            $Test->{Result}->{$DefineEmailFrom},
            "$Test->{Name} - $DefineEmailFrom - Sender()",
        );
    }
}

# Cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
