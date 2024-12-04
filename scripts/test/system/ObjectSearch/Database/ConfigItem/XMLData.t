# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::ConfigItem::XMLData';

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

# check GetSupportedAttributes before test attribute is created
my $AttributeListBefore = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeListBefore->{'CurrentVersion.Data.UnitTest'},
    undef,
    'GetSupportedAttributes provides expected data before creation of test attribute'
);

# begin transaction on database
$Helper->BeginWork();

# add class for unit test
my $Class   = 'UnitTest';
my $ClassID = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'ITSM::ConfigItem::Class',
    Name    => $Class,
    ValidID => 1,
    UserID  => 1,
);
my $DefinitionID = $Kernel::OM->Get('ITSMConfigItem')->DefinitionAdd(
    ClassID    => $ClassID,
    Definition => <<'END',
[
    {
        Key             => 'NotSearchable',
        Name            => 'NotSearchable',
        Searchable      => 0,
        CustomerVisible => 0,
        Input           => {
            Type      => 'Text',
            MaxLength => 50,
        },
        Sub => [
            {
                Key             => 'UnitTest',
                Name            => 'UnitTest',
                Searchable      => 1,
                CustomerVisible => 0,
                Input           => {
                    Type      => 'Text',
                    MaxLength => 50
                }
            }
        ]
    }
]
END
    UserID     => 1
);

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList->{'CurrentVersion.Data.NotSearchable'},
    {
        IsSearchable => 0,
        IsSortable   => 0,
        Operators    => [],
        Class        => [ $Class ],
        ClassID      => [ $ClassID ]
    },
    'GetSupportedAttributes provides expected data for not searchable attribute'
);
$Self->IsDeeply(
    $AttributeList->{'CurrentVersion.Data.NotSearchable.UnitTest'},
    {
        IsSearchable => 1,
        IsSortable   => 0,
        Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE','ENDSWITH','STARTSWITH','CONTAINS','LIKE'],
        Class        => [ $Class ],
        ClassID      => [ $ClassID ]
    },
    'GetSupportedAttributes provides expected data for searchable sub attribute'
);

# backup backend of db
my $BackupDBBackend = $Kernel::OM->Get('DB')->{Backend};

# run test for database type postgresql and mysql to check CAST
for my $DatabaseType ( qw( postgresql mysql ) ) {

    # overwrite backend of db object
    my $GenericModule = $Kernel::OM->GetModuleFor('DB::' . $DatabaseType);
    if ( !$Kernel::OM->Get('Main')->Require($GenericModule) ) {
        $Self->False(
            1,
            'Unable to require module for database type ' . $DatabaseType
        );
        next;
    }
    $Kernel::OM->Get('DB')->{Backend} = $GenericModule->new( %{$Kernel::OM->Get('DB')} );
    $Kernel::OM->Get('DB')->{Backend}->LoadPreferences();

    $Self->Is(
        ref( $Kernel::OM->Get('DB')->{Backend} ),
        'Kernel::System::DB::' . $DatabaseType,
        'DatabaseType ' . $DatabaseType . ' / Backend'
    );

    my $QuoteSingle   = '';
    my $DBQuoteSingle = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSingle');
    if ( $DBQuoteSingle ) {
        $QuoteSingle = $DBQuoteSingle;
    }
    if ( $DatabaseType eq 'mysql' ) {
        $Self->Is(
            $QuoteSingle,
            '\\',
            'DatabaseType ' . $DatabaseType . ' / QuoteSingle'
        );
    }
    else {
        $Self->Is(
            $QuoteSingle,
            '\'',
            'DatabaseType ' . $DatabaseType . ' / QuoteSingle'
        );
    }

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
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'EQ',
                Value    => undef

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
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => undef,
                Value    => '1'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: Operator invalid',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'Test',
                Value    => '1'
            },
            Expected     => undef
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator EQ',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value = \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator EQ / Value empty string',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'EQ',
                Value    => ''
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    '(xst_left0.xml_content_value = \'\' OR xst_left0.xml_content_value IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator NE',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'NE',
                Value    => 'Test'
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    '(xst_left0.xml_content_value != \'Test\' OR xst_left0.xml_content_value IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator NE / Value empty string',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'NE',
                Value    => ''
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value != \'\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator IN',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value IN (\'Test\')'
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator !IN',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => '!IN',
                Value    => ['Test']
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value NOT IN (\'Test\')'
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LT',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'LT',
                Value    => 'Test'
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value < \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LTE',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'LTE',
                Value    => 'Test'
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value <= \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator GT',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'GT',
                Value    => 'Test'
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value > \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator GTE',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'GTE',
                Value    => 'Test'
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value >= \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator STARTSWITH',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value LIKE \'Test%\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator ENDSWITH',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value LIKE \'%Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator CONTAINS',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value LIKE \'%Test%\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LIKE',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Expected     => {
                'Join'  => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value LIKE \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator EQ / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'EQ',
                Value    => 'Test'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value = \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator EQ / PreviousVersionSearch / Value empty string',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'EQ',
                Value    => ''
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    '(xst_left0.xml_content_value = \'\' OR xst_left0.xml_content_value IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator NE / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'NE',
                Value    => 'Test'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    '(xst_left0.xml_content_value != \'Test\' OR xst_left0.xml_content_value IS NULL)'
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator NE / PreviousVersionSearch / Value empty string',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'NE',
                Value    => ''
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value != \'\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator IN / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'IN',
                Value    => ['Test']
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value IN (\'Test\')'
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator !IN / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => '!IN',
                Value    => ['Test']
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value NOT IN (\'Test\')'
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LT / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'LT',
                Value    => 'Test'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value < \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LTE / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'LTE',
                Value    => 'Test'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value <= \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator GT / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'GT',
                Value    => 'Test'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value > \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator GTE / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'GTE',
                Value    => 'Test'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value >= \'Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator STARTSWITH / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'STARTSWITH',
                Value    => 'Test'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value LIKE \'Test%\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator ENDSWITH / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'ENDSWITH',
                Value    => 'Test'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value LIKE \'%Test\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator CONTAINS / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'CONTAINS',
                Value    => 'Test'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value LIKE \'%Test%\''
                ]
            }
        },
        {
            Name         => 'Search: valid search / Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LIKE / PreviousVersionSearch',
            Search       => {
                Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                Operator => 'LIKE',
                Value    => 'Test'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON xst_left0.xml_key = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'NotSearchable' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'UnitTest' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\''
                ],
                'Where' => [
                    'xst_left0.xml_content_value LIKE \'Test\''
                ]
            }
        }
    );
    for my $Test ( @SearchTests ) {
        my $Result = $AttributeObject->Search(
            Search       => $Test->{Search},
            Flags        => $Test->{Flags},
            BoolOperator => 'AND',
            UserID       => 1,
            Silent       => defined( $Test->{Expected} ) ? 0 : 1
        );
        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            'DatabaseType ' . $DatabaseType . ' / ' . $Test->{Name}
        );
    }
}

# restore backend of db
$Kernel::OM->Get('DB')->{Backend} = $BackupDBBackend;

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
        Name      => 'Sort: Attribute "CurrentVersion.Data.NotSearchable.UnitTest"',
        Attribute => 'CurrentVersion.Data.NotSearchable.UnitTest',
        Expected  => undef
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

# prepare depl state mapping
my $DeplStateRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production',
);

# prepare inci state mapping
my $InciStateRef = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::Core::IncidentState',
    Name  => 'Operational',
);

# prepare test data mapping
my $TestData1 = 'Test001';
my $TestData2 = 'Test002';
my $TestData3 = 'Test003';

## prepare test assets ##
# first asset
my $ConfigItemID1 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemID1,
    'Created first asset'
);
my $VersionID1 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID1,
    Name         => $Helper->GetRandomID(),
    DefinitionID => 1,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    XMLData      => [
        undef,
        {
            Version => [
                undef,
                {
                    NotSearchable => [
                        undef,
                        {
                            UnitTest => [
                                undef,
                                {
                                    Content => $TestData1
                                }
                            ]
                        }
                    ]
                }
            ]
        }
    ],
    UserID       => 1,
);
$Self->True(
    $VersionID1,
    'Created version for first asset'
);
# second asset
my $ConfigItemID2 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemID2,
    'Created second asset'
);
my $VersionID2_1 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID2,
    Name         => $Helper->GetRandomID(),
    DefinitionID => 1,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    XMLData      => [
        undef,
        {
            Version => [
                undef,
                {
                    NotSearchable => [
                        undef,
                        {
                            UnitTest => [
                                undef,
                                {
                                    Content => $TestData2
                                }
                            ]
                        }
                    ]
                }
            ]
        }
    ],
    UserID       => 1,
);
$Self->True(
    $VersionID2_1,
    'Created version for second asset'
);
my $VersionID2_2 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID2,
    Name         => $Helper->GetRandomID(),
    DefinitionID => 1,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    XMLData      => [
        undef,
        {
            Version => [
                undef,
                {
                    NotSearchable => [
                        undef,
                        {
                            UnitTest => [
                                undef,
                                {
                                    Content => $TestData3
                                }
                            ]
                        }
                    ]
                }
            ]
        }
    ],
    UserID       => 1,
);
$Self->True(
    $VersionID2_2,
    'Created second version for second asset'
);
# third asset
my $ConfigItemID3 = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    ClassID => $ClassID,
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
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator EQ / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator EQ / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => [$ConfigItemID3]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator NE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator NE / Value empty string',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator !IN / Value [$TestData1,$TestData3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LT / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'LT',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LTE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'LTE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator GT / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'GT',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator GTE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'GTE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator STARTSWITH / Value $TestData3',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'STARTSWITH',
                    Value    => $TestData3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator STARTSWITH / Value substr($TestData3,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData3,0,4)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator ENDSWITH / Value $TestData3',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'ENDSWITH',
                    Value    => $TestData3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator ENDSWITH / Value substr($TestData3,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData3,-5)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator CONTAINS / Value $TestData3',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'CONTAINS',
                    Value    => $TestData3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator CONTAINS / Value substr($TestData3,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData3,2,-2)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LIKE / Value $TestData3',
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'LIKE',
                    Value    => $TestData3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator EQ / Value $TestData2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'EQ',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator EQ / Value empty string / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'EQ',
                    Value    => ''
                }
            ]
        },
        Expected => [$ConfigItemID3]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator NE / Value $TestData2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'NE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator NE / Value empty string / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'NE',
                    Value    => ''
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator IN / Value [$TestData1,$TestData3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator !IN / Value [$TestData1,$TestData3] / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => '!IN',
                    Value    => [$TestData1,$TestData3]
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LT / Value $TestData2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'LT',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LTE / Value $TestData2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'LTE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator GT / Value $TestData2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'GT',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator GTE / Value $TestData2 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'GTE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator STARTSWITH / Value $TestData3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'STARTSWITH',
                    Value    => $TestData3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator STARTSWITH / Value substr($TestData3,0,4) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData3,0,4)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator ENDSWITH / Value $TestData3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'ENDSWITH',
                    Value    => $TestData3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator ENDSWITH / Value substr($TestData3,-5) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData3,-5)
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator CONTAINS / Value $TestData3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'CONTAINS',
                    Value    => $TestData3
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator CONTAINS / Value substr($TestData3,2,-2) / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData3,2,-2)
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2]
    },
    {
        Name     => 'Search: Field CurrentVersion.Data.NotSearchable.UnitTest / Operator LIKE / Value $TestData3 / PreviousVersionSearch',
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.NotSearchable.UnitTest',
                    Operator => 'LIKE',
                    Value    => $TestData3
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
# attributes of this backend are not sortable

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
