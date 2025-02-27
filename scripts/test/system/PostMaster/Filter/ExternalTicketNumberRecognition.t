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

# define needed variable
my $RandomID = $Helper->GetRandomID();
my %Jobs     = %{ $Kernel::OM->Get('Config')->Get('PostMaster::PreFilterModule') };

# create a dynamic field
my $FieldName = 'ExternalTNRecognition' . $RandomID;
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

my $ExternalTicketID = '13579' . $RandomID;

# filter test
my @Tests = (
    {
        Name  => '#1 - From Test - Fail',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject Incident-' . $ExternalTicketID . '

Some Content in Body',
        Check     => {},
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => 'externalsystem@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Incident-(\\d.*)\\s*',
            SearchInBody      => '1',
            SearchInSubject   => '1',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 1,
    },
    {
        Name  => '#2 - From Test Success',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject Incident-' . $ExternalTicketID . '

Some Content in Body',
        Check => {
            "DynamicField_$FieldName" => [ $ExternalTicketID ],
        },
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Incident-(\\d.*)\\s*',
            SearchInBody      => '1',
            SearchInSubject   => '1',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 1,
    },
    {
        Name  => '#3 - Subject Test - Fail',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject Incident-' . $ExternalTicketID . '7

Some Content in Body',
        Check     => {},
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Incident-(\\d.*)\\s*',
            SearchInBody      => '1',
            SearchInSubject   => '1',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 1,
    },
    {
        Name  => '#4 - Subject Test - Fail',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject Incident-' . $ExternalTicketID . '

Some Content in Body',
        Check     => {},
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Incident-(\\d.*)\\s*',
            SearchInBody      => '1',
            SearchInSubject   => '0',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 1,
    },
    {
        Name  => '#5 - Subject Test - Fail',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject Incident-' . $ExternalTicketID . '

Some Content in Body',
        Check     => {},
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Report-(\\d.*)\\s*',
            SearchInBody      => '1',
            SearchInSubject   => '1',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 1,
    },
    {
        Name  => '#6 - Subject Test Success',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject Incident-' . $ExternalTicketID . '

Some Content in Body',
        Check => {
            "DynamicField_$FieldName" => [ $ExternalTicketID ],
        },
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Incident-(\\d.*)\\s*',
            SearchInBody      => '1',
            SearchInSubject   => '1',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 2,
    },
    {
        Name  => '#3 - Body Test - Fail',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject

Some Content in Body Incident-' . $ExternalTicketID . '7',
        Check     => {},
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Incident-(\\d.*)\\s*',
            SearchInBody      => '1',
            SearchInSubject   => '1',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 2,
    },
    {
        Name  => '#4 - Body Test - Fail',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject

Some Content in Body Incident-' . $ExternalTicketID,
        Check     => {},
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Incident-(\\d.*)\\s*',
            SearchInBody      => '0',
            SearchInSubject   => '1',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 1,
    },
    {
        Name  => '#5 - Body Test - Fail',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject

Some Content in Body Incident-' . $ExternalTicketID,
        Check     => {},
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Report-(\\d.*)\\s*',
            SearchInBody      => '1',
            SearchInSubject   => '1',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 1,
    },
    {
        Name  => '#6 - Body Test Success',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject

Some Content in Body Incident-' . $ExternalTicketID,
        Check => {
            "DynamicField_$FieldName" => [ $ExternalTicketID ],
        },
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Incident-(\\d.*)\\s*',
            SearchInBody      => '1',
            SearchInSubject   => '1',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 2,
    },
    {
        Name =>
            '#7 - Body Test Success with Complex TicketNumber / Regex; special characters must be escaped in the regex',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
Subject: An incident subject

Some Content in Body Incident#/' . $ExternalTicketID,
        Check => {
            "DynamicField_$FieldName" => [ $ExternalTicketID ],
        },
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition',
            Name              => 'Some Description',
            NumberRegExp      => '\\s*Incident\#\/(\\d.*)\\s*',
            SearchInBody      => '1',
            SearchInSubject   => '1',
            SenderType        => 'system',
            TicketStateTypes  => 'new;open',
        },
        NewTicket => 2,
    },
);

for my $Test (@Tests) {

    my @Return;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => \$Test->{Email},
        );

        $Kernel::OM->Get('Config')->Set(
            Key   => 'PostMaster::PreFilterModule',
            Value => {
                '00-ExternalTicketNumberRecognition1' => {
                    %{ $Test->{JobConfig} }
                },
            },
        );

        @Return = $PostMasterObject->Run();
        @Return = @{ $Return[0] || [] };
    }
    $Self->Is(
        $Return[0] || 0,
        $Test->{NewTicket},
        "#Filter Run() - NewTicket",
    );
    $Self->True(
        $Return[1] || 0,
        "#Filter  Run() - NewTicket/TicketID",
    );
    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    for my $Key ( sort keys %{ $Test->{Check} } ) {
        $Self->IsDeeply(
            $Ticket{$Key},
            $Test->{Check}->{$Key},
            "#Filter Run() - $Key",
        );
    }
}

# set back values for prefilter config
$Kernel::OM->Get('Config')->Set(
    Key   => 'PostMaster::PreFilterModule',
    Value => \%Jobs,
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
