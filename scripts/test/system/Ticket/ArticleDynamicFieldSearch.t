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
my $ConfigObject       = $Kernel::OM->Get('Config');
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $BackendObject      = $Kernel::OM->Get('DynamicField::Backend');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# create local objects
my $RandomID = $Helper->GetRandomID();

$Self->Is(
    ref $BackendObject,
    'DynamicField::Backend',
    'Backend object was created successfuly',
);

# create a dynamic field
my $FieldID1 = $DynamicFieldObject->DynamicFieldAdd(
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
my $DFTicketConfig = $DynamicFieldObject->DynamicFieldGet(
    ID => $FieldID1,
);

push @DFConfig, $DFTicketConfig;

# create a dynamic fields

for my $Item ( 1 .. 2 ) {
    my $DynamicFieldID = $DynamicFieldObject->DynamicFieldAdd(
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

    my $DFArticleConfig = $DynamicFieldObject->DynamicFieldGet(
        ID => $DynamicFieldID,
    );

    push @DFConfig, $DFArticleConfig;

}

# tests for article search index modules
for my $Module (qw(StaticDB RuntimeDB)) {

    # Make sure that the TicketObject gets recreated for each loop.
    $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

    $ConfigObject->Set(
        Key   => 'Ticket::SearchIndexModule',
        Value => 'Ticket::ArticleSearchIndex::' . $Module,
    );

    my $TicketObject = $Kernel::OM->Get('Ticket');

    $Self->True(
        $TicketObject->isa( 'Ticket::ArticleSearchIndex::' . $Module ),
        "TicketObject loaded the correct backend",
    );

    my @TestTicketIDs;
    my @TicketIDs;
    my @Tickets;

    for my $Item ( 0 .. 1 ) {
        my $TicketID = $TicketObject->TicketCreate(
            Title        => "Ticket$RandomID",
            Queue        => 'Junk',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'closed',
            OrganisationID => '123465',
            ContactID    => 'customer@example.com',
            OwnerID      => 1,
            UserID       => 1,
        );

        push @TestTicketIDs, $TicketID;
        push @TicketIDs,     $TicketID;

        my %TicketData = $TicketObject->TicketGet(
            TicketID => $TicketID,
        );

        push @Tickets, \%TicketData;
    }

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DFConfig[0],
        ObjectID           => $TicketIDs[0],
        Value              => 'ticket1_field1',
        UserID             => 1,
    );

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DFConfig[0],
        ObjectID           => $TicketIDs[1],
        Value              => 'ticket2_field1',
        UserID             => 1,
    );

    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID       => $TicketIDs[0],
        Channels       => 'note',
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

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DFConfig[1],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle1_ticket1_article1',
        UserID             => 1,
    );

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DFConfig[2],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle2_ticket1_article1',
        UserID             => 1,
    );

    $ArticleID = $TicketObject->ArticleCreate(
        TicketID       => $TicketIDs[0],
        Channels       => 'note',
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

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DFConfig[1],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle1_ticket1_article2',
        UserID             => 1,
    );

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DFConfig[2],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle2_ticket1_article2',
        UserID             => 1,
    );

    $ArticleID = $TicketObject->ArticleCreate(
        TicketID       => $TicketIDs[1],
        Channels       => 'note',
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

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DFConfig[1],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle1_ticket2_article1',
        UserID             => 1,
    );

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DFConfig[2],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle2_ticket2_article1',
        UserID             => 1,
    );

    $ArticleID = $TicketObject->ArticleCreate(
        TicketID       => $TicketIDs[1],
        Channels       => 'note',
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

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DFConfig[1],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle1_ticket2_article2',
        UserID             => 1,
    );

    $BackendObject->ValueSet(
        DynamicFieldConfig => $DFConfig[2],
        ObjectID           => $ArticleID,
        Value              => 'fieldarticle2_ticket2_article2',
        UserID             => 1,
    );

    my %TicketIDsSearch = $TicketObject->TicketSearch(
        Result  => 'HASH',
        Limit   => 100,
        Filter  => {
            AND => [
                {
                    Field => 'Title',
                    Value => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle1$RandomID",
                    Value => 'fieldarticle1_ticket1_article1',
                    Operator => 'EQ',
                }
            ]
        },
        UserID     => 1,
        Permission => 'rw',
    );

    $Self->IsDeeply(
        \%TicketIDsSearch,
        { $TicketIDs[0] => $Tickets[0]->{TicketNumber} },
        "$Module - Search for one article field",
    );

    %TicketIDsSearch = $TicketObject->TicketSearch(
        Result  => 'HASH',
        Limit   => 100,
        Filter  => {
            AND => [
                {
                    Field => 'Title',
                    Value => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle1$RandomID",
                    Value => 'fieldarticle1_ticket1_article1',
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle2$RandomID",
                    Value => 'fieldarticle2_ticket1_article1',
                    Operator => 'EQ',
                }
            ]
        },
        UserID     => 1,
        Permission => 'rw',
    );

    $Self->IsDeeply(
        \%TicketIDsSearch,
        { $TicketIDs[0] => ( $Tickets[0]->{TicketNumber} ) },
        "$Module - Search for two article fields in one article",
    );

    %TicketIDsSearch = $TicketObject->TicketSearch(
        Result  => 'HASH',
        Limit   => 100,
        Filter  => {
            AND => [
                {
                    Field => 'Title',
                    Value => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle1$RandomID",
                    Value => 'fieldarticle1_ticket1_article1',
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle2$RandomID",
                    Value => 'fieldarticle2_ticket1_article2',
                    Operator => 'EQ',
                }
            ]
        },
        UserID     => 1,
        Permission => 'rw',
    );

    $Self->IsDeeply(
        \%TicketIDsSearch,
        {},
        "$Module - Search for two article fields in different articles",
    );

    %TicketIDsSearch = $TicketObject->TicketSearch(
        Result  => 'HASH',
        Limit   => 100,
        Filter  => {
            AND => [
                {
                    Field => 'Title',
                    Value => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle1$RandomID",
                    Value => 'fieldarticle1_ticket*_article1',
                    Operator => 'LIKE',
                },
                {
                    Field => "DynamicField_DFTArticle2$RandomID",
                    Value => 'fieldarticle2_ticket*_article1',
                    Operator => 'LIKE',
                }
            ]
        },
        UserID     => 1,
        Permission => 'rw',
    );

    $Self->IsDeeply(
        \%TicketIDsSearch,
        {
            $TicketIDs[0] => ( $Tickets[0]->{TicketNumber} ),
            $TicketIDs[1] => ( $Tickets[1]->{TicketNumber} ),
        },
        "$Module - Search for two article fields in different tickets, wildcard",
    );

    %TicketIDsSearch = $TicketObject->TicketSearch(
        Result  => 'HASH',
        Limit   => 100,
        Filter  => {
            AND => [
                {
                    Field => 'Title',
                    Value => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle1$RandomID",
                    Value => [ 'fieldarticle1_ticket1_article1', 'fieldarticle1_ticket2_article1' ],
                    Operator => 'IN',
                },
                {
                    Field => "DynamicField_DFTArticle2$RandomID",
                    Value => [ 'fieldarticle2_ticket1_article1', 'fieldarticle2_ticket2_article1' ],
                    Operator => 'IN',
                }
            ]
        },
        UserID     => 1,
        Permission => 'rw',
    );

    $Self->IsDeeply(
        \%TicketIDsSearch,
        {
            $TicketIDs[0] => ( $Tickets[0]->{TicketNumber} ),
            $TicketIDs[1] => ( $Tickets[1]->{TicketNumber} ),
        },
        "$Module - Search for two article fields in different tickets, hardcoded",
    );

    my @TicketIDsSearch = $TicketObject->TicketSearch(
        Result  => 'ARRAY',
        Limit   => 100,
        Filter  => {
            AND => [
                {
                    Field => 'Title',
                    Value => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle1$RandomID",
                    Value => [ 'fieldarticle1_ticket1_article1', 'fieldarticle1_ticket2_article1' ],
                    Operator => 'IN',
                },
                {
                    Field => "DynamicField_DFTArticle2$RandomID",
                    Value => [ 'fieldarticle2_ticket1_article1', 'fieldarticle2_ticket2_article1' ],
                    Operator => 'IN',
                }
            ]
        },
        Sort       => [
            {
                Field => "DynamicField_DFTArticle2$RandomID",
                Direction => 'ascending',
            }
        ],
        UserID     => 1,
        Permission => 'rw',
    );

    $Self->IsDeeply(
        \@TicketIDsSearch,
        [ $TicketIDs[0], $TicketIDs[1], ],
        "$Module - Sort by search field, ASC",
    );

    @TicketIDsSearch = $TicketObject->TicketSearch(
        Result  => 'ARRAY',
        Limit   => 100,
        Filter  => {
            AND => [
                {
                    Field => 'Title',
                    Value => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle1$RandomID",
                    Value => [ 'fieldarticle1_ticket1_article1', 'fieldarticle1_ticket2_article1' ],
                    Operator => 'IN',
                },
                {
                    Field => "DynamicField_DFTArticle2$RandomID",
                    Value => [ 'fieldarticle2_ticket1_article1', 'fieldarticle2_ticket2_article1' ],
                    Operator => 'IN',
                }
            ]
        },
        Sort       => [
            {
                Field => "DynamicField_DFTArticle2$RandomID",
                Direction => 'descending',
            }
        ],
        UserID     => 1,
        Permission => 'rw',
    );

    $Self->IsDeeply(
        \@TicketIDsSearch,
        [ $TicketIDs[1], $TicketIDs[0], ],
        "$Module - Sort by search field, DESC",
    );

    @TicketIDsSearch = $TicketObject->TicketSearch(
        Result  => 'ARRAY',
        Limit   => 100,
        Filter  => {
            AND => [
                {
                    Field => 'Title',
                    Value => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle1$RandomID",
                    Value => [ 'fieldarticle1_ticket1_article1', 'fieldarticle1_ticket2_article1' ],
                    Operator => 'EQ',
                },
            ]
        },
        Sort       => [
            {
                Field => "DynamicField_DFTArticle2$RandomID",
                Direction => 'ascending',
            }
        ],
        UserID     => 1,
        Permission => 'rw',
    );

    $Self->IsDeeply(
        \@TicketIDsSearch,
        [ $TicketIDs[0], $TicketIDs[1], ],
        "$Module - Sort by another field, ASC",
    );

    @TicketIDsSearch = $TicketObject->TicketSearch(
        Result  => 'ARRAY',
        Limit   => 100,
        Filter  => {
            AND => [
                {
                    Field => 'Title',
                    Value => "Ticket$RandomID",
                    Operator => 'EQ',
                },
                {
                    Field => "DynamicField_DFTArticle1$RandomID",
                    Value => [ 'fieldarticle1_ticket1_article1', 'fieldarticle1_ticket2_article1' ],
                    Operator => 'EQ',
                },
            ]
        },
        Sort       => [
            {
                Field => "DynamicField_DFTArticle2$RandomID",
                Direction => 'descending',
            }
        ],
        UserID     => 1,
        Permission => 'rw',
    );

    $Self->IsDeeply(
        \@TicketIDsSearch,
        [ $TicketIDs[1], $TicketIDs[0], ],
        "$Module - Sort by another field, DESC",
    );

    for my $TicketID (@TestTicketIDs) {

        # the ticket is no longer needed
        $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => 1,
        );
    }
}

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
