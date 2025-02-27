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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create local objects
my $RandomID = $Helper->GetRandomID();

$Self->Is(
    ref $Kernel::OM->Get('DynamicField::Backend'),
    'Kernel::System::DynamicField::Backend',
    'Backend object was created successfuly',
);

# create a dynamic field
my $FieldID1 = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    Name       => "DFT1$RandomID",
    Label      => 'Description',
    FieldOrder => 9991,
    FieldType  => 'Text',            # mandatory, selects the DF backend to use for this field
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue => 'Default',
    },
    ValidID => 1,
    UserID  => 1,
    Reorder => 0,
);

my @DFConfig;
my $DFTicketConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
    ID => $FieldID1,
);

push @DFConfig, $DFTicketConfig;

# create a dynamic fields

for my $Item ( 1 .. 2 ) {
    my $DynamicFieldID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name       => "DFTArticle$Item$RandomID",
        Label      => 'Description',
        FieldOrder => 9991,
        FieldType  => 'Text',                       # mandatory, selects the DF backend to use for this field
        ObjectType => 'Article',
        Config     => {
            DefaultValue => 'Default',
        },
        ValidID => 1,
        UserID  => 1,
        Reorder => 0,
    );

    my $DFArticleConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $DynamicFieldID,
    );

    push @DFConfig, $DFArticleConfig;
}

# tests for article search index modules
for my $Module (qw(StaticDB RuntimeDB)) {

    # Make sure that the TicketObject gets recreated for each loop.
    $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

    $Kernel::OM->Get('Config')->Set(
        Key   => 'Ticket::SearchIndexModule',
        Value => 'Kernel::System::Ticket::ArticleSearchIndex::' . $Module,
    );

    $Self->True(
        $Kernel::OM->Get('Ticket')->isa( 'Kernel::System::Ticket::ArticleSearchIndex::' . $Module ),
        "TicketObject loaded the correct backend",
    );

    my @TestTicketIDs;
    my @TicketIDs;
    my @Tickets;

    for my $Item ( 0 .. 1 ) {
        my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
            Title          => "Ticket$RandomID",
            Queue          => 'Junk',
            Lock           => 'unlock',
            Priority       => '3 normal',
            State          => 'closed',
            OrganisationID => '123465',
            ContactID      => 'customer@example.com',
            OwnerID        => 1,
            UserID         => 1,
        );

        push @TestTicketIDs, $TicketID;
        push @TicketIDs,     $TicketID;

        my %TicketData = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID => $TicketID,
        );

        push @Tickets, \%TicketData;
    }

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DFConfig[0],
        ObjectID           => $TicketIDs[0],
        Value              => 'ticket1_field1',
        UserID             => 1,
    );

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DFConfig[0],
        ObjectID           => $TicketIDs[1],
        Value              => 'ticket2_field1',
        UserID             => 1,
    );

    my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        TicketID       => $TicketIDs[0],
        Channel        => 'note',
        SenderType     => 'agent',
        From           => 'Some Agent <email@example.com>',
        To             => 'Some Customer <customer-a@example.com>',
        Subject        => 'some short description',
        Body           => 'ticket1_article1',
        ContentType    => 'text/plain; charset=ISO-8859-15',
        HistoryType    => 'OwnerUpdate',
        HistoryComment => 'Some free text!',
        UserID         => 1,
        NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
    );

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DFConfig[1],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle1_ticket1_article1',
        UserID             => 1,
    );

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DFConfig[2],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle2_ticket1_article1',
        UserID             => 1,
    );

    $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        TicketID       => $TicketIDs[0],
        Channel        => 'note',
        SenderType     => 'agent',
        From           => 'Some Agent <email@example.com>',
        To             => 'Some Customer <customer-a@example.com>',
        Subject        => 'some short description',
        Body           => 'ticket1_article2',
        ContentType    => 'text/plain; charset=ISO-8859-15',
        HistoryType    => 'OwnerUpdate',
        HistoryComment => 'Some free text!',
        UserID         => 1,
        NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
    );

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DFConfig[1],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle1_ticket1_article2',
        UserID             => 1,
    );

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DFConfig[2],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle2_ticket1_article2',
        UserID             => 1,
    );

    $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        TicketID       => $TicketIDs[1],
        Channel        => 'note',
        SenderType     => 'agent',
        From           => 'Some Agent <email@example.com>',
        To             => 'Some Customer <customer-a@example.com>',
        Subject        => 'some short description',
        Body           => 'ticket2_article1',
        ContentType    => 'text/plain; charset=ISO-8859-15',
        HistoryType    => 'OwnerUpdate',
        HistoryComment => 'Some free text!',
        UserID         => 1,
        NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
    );

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DFConfig[1],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle1_ticket2_article1',
        UserID             => 1,
    );

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DFConfig[2],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle2_ticket2_article1',
        UserID             => 1,
    );

    $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
        TicketID       => $TicketIDs[1],
        Channel        => 'note',
        SenderType     => 'agent',
        From           => 'Some Agent <email@example.com>',
        To             => 'Some Customer <customer-a@example.com>',
        Subject        => 'some short description',
        Body           => 'ticket2_article2',
        ContentType    => 'text/plain; charset=ISO-8859-15',
        HistoryType    => 'OwnerUpdate',
        HistoryComment => 'Some free text!',
        UserID         => 1,
        NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
    );

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DFConfig[1],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle1_ticket2_article2',
        UserID             => 1,
    );

    $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DFConfig[2],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle2_ticket2_article2',
        UserID             => 1,
    );

    # process event queue
    $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

    my %TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Result     => 'HASH',
        Limit      => 100,
        Search     => {
            AND => [
                {
                    Field    => 'Title',
                    Value    => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field    => "DynamicField_DFTArticle1$RandomID",
                    Value    => 'fieldarticle1_ticket1_article1',
                    Operator => 'EQ',
                }
            ]
        },
        UserType    => 'Agent',
        UserID      => 1,
    );

    $Self->IsDeeply(
        \%TicketIDsSearch,
        { $TicketIDs[0] => $Tickets[0]->{TicketNumber} },
        "$Module - Search for one article field",
    );

    %TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Result     => 'HASH',
        Limit      => 100,
        Search     => {
            AND => [
                {
                    Field    => 'Title',
                    Value    => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field    => "DynamicField_DFTArticle1$RandomID",
                    Value    => 'fieldarticle1_ticket1_article1',
                    Operator => 'EQ',
                },
                {
                    Field    => "DynamicField_DFTArticle2$RandomID",
                    Value    => 'fieldarticle2_ticket1_article1',
                    Operator => 'EQ',
                }
            ]
        },
        UserID      => 1,
        UserType    => 'Agent',
    );

    $Self->IsDeeply(
        \%TicketIDsSearch,
        { $TicketIDs[0] => ( $Tickets[0]->{TicketNumber} ) },
        "$Module - Search for two article fields in one article",
    );

    %TicketIDsSearch =  $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Result     => 'HASH',
        Limit      => 100,
        Search     => {
            AND => [
                {
                    Field    => 'Title',
                    Value    => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field    => "DynamicField_DFTArticle1$RandomID",
                    Value    => 'fieldarticle1_ticket1_article1',
                    Operator => 'EQ',
                },
                {
                    Field    => "DynamicField_DFTArticle2$RandomID",
                    Value    => 'fieldarticle2_ticket1_article2',
                    Operator => 'EQ',
                }
            ]
        },
        UserID     => 1,
        UserType   => 'Agent',
    );

    $Self->IsDeeply(
        \%TicketIDsSearch,
        {},
        "$Module - Search for two article fields in different articles",
    );

    %TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Result     => 'HASH',
        Limit      => 100,
        Search     => {
            AND => [
                {
                    Field    => 'Title',
                    Value    => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field    => "DynamicField_DFTArticle1$RandomID",
                    Value    => 'fieldarticle1_ticket*_article1',
                    Operator => 'LIKE',
                },
                {
                    Field    => "DynamicField_DFTArticle2$RandomID",
                    Value    => 'fieldarticle2_ticket*_article1',
                    Operator => 'LIKE',
                }
            ]
        },
        UserID     => 1,
        UserType   => 'Agent',
    );

    $Self->IsDeeply(
        \%TicketIDsSearch,
        {
            $TicketIDs[0] => ( $Tickets[0]->{TicketNumber} ),
            $TicketIDs[1] => ( $Tickets[1]->{TicketNumber} ),
        },
        "$Module - Search for two article fields in different tickets, wildcard",
    );

    %TicketIDsSearch =  $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Result     => 'HASH',
        Limit      => 100,
        Search     => {
            AND => [
                {
                    Field    => 'Title',
                    Value    => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field    => "DynamicField_DFTArticle1$RandomID",
                    Value    => [ 'fieldarticle1_ticket1_article1', 'fieldarticle1_ticket2_article1' ],
                    Operator => 'IN',
                },
                {
                    Field    => "DynamicField_DFTArticle2$RandomID",
                    Value    => [ 'fieldarticle2_ticket1_article1', 'fieldarticle2_ticket2_article1' ],
                    Operator => 'IN',
                }
            ]
        },
        UserID     => 1,
        UserType   => 'Agent',
    );

    $Self->IsDeeply(
        \%TicketIDsSearch,
        {
            $TicketIDs[0] => ( $Tickets[0]->{TicketNumber} ),
            $TicketIDs[1] => ( $Tickets[1]->{TicketNumber} ),
        },
        "$Module - Search for two article fields in different tickets, hardcoded",
    );

    for my $TicketID (@TestTicketIDs) {

        # the ticket is no longer needed
        $Kernel::OM->Get('Ticket')->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
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
