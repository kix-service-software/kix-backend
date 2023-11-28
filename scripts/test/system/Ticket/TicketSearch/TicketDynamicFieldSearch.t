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
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $BackendObject      = $Kernel::OM->Get('DynamicField::Backend');
my $TicketObject       = $Kernel::OM->Get('Ticket');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $RandomID = $Helper->GetRandomID();

$Self->Is(
    ref $BackendObject,
    'Kernel::System::DynamicField::Backend',
    'Backend object was created successfully',
);

# create dynamic field properties
my @DynamicFieldProperties = (
    {
        Name       => "DFT1$RandomID",
        FieldOrder => 9991,
        FieldType  => 'Text',
        Config     => {
            DefaultValue => 'Default',
        },
    },
    {
        Name       => "DFT2$RandomID",
        FieldOrder => 9992,
        FieldType  => 'Multiselect',
        Config     => {
            DefaultValue   => 'Default',
            PossibleValues => {
                ticket1_field2 => 'ticket1_field2',
                ticket2_field2 => 'ticket2_field2',
            },
        },
    },
    {
        Name       => "DFT3$RandomID",
        FieldOrder => 9993,
        FieldType  => 'DateTime',
        Config     => {
            DefaultValue => 'Default',
        },
    },
    {
        Name       => "DFT4$RandomID",
        FieldOrder => 9993,
        FieldType  => 'Text',
        Config     => {
            DefaultValue => 'Default',
        },
    },
    {
        Name       => "DFT5$RandomID",
        FieldOrder => 9995,
        FieldType  => 'Multiselect',
        Config     => {
            CountMax       => 3,
            DefaultValue   => [ 'ticket2_field5', 'ticket4_field5' ],
            PossibleValues => {
                ticket1_field5 => 'ticket1_field51',
                ticket2_field5 => 'ticket2_field52',
                ticket3_field5 => 'ticket2_field53',
                ticket4_field5 => 'ticket2_field54',
                ticket5_field5 => 'ticket2_field55',
            },
        },
    }
);

my @FieldConfig;

# create dynamic fields
for my $DynamicFieldProperties (@DynamicFieldProperties) {
    my $FieldID = $DynamicFieldObject->DynamicFieldAdd(
        %{$DynamicFieldProperties},
        Label      => 'Description',
        ObjectType => 'Ticket',
        ValidID    => 1,
        UserID     => 1,
        Reorder    => 0,
    );

    $Self->True(
        $FieldID,
        "DynamicField is created - $DynamicFieldProperties->{Name} ($FieldID)",
    );

    push @FieldConfig, $DynamicFieldObject->DynamicFieldGet(
        ID => $FieldID,
    );
}

my @TicketData;
for ( 1 .. 2 ) {
    my $TicketID = $TicketObject->TicketCreate(
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

    $Self->True(
        $TicketID,
        "Ticket is created - $TicketID",
    );

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $TicketID,
    );

    push @TicketData, {
        TicketID     => $TicketID,
        TicketNumber => $Ticket{TicketNumber},
        }
}

my @Values = (
    {
        DynamicFieldConfig => $FieldConfig[0],
        ObjectID           => $TicketData[0]{TicketID},
        Value              => 'ticket1_field1',
    },
    {
        DynamicFieldConfig => $FieldConfig[1],
        ObjectID           => $TicketData[0]{TicketID},
        Value              => 'ticket1_field2',
    },
    {
        DynamicFieldConfig => $FieldConfig[2],
        ObjectID           => $TicketData[0]{TicketID},
        Value              => '2001-01-01 01:01:01',
    },
    {
        DynamicFieldConfig => $FieldConfig[3],
        ObjectID           => $TicketData[0]{TicketID},
        Value              => '0',
    },
    {
        DynamicFieldConfig => $FieldConfig[4],
        ObjectID           => $TicketData[0]{TicketID},
        Value              => ['ticket1_field5'],
        UserID             => 1,

    },
    {
        DynamicFieldConfig => $FieldConfig[0],
        ObjectID           => $TicketData[1]{TicketID},
        Value              => 'ticket2_field1',

    },
    {
        DynamicFieldConfig => $FieldConfig[1],
        ObjectID           => $TicketData[1]{TicketID},
        Value              => 'ticket2_field2',
    },
    {
        DynamicFieldConfig => $FieldConfig[2],
        ObjectID           => $TicketData[1]{TicketID},
        Value              => '2011-11-11 11:11:11',
    },
    {
        DynamicFieldConfig => $FieldConfig[3],
        ObjectID           => $TicketData[1]{TicketID},
        Value              => '1',
    },
    {
        DynamicFieldConfig => $FieldConfig[4],
        ObjectID           => $TicketData[1]{TicketID},
        Value              => [
            'ticket1_field5',
            'ticket2_field5',
            'ticket4_field5',
        ],
    },
);

for my $Value (@Values) {
    $BackendObject->ValueSet(
        DynamicFieldConfig => $Value->{DynamicFieldConfig},
        ObjectID           => $Value->{ObjectID},
        Value              => $Value->{Value},
        UserID             => 1,
    );
}

my %TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    { $TicketData[0]{TicketID} => $TicketData[0]{TicketNumber} },
    'Search for one field',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    { $TicketData[0]{TicketID} => $TicketData[0]{TicketNumber} },
    'Search for one field',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket1_field2',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    { $TicketData[0]{TicketID} => $TicketData[0]{TicketNumber} },
    'Search for two fields',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1_nonexisting',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket1_field2',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    {},
    'Search for two fields, wrong first value',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket1_field2_nonexisting',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
    Silent     => 1
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    {},
    'Search for two fields, wrong second value',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket%_field1',
                Operator => 'LIKE',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => ['ticket1_field2','ticket2_field2'],
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Silent     => 0
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    {
        $TicketData[0]{TicketID} => $TicketData[0]{TicketNumber},
        $TicketData[1]{TicketID} => $TicketData[1]{TicketNumber},
        ,
    },
    'Search for two fields, match two tickets',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket1_field2',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT3$RandomID",
                Value => '2001-01-01 01:01:01',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT4$RandomID",
                Value => '0',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT5$RandomID",
                Value => 'ticket1_field5',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    { $TicketData[0]{TicketID} => $TicketData[0]{TicketNumber} },
    'Search for five fields',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket1_field2',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT3$RandomID",
                Value => '2001-01-01 01:01:01',
                Operator => 'GTE',
            },
            {
                Field => "DynamicField_DFT3$RandomID",
                Value => '2001-01-01 01:01:01',
                Operator => 'LTE',
            },
            {
                Field => "DynamicField_DFT4$RandomID",
                Value => '0',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT5$RandomID",
                Value => 'ticket1_field5',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    { $TicketData[0]{TicketID} => $TicketData[0]{TicketNumber} },
    'Search for five fields, two operators with equals',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket1_field2',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT3$RandomID",
                Value => '2001-01-01 01:01:00',
                Operator => 'GT',
            },
            {
                Field => "DynamicField_DFT3$RandomID",
                Value => '2001-01-01 01:01:02',
                Operator => 'LT',
            },
            {
                Field => "DynamicField_DFT4$RandomID",
                Value => '0',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT5$RandomID",
                Value => 'ticket1_field5',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    { $TicketData[0]{TicketID} => $TicketData[0]{TicketNumber} },
    'Search for five fields, two operators without equals',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket1_field2',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT3$RandomID",
                Value => '2001-01-01 01:01:01',
                Operator => 'GT',
            },
            {
                Field => "DynamicField_DFT3$RandomID",
                Value => '2001-01-01 01:01:01',
                Operator => 'LT',
            },
            {
                Field => "DynamicField_DFT4$RandomID",
                Value => '0',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT5$RandomID",
                Value => 'ticket1_field5',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    {},
    'Search for five fields, two operators without equals (no match)',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket1_field2',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT3$RandomID",
                Value => '2002-01-01 01:01:01',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT4$RandomID",
                Value => '0',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT5$RandomID",
                Value => 'ticket1_field5',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    {},
    'Search for five fields, wrong third value',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket1_field2',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT3$RandomID",
                Value => '2001-01-01 01:01:01',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT4$RandomID",
                Value => '1',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT5$RandomID",
                Value => 'ticket1_field5',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    {},
    'Search for five fields, wrong fourth value',
);

%TicketIDsSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'HASH',
    Limit      => 100,
    Search  => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket1_field1',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket1_field2',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT3$RandomID",
                Value => '2001-01-01 01:01:01',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT4$RandomID",
                Value => '0',
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT5$RandomID",
                Value => 'ticket1000_field5',
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
    Silent     => 1
);

$Self->IsDeeply(
    \%TicketIDsSearch,
    {},
    'Search for five fields, wrong fifth value',
);

my @TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket%_field1',
                Operator => 'LIKE',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket%_field2',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT1$RandomID",
            Direction => 'ascending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[0]{TicketID}, $TicketData[1]{TicketID}, ],
    'Search for two fields, match two tickets, sort for search field, ASC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT1$RandomID",
                Value => 'ticket%_field1',
                Operator => 'LIKE',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket%_field2',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT1$RandomID",
            Direction => 'descending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[1]{TicketID}, $TicketData[0]{TicketID}, ],
    'Search for two fields, match two tickets, sort for search field, DESC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket%_field2',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT1$RandomID",
            Direction => 'ascending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[0]{TicketID}, $TicketData[1]{TicketID}, ],
    'Search for field, match two tickets, sort for another field, ASC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket%_field2',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT1$RandomID",
            Direction => 'descending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[1]{TicketID}, $TicketData[0]{TicketID}, ],
    'Search for field, match two tickets, sort for another field, DESC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket%_field2',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT3$RandomID",
            Direction => 'ascending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[0]{TicketID}, $TicketData[1]{TicketID}, ],
    'Search for field, match two tickets, sort for date field, ASC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket%_field2',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT3$RandomID",
            Direction => 'descending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[1]{TicketID}, $TicketData[0]{TicketID}, ],
    'Search for field, match two tickets, sort for date field, DESC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket%_field2',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT4$RandomID",
            Direction => 'ascending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[0]{TicketID}, $TicketData[1]{TicketID}, ],
    'Search for field, match two tickets, sort for text (DFT4) field, ASC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT2$RandomID",
                Value => 'ticket%_field2',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT4$RandomID",
            Direction => 'descending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[1]{TicketID}, $TicketData[0]{TicketID}, ],
    'Search for field, match two tickets, sort for text (DFT4) field, DESC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT4$RandomID",
            Direction => 'ascending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[0]{TicketID}, $TicketData[1]{TicketID}, ],
    'Search for no field, sort for text (DFT4) field, ASC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT4$RandomID",
            Direction => 'descending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[1]{TicketID}, $TicketData[0]{TicketID}, ],
    'Search for no field, sort for text (DFT4) field, DESC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT5$RandomID",
                Value => 'ticket%_field5',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT1$RandomID",
            Direction => 'ascending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[0]{TicketID}, $TicketData[1]{TicketID}, ],
    'Search for field, match two tickets, sort for text field, ASC',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT5$RandomID",
                Value => 'ticket1_field5',
                Operator => 'LIKE',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT1$RandomID",
            Direction => 'descending',
        }
    ]
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[1]{TicketID}, $TicketData[0]{TicketID}, ],
    'Search for one value, match two ticket',
);

@TicketResultSearch = $Kernel::OM->Get('ObjectSearch')->Search(
    ObjectType => 'Ticket',
    UserType   => 'Agent',
    Result     => 'ARRAY',
    Limit      => 100,
    Search     => {
        AND => [
            {
                Field => 'Title',
                Value => "Ticket$RandomID",
                Operator => 'EQ',
            },
            {
                Field => "DynamicField_DFT5$RandomID",
                Value => ['ticket2_field5', 'ticket4_field5'],
                Operator => 'IN',
            }
        ]
    },
    UserID     => 1,
    Sort       => [
        {
            Field => "DynamicField_DFT1$RandomID",
            Direction => 'descending',
        }
    ],
);

$Self->IsDeeply(
    \@TicketResultSearch,
    [ $TicketData[1]{TicketID}, ],
    'Search for two values in a same field, match one ticket using IN operator',
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
