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

# This unit test checks whether the fix for KIX2018-15345 is still available.

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# get objectsearch object
my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

# begin transaction on database
$Helper->BeginWork();

## prepare test data ##
# create dynamic field for unit test
my $DynamicFieldID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    InternalField => 0,
    Name          => 'UnitTest',
    Label         => 'UnitTest',
    FieldType     => 'Text',
    ObjectType    => 'Article',
    Config        => {},
    ValidID       => 1,
    UserID        => 1,
);
$Self->True(
    $DynamicFieldID,
    'Created dynamic field for UnitTest'
);
my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
    ID => $DynamicFieldID
);

# create Ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => $Helper->GetRandomID(),
    QueueID        => 1,
    Lock           => 'unlock',
    PriorityID     => 1,
    StateID        => 1,
    TypeID         => 1,
    OrganisationID => 1,
    ContactID      => 1,
    OwnerID        => 1,
    ResponsibleID  => 1,
    UserID         => 1
);
$Self->True(
    $TicketID,
    'Created ticket'
);

# create two Articles
my $ArticleID1 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID         => $TicketID,
    ChannelID        => 1,
    CustomerVisible  => 1,
    SenderType       => 'agent',
    Subject          => 'first article of ticket',
    Body             => 'object search test',
    Charset          => 'utf-8',
    MimeType         => 'text/plain',
    HistoryType      => 'AddNote',
    HistoryComment   => 'object search test',
    UserID           => 1
);
$Self->True(
    $ArticleID1,
    'Created first article of ticket'
);

my $ArticleID2 = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID         => $TicketID,
    ChannelID        => 1,
    CustomerVisible  => 1,
    SenderType       => 'agent',
    Subject          => 'second article of ticket',
    Body             => 'object search test',
    Charset          => 'utf-8',
    MimeType         => 'text/plain',
    HistoryType      => 'AddNote',
    HistoryComment   => 'object search test',
    UserID           => 1
);
$Self->True(
    $ArticleID2,
    'Created second article of ticket'
);

# set ArticleDF for only second Article with specific value
my $ValueSet = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $ArticleID2,
    Value              => 'Test',
    UserID             => 1,
);
$Self->True(
    $ValueSet,
    'Dynamic field value set for second article of ticket'
);

## execute test search ##
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Ticket by ArticleID and ArticleDF. ArticleID not corresponding to ArticleDF',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'EQ',
                    Value    => $ArticleID1
                },
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => 'Test'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Ticket by ArticleID and ArticleDF. ArticleID corresponding to ArticleDF',
        Search   => {
            'AND' => [
                {
                    Field    => 'ArticleID',
                    Operator => 'EQ',
                    Value    => $ArticleID2
                },
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EQ',
                    Value    => 'Test'
                }
            ]
        },
        Expected => [
            $TicketID
        ]
    },
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Ticket',
        Result     => 'ARRAY',
        Search     => $Test->{Search},
        UserType   => 'Agent',
        UserID     => 1,
    );
    $Self->IsDeeply(
        \@Result,
        $Test->{Expected},
        $Test->{Name}
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
