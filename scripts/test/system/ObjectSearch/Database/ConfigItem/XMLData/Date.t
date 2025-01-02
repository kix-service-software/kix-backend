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
my $InputType       = 'Date';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $AttributeModule ) );

# create backend object
my $AttributeObject = $AttributeModule->new( %{ $Self } );
$Self->Is(
    ref( $AttributeObject ),
    $AttributeModule,
    'Attribute object has correct module ref'
);

# check GetSupportedAttributes before field is created
my $AttributeListBefore = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeListBefore->{'DynamicField_UnitTest'},
    undef,
    'GetSupportedAttributes provides expected data before creation of test field'
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

$Self->True(
    $ClassID,
    'Created asset class for UnitTest'
);

my $DefinitionID = $Kernel::OM->Get('ITSMConfigItem')->DefinitionAdd(
    ClassID    => $ClassID,
    Definition => <<'END',
[
    {
        Key             => 'Date',
        Name            => 'Date',
        Searchable      => 1,
        CustomerVisible => 0,
        Input           => {
            Type             => 'Date',
            YearPeriodFuture => 10,
            YearPeriodPast   => 20
        },
        CountDefault => 0,
        CountMax     => 1,
        CountMin     => 0
    }
]
END
    UserID     => 1
);
$Self->True(
    $DefinitionID,
    'Added definition for asset class UnitTest'
);

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList->{'CurrentVersion.Data.Date'},
    {
        IsSearchable => 1,
        IsSortable   => 0,
        Operators    => ['EQ','NE','LT','LTE','GT','GTE'],
        Class        => [ $Class ],
        ClassID      => [ $ClassID ],
        ValueType    => 'DATE'
    },
    'GetSupportedAttributes provides expected data for date attribute'
);

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2024-02-09 00:00:00',
);
$Helper->FixedTimeSet($SystemTime);

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

    my $BigIntCast  = 'BIGINT';
    my $CastMapping = $Kernel::OM->Get('DB')->GetDatabaseFunction('CastMapping');
    if (
        ref( $CastMapping ) eq 'HASH'
        && $CastMapping->{BIGINT}
    ) {
        $BigIntCast = $CastMapping->{BIGINT};
    }
    if ( $DatabaseType eq 'mysql' ) {
        $Self->Is(
            $BigIntCast,
            'UNSIGNED',
            'DatabaseType ' . $DatabaseType . ' / BigIntCast'
        );
    }
    else {
        $Self->Is(
            $BigIntCast,
            'BIGINT',
            'DatabaseType ' . $DatabaseType . ' / BigIntCast'
        );
    }

    my $QuoteSingle   = q{};
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
            Name         => "Search: undef search",
            Search       => undef,
            Expected     => undef
        },
        {
            Name         => "Search: Value undef",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'EQ',
                Value    => undef

            },
            Expected     => undef
        },
        {
            Name         => "Search: Field undef",
            Search       => {
                Field    => undef,
                Operator => 'EQ',
                Value    => '+1d'
            },
            Expected     => undef
        },
        {
            Name         => "Search: Field invalid",
            Search       => {
                Field    => 'Test',
                Operator => 'EQ',
                Value    => '+1d'
            },
            Expected     => undef
        },
        {
            Name         => "Search: Operator undef",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => undef,
                Value    => '+1d'
            },
            Expected     => undef
        },
        {
            Name         => "Search: Operator invalid",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'Test',
                Value    => '+1d'
            },
            Expected     => undef
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator EQ / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'EQ',
                Value    => '2024-02-09'
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value = \'2024-02-09 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator EQ / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'EQ',
                Value    => '+1d'
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value = \'2024-02-10 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator NE / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'NE',
                Value    => '2024-02-09'
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    '(xst_left0.xml_content_value != \'2024-02-09 00:00:00\' OR xst_left0.xml_content_value IS NULL)'
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator NE / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'NE',
                Value    => '+1d'
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    '(xst_left0.xml_content_value != \'2024-02-10 00:00:00\' OR xst_left0.xml_content_value IS NULL)'
                ]

            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator LT / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'LT',
                Value    => '2024-02-09'
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value < \'2024-02-09 00:00:00\''
                ]

            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator LT / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'LT',
                Value    => '+1d'
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value < \'2024-02-10 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator LTE / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'LTE',
                Value    => '2024-02-09'
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value <= \'2024-02-09 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator LTE / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'LTE',
                Value    => '+1d'
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value <= \'2024-02-10 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator GT / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'GT',
                Value    => '2024-02-09'
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value > \'2024-02-09 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator GT / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'GT',
                Value    => '+1d'
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value > \'2024-02-10 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator GTE / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'GTE',
                Value    => '2024-02-09'
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value >= \'2024-02-09 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator GTE / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'GTE',
                Value    => '+1d'
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = ci.last_version_id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value >= \'2024-02-10 00:00:00\''
                ]

            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator EQ / PreviousVersionSearch / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'EQ',
                Value    => '2024-02-09'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value = \'2024-02-09 00:00:00\''
                ]

            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator EQ / PreviousVersionSearch / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'EQ',
                Value    => '+1d'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value = \'2024-02-10 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator NE / PreviousVersionSearch / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'NE',
                Value    => '2024-02-09'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    '(xst_left0.xml_content_value != \'2024-02-09 00:00:00\' OR xst_left0.xml_content_value IS NULL)'
                ]

            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator NE / PreviousVersionSearch / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'NE',
                Value    => '+1d'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    '(xst_left0.xml_content_value != \'2024-02-10 00:00:00\' OR xst_left0.xml_content_value IS NULL)'
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator LT / PreviousVersionSearch / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'LT',
                Value    => '2024-02-09'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value < \'2024-02-09 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator LT / PreviousVersionSearch / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'LT',
                Value    => '+1d'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value < \'2024-02-10 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator LTE / PreviousVersionSearch / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'LTE',
                Value    => '2024-02-09'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value <= \'2024-02-09 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator LTE / PreviousVersionSearch / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'LTE',
                Value    => '+1d'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value <= \'2024-02-10 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator GT / PreviousVersionSearch / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'GT',
                Value    => '2024-02-09'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value > \'2024-02-09 00:00:00\''
                ]

            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator GT / PreviousVersionSearch / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'GT',
                Value    => '+1d'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value > \'2024-02-10 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator GTE / PreviousVersionSearch / absolute value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'GTE',
                Value    => '2024-02-09'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => undef,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value >= \'2024-02-09 00:00:00\''
                ]
            }
        },
        {
            Name         => "Search: valid search / Field CurrentVersion.Data.Date / Operator GTE / PreviousVersionSearch / relative value",
            Search       => {
                Field    => 'CurrentVersion.Data.Date',
                Operator => 'GTE',
                Value    => '+1d'
            },
            Flags        => {
                PreviousVersionSearch => 1
            },
            Expected     => {
                'IsRelative' => 1,
                'Join' => [
                    'LEFT OUTER JOIN configitem_version civ on civ.configitem_id = ci.id',
                    'LEFT OUTER JOIN xml_storage xst_left0 ON CAST(xst_left0.xml_key AS ' . $BigIntCast . ') = civ.id AND xst_left0.xml_content_key LIKE \'[1]{' . $QuoteSingle . '\'Version' . $QuoteSingle . '\'}[1]{' . $QuoteSingle . '\'Date' . $QuoteSingle . '\'}[%]{' . $QuoteSingle . '\'Content' . $QuoteSingle . '\'}\' AND xst_left0.xml_type IN (\'ITSM::ConfigItem::' . $ClassID . '\',\'ITSM::ConfigItem::Archiv::' . $ClassID . '\')'
                ],
                'Where' => [
                    'xst_left0.xml_content_value >= \'2024-02-10 00:00:00\''
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
        Name      => 'Sort: Attribute "CurrentVersion.Data.Date"',
        Attribute => 'CurrentVersion.Data.Date',
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
    DefinitionID => $DefinitionID,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    XMLData      => [
        undef,
        {
            Version => [
                undef,
                {
                    Date => [
                        undef,
                        {
                            Content => '2024-02-09 00:00:00'
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
    DefinitionID => $DefinitionID,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    XMLData      => [
        undef,
        {
            Version => [
                undef,
                {
                    Date => [
                        undef,
                        {
                            Content => '2024-02-23 00:00:00'
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
    DefinitionID => $DefinitionID,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    XMLData      => [
        undef,
        {
            Version => [
                undef,
                {
                    Date => [
                        undef,
                        {
                            Content => '2024-02-16 00:00:00'
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
my $VersionID3 = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
    ConfigItemID => $ConfigItemID3,
    Name         => $Helper->GetRandomID(),
    DefinitionID => $DefinitionID,
    DeplStateID  => $DeplStateRef->{ItemID},
    InciStateID  => $InciStateRef->{ItemID},
    XMLData      => [
        undef,
        {
            Version => [
                undef,
                {
                    Date => [
                        undef,
                        {
                            Content => '2024-02-16 00:00:00'
                        }
                    ]
                }
            ]
        }
    ],
    UserID       => 1,
);
$Self->True(
    $VersionID3,
    'Created version for third asset'
);

# discard config item object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['ITSMConfigItem'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator EQ / Value 2024-02-16",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'EQ',
                    Value    => '2024-02-16'
                }
            ]
        },
        Expected => [$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator EQ / Value +7d",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'EQ',
                    Value    => '+7d'
                }
            ]
        },
        Expected => [$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator NE / Value 2024-02-16",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'NE',
                    Value    => '2024-02-16'
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator NE / Value +7d",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'NE',
                    Value    => '+7d'
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator LT / Value 2024-02-16",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'LT',
                    Value    => '2024-02-16'
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator LT / Value +1w",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'LT',
                    Value    => '+1w'
                }
            ]
        },
        Expected => [$ConfigItemID1]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator LTE / Value 2024-02-16",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'LTE',
                    Value    => '2024-02-16'
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator LTE / Value +1w",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'LTE',
                    Value    => '+1w'
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator GT / Value 2024-02-10",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'GT',
                    Value    => '2024-02-10'
                }
            ]
        },
        Expected => [$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator GT / Value +1d",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'GT',
                    Value    => '+1d'
                }
            ]
        },
        Expected => [$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator GTE / Value 2024-02-16",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'GTE',
                    Value    => '2024-02-16'
                }
            ]
        },
        Expected => [$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator GTE / Value +1w",
        Search   => {
            'AND' => [
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'GTE',
                    Value    => '+1w'
                }
            ]
        },
        Expected => [$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator EQ / Value 2024-02-23 / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'EQ',
                    Value    => '2024-02-23'
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator EQ / Value +2w / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'EQ',
                    Value    => '+2w'
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator NE / Value 2024-02-23 / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'NE',
                    Value    => '2024-02-23'
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator NE / Value +2w / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'NE',
                    Value    => '+2w'
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator LT / Value 2024-02-23 / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'LT',
                    Value    => '2024-02-23'
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator LT / Value +2w / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'LT',
                    Value    => '+2w'
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator LTE / Value 2024-02-23 / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'LTE',
                    Value    => '2024-02-23'
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator LTE / Value +2w / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'LTE',
                    Value    => '+2w'
                }
            ]
        },
        Expected => [$ConfigItemID1,$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator GT / Value 2024-02-09 / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'GT',
                    Value    => '2024-02-09'
                }
            ]
        },
        Expected => [$ConfigItemID2,$ConfigItemID3]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator GT / Value +1w / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'GT',
                    Value    => '+1w'
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator GTE / Value 2024-02-23 / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'GTE',
                    Value    => '2024-02-23'
                }
            ]
        },
        Expected => [$ConfigItemID2]
    },
    {
        Name     => "Search: Field CurrentVersion.Data.Date / Operator GTE / Value +2w / PreviousVersionSearch",
        Search   => {
            'AND' => [
                {
                    Field    => 'PreviousVersionSearch',
                    Value    => 1
                },
                {
                    Field    => 'CurrentVersion.Data.Date',
                    Operator => 'GTE',
                    Value    => '+2w'
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

# reset fixed time
$Helper->FixedTimeUnset();

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
