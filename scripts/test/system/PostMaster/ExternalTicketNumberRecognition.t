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

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
my $TicketObject = $Kernel::OM->Get('Ticket');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# define needed variable
my $RandomID = $Helper->GetRandomID();
my %Jobs     = %{ $ConfigObject->Get('PostMaster::PreFilterModule') };

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
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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
            "DynamicField_$FieldName" => $ExternalTicketID,
        },
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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
            "DynamicField_$FieldName" => $ExternalTicketID,
        },
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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
            "DynamicField_$FieldName" => $ExternalTicketID,
        },
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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
            "DynamicField_$FieldName" => $ExternalTicketID,
        },
        JobConfig => {
            Channel           => 'note',
            DynamicFieldName  => $FieldName,
            FromAddressRegExp => '\\s*@example.com',
            Module            => 'PostMaster::Filter::ExternalTicketNumberRecognition',
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

    $ConfigObject->Set(
        Key   => 'PostMaster::PreFilterModule',
        Value => {},
    );

    $ConfigObject->Set(
        Key   => 'PostMaster::PreFilterModule',
        Value => {
            '00-ExternalTicketNumberRecognition1' => {
                %{ $Test->{JobConfig} }
            },
        },
    );

    my @Return;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => \$Test->{Email},
            Debug => 2,
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
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    for my $Key ( sort keys %{ $Test->{Check} } ) {
        $Self->Is(
            $Ticket{$Key},
            $Test->{Check}->{$Key},
            "#Filter Run() - $Key",
        );
    }
}

# set back values for prefilter config
$ConfigObject->Set(
    Key   => 'PostMaster::PreFilterModule',
    Value => \%Jobs,
);

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
