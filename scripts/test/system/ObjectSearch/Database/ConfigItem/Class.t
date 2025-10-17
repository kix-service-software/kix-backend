# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ConfigItem::Class';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $AttributeModule ) );

# create backend object
my $AttributeObject = $AttributeModule->new( %{ $Self } );
$Self->Is(
    ref( $AttributeObject ),
    $AttributeModule,
    'Attribute object has correct module ref'
);

# check supported methods
for my $Method ( qw(GetSupportedAttributes Search Sort) ) {
    $Self->True(
        $AttributeObject->can($Method),
        'Attribute object can "' . $Method . '"'
    );
}

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList,
    {
        ClassID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        ClassIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','GT','GTE','LT','LTE'],
            ValueType    => 'NUMERIC'
        },
        Class => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ', 'NE', 'IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
        }
    },
    'GetSupportedAttributes provides expected data'
);

# check Search
my @SearchTests = (
    {
        Name         => 'Search: undef search',
        Search       => undef,
        Expected     => undef
    },
    {
        Name         => 'Search: Value undef',
        Search       => {
            Field    => 'ClassID',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'ClassID',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'ClassID',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'ClassID',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field ClassID / Operator EQ',
        Search       => {
            Field    => 'ClassID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassID / Operator NE',
        Search       => {
            Field    => 'ClassID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassID / Operator IN',
        Search       => {
            Field    => 'ClassID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassID / Operator !IN',
        Search       => {
            Field    => 'ClassID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassID / Operator LT',
        Search       => {
            Field    => 'ClassID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassID / Operator GT',
        Search       => {
            Field    => 'ClassID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassID / Operator LTE',
        Search       => {
            Field    => 'ClassID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassID / Operator GTE',
        Search       => {
            Field    => 'ClassID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassIDs / Operator EQ',
        Search       => {
            Field    => 'ClassIDs',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassIDs / Operator NE',
        Search       => {
            Field    => 'ClassIDs',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassIDs / Operator IN',
        Search       => {
            Field    => 'ClassIDs',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassIDs / Operator !IN',
        Search       => {
            Field    => 'ClassIDs',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassIDs / Operator LT',
        Search       => {
            Field    => 'ClassIDs',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassIDs / Operator GT',
        Search       => {
            Field    => 'ClassIDs',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassIDs / Operator LTE',
        Search       => {
            Field    => 'ClassIDs',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ClassIDs / Operator GTE',
        Search       => {
            Field    => 'ClassIDs',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Join'  => [],
            'Where' => [
                'ci.class_id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator EQ',
        Search       => {
            Field    => 'Class',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\''
            ],
            'Where' => [
                'cic.name = \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator NE',
        Search       => {
            Field    => 'Class',
            Operator => 'NE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\''
            ],
            'Where' => [
                'cic.name != \'Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator IN',
        Search       => {
            Field    => 'Class',
            Operator => 'IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\''
            ],
            'Where' => [
                'cic.name IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator !IN',
        Search       => {
            Field    => 'Class',
            Operator => '!IN',
            Value    => ['Test']
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\''
            ],
            'Where' => [
                'cic.name NOT IN (\'Test\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator STARTSWITH',
        Search       => {
            Field    => 'Class',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\''
            ],
            'Where' => [
                'cic.name LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator ENDSWITH',
        Search       => {
            Field    => 'Class',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\''
            ],
            'Where' => [
                'cic.name LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator CONTAINS',
        Search       => {
            Field    => 'Class',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\''
            ],
            'Where' => [
                'cic.name LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Class / Operator LIKE',
        Search       => {
            Field    => 'Class',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\''
            ],
            'Where' => [
                'cic.name LIKE \'Test\''
            ]
        }
    }
);
for my $Test ( @SearchTests ) {
    my $Result = $AttributeObject->Search(
        Search       => $Test->{Search},
        BoolOperator => 'AND',
        UserID       => 1,
        Silent       => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

# check Sort
my @SortTests = (
    {
        Name      => 'Sort: Attribute undef',
        Attribute => undef,
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute invalid',
        Attribute => 'Test',
        Expected  => undef
    },
    {
        Name      => 'Sort: Attribute "ClassID"',
        Attribute => 'ClassID',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'ci.class_id'
            ],
            'Select'  => [
                'ci.class_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "ClassIDs"',
        Attribute => 'ClassIDs',
        Expected  => {
            'Join'    => [],
            'OrderBy' => [
                'ci.class_id'
            ],
            'Select'  => [
                'ci.class_id'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "Class"',
        Attribute => 'Class',
        Expected  => {
            'Join'    => [
                'INNER JOIN general_catalog cic ON cic.id = ci.class_id AND cic.general_catalog_class = \'ITSM::ConfigItem::Class\'',
                'LEFT OUTER JOIN translation_pattern tlp0 ON tlp0.value = cic.name',
                'LEFT OUTER JOIN translation_language tl0 ON tl0.pattern_id = tlp0.id AND tl0.language = \'en\''
            ],
            'OrderBy' => [
                'TranslateClass'
            ],
            'Select'  => [
                'LOWER(COALESCE(tl0.value, cic.name)) AS TranslateClass'
            ]
        }
    }
);
for my $Test ( @SortTests ) {
    my $Result = $AttributeObject->Sort(
        Attribute => $Test->{Attribute},
        Language  => 'en',
        Silent    => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name}
    );
}

### Integration Test ###
# discard current object search object
$Kernel::OM->ObjectsDiscard(
    Objects => ['ObjectSearch'],
);

# make sure config 'ObjectSearch::Backend' is set to Module 'ObjectSearch::Database'
$Kernel::OM->Get('Config')->Set(
    Key   => 'ObjectSearch::Backend',
    Value => {
        Module => 'ObjectSearch::Database',
    }
);

# get objectsearch object
my $ObjectSearch = $Kernel::OM->Get('ObjectSearch');

# begin transaction on database
$Helper->BeginWork();

# load translations for given language
my @Translations = $Kernel::OM->Get('Translation')->TranslationList();
my %TranslationsDE;
for my $Translation ( @Translations ) {
    $TranslationsDE{ $Translation->{Pattern} } = $Translation->{Languages}->{'de'};
}

# prepare class mapping
my $ItemDataRef1 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::Class',
    Name          => 'Building',
    NoPreferences => 1
);
my $ClassID1   = $ItemDataRef1->{ItemID};
my $ClassName1 = $ItemDataRef1->{Name};
$Self->True(
    $ClassID1,
    'Class 1 has id'
);
$Self->Is(
    $ClassName1,
    'Building',
    'Class 1 has expected name'
);
$Self->Is(
    $TranslationsDE{ $ClassName1 },
    'Gebäude',
    'Class 1 has expected translation (de)'
);
my $ItemDataRef2 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::Class',
    Name          => 'Location',
    NoPreferences => 1
);
my $ClassID2   = $ItemDataRef2->{ItemID};
my $ClassName2 = $ItemDataRef2->{Name};
$Self->True(
    $ClassID2,
    'Class 2 has id'
);
$Self->Is(
    $ClassName2,
    'Location',
    'Class 2 has expected name'
);
$Self->Is(
    $TranslationsDE{ $ClassName2 },
    'Standort',
    'Class 2 has expected translation (de)'
);
my $ItemDataRef3 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class         => 'ITSM::ConfigItem::Class',
    Name          => 'Network',
    NoPreferences => 1
);
my $ClassID3   = $ItemDataRef3->{ItemID};
my $ClassName3 = $ItemDataRef3->{Name};
$Self->True(
    $ClassID3,
    'Class 3 has id'
);
$Self->Is(
    $ClassName3,
    'Network',
    'Class 3 has expected name'
);
$Self->Is(
    $TranslationsDE{ $ClassName3 },
    'Netzwerk',
    'Class 3 has expected translation (de)'
);

## prepare test assets ##
# first asset
my $ConfigItemID1 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassID1,
    UserID  => 1,
);
$Self->True(
    $ConfigItemID1,
    'Created first asset'
);
# second asset
my $ConfigItemID2 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassID2,
    UserID  => 1,
);
$Self->True(
    $ConfigItemID2,
    'Created second asset'
);
# third asset
my $ConfigItemID3 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassID3,
    UserID  => 1,
);
$Self->True(
    $ConfigItemID3,
    'Created third asset'
);

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['ITSMConfigItem'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field ClassID / Operator EQ / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassID',
                    Operator => 'EQ',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ClassID / Operator NE / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassID',
                    Operator => 'NE',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ClassID / Operator IN / Value [$ClassID1,$ClassID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassID',
                    Operator => 'IN',
                    Value    => [$ClassID1,$ClassID3]
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field ClassID / Operator !IN / Value [$ClassID1,$ClassID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassID',
                    Operator => '!IN',
                    Value    => [$ClassID1,$ClassID3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ClassID / Operator LT / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassID',
                    Operator => 'LT',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field ClassID / Operator GT / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassID',
                    Operator => 'GT',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ClassID / Operator LTE / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassID',
                    Operator => 'LTE',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ClassID / Operator GTE / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassID',
                    Operator => 'GTE',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ClassIDs / Operator EQ / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassIDs',
                    Operator => 'EQ',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ClassIDs / Operator NE / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassIDs',
                    Operator => 'NE',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ClassIDs / Operator IN / Value [$ClassID1,$ClassID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassIDs',
                    Operator => 'IN',
                    Value    => [$ClassID1,$ClassID3]
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field ClassIDs / Operator !IN / Value [$ClassID1,$ClassID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassIDs',
                    Operator => '!IN',
                    Value    => [$ClassID1,$ClassID3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ClassIDs / Operator LT / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassIDs',
                    Operator => 'LT',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field ClassIDs / Operator GT / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassIDs',
                    Operator => 'GT',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field ClassIDs / Operator LTE / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassIDs',
                    Operator => 'LTE',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field ClassIDs / Operator GTE / Value $ClassID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ClassIDs',
                    Operator => 'GTE',
                    Value    => $ClassID2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator EQ / Value $ClassName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'EQ',
                    Value    => $ClassName2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Class / Operator NE / Value $ClassName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'NE',
                    Value    => $ClassName2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator IN / Value [$ClassName1,$ClassName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'IN',
                    Value    => [$ClassName1,$ClassName3]
                }
            ]
        },
        Expected => [$ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator !IN / Value [$ClassName1,$ClassName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => '!IN',
                    Value    => [$ClassName1,$ClassName3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Class / Operator STARTSWITH / Value $ClassName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'STARTSWITH',
                    Value    => $ClassName2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Class / Operator STARTSWITH / Value substr($ClassName2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'STARTSWITH',
                    Value    => substr($ClassName2,0,4)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Class / Operator ENDSWITH / Value $ClassName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'ENDSWITH',
                    Value    => $ClassName2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Class / Operator ENDSWITH / Value substr($ClassName2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'ENDSWITH',
                    Value    => substr($ClassName2,-5)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Class / Operator CONTAINS / Value $ClassName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'CONTAINS',
                    Value    => $ClassName2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field Class / Operator CONTAINS / Value substr($ClassName3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'CONTAINS',
                    Value    => substr($ClassName3,2,-2)
                }
            ]
        },
        Expected => [$ConfigItemID3]
    },
    {
        Name     => 'Search: Field Class / Operator LIKE / Value $ClassName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Class',
                    Operator => 'LIKE',
                    Value    => $ClassName2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ConfigItem',
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

# test Sort
my @IntegrationSortTests = (
    {
        Name     => 'Sort: Field ClassID',
        Sort     => [
            {
                Field => 'ClassID'
            }
        ],
        Expected => [$ConfigItemID2, $ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ClassID / Direction ascending',
        Sort     => [
            {
                Field     => 'ClassID',
                Direction => 'ascending'
            }
        ],
        Expected => [$ConfigItemID2, $ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ClassID / Direction descending',
        Sort     => [
            {
                Field     => 'ClassID',
                Direction => 'descending'
            }
        ],
        Expected => [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field ClassIDs',
        Sort     => [
            {
                Field => 'ClassIDs'
            }
        ],
        Expected => [$ConfigItemID2, $ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ClassIDs / Direction ascending',
        Sort     => [
            {
                Field     => 'ClassIDs',
                Direction => 'ascending'
            }
        ],
        Expected => [$ConfigItemID2, $ConfigItemID1, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field ClassIDs / Direction descending',
        Sort     => [
            {
                Field     => 'ClassIDs',
                Direction => 'descending'
            }
        ],
        Expected => [$ConfigItemID3, $ConfigItemID1, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field Class',
        Sort     => [
            {
                Field => 'Class'
            }
        ],
        Expected => [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field Class / Direction ascending',
        Sort     => [
            {
                Field     => 'Class',
                Direction => 'ascending'
            }
        ],
        Expected => [$ConfigItemID1, $ConfigItemID2, $ConfigItemID3]
    },
    {
        Name     => 'Sort: Field Class / Direction descending',
        Sort     => [
            {
                Field     => 'Class',
                Direction => 'descending'
            }
        ],
        Expected => [$ConfigItemID3, $ConfigItemID2, $ConfigItemID1]
    },
    {
        Name     => 'Sort: Field Class / Language de',
        Sort     => [
            {
                Field => 'Class'
            }
        ],
        Language => 'de',
        Expected => [$ConfigItemID1, $ConfigItemID3, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field Class / Direction ascending / Language de',
        Sort     => [
            {
                Field     => 'Class',
                Direction => 'ascending'
            }
        ],
        Language => 'de',
        Expected => [$ConfigItemID1, $ConfigItemID3, $ConfigItemID2]
    },
    {
        Name     => 'Sort: Field Class / Direction descending / Language de',
        Sort     => [
            {
                Field     => 'Class',
                Direction => 'descending'
            }
        ],
        Language => 'de',
        Expected => [$ConfigItemID2, $ConfigItemID3, $ConfigItemID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'ConfigItem',
        Result     => 'ARRAY',
        Sort       => $Test->{Sort},
        Language   => $Test->{Language},
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
