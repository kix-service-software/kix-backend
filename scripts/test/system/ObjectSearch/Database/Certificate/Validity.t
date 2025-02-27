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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Certificate::Validity';

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
        'Attribute object can "' . $Method . q{"}
    );
}

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList, {
        StartDate => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        },
        EndDate => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        }
    },
    'GetSupportedAttributes provides expected data'
);

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2025-01-01 12:00:00',
);
$Helper->FixedTimeSet($SystemTime);

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
            Field    => 'StartDate',
            Operator => 'EQ',
            Value    => undef

        },
        Expected     => undef
    },,
    {
        Name         => 'Search: Value invalid',
        Search       => {
            Field    => 'StartDate',
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
            Field    => 'StartDate',
            Operator => undef,
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'StartDate',
            Operator => 'Test',
            Value    => '1'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator EQ / absolute value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'EQ',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value = \'2025-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator EQ / relative value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value = \'2025-01-01 13:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator NE / absolute value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'NE',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                '(vfsp0.preferences_value != \'2025-01-01 12:00:00\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator NE / relative value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'NE',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                '(vfsp0.preferences_value != \'2025-01-01 13:00:00\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator LT / absolute value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'LT',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value < \'2025-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator LT / relative value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value < \'2025-01-01 13:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator GT / absolute value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'GT',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value > \'2025-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator GT / relative value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value > \'2025-01-01 13:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator LTE / absolute value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'LTE',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value <= \'2025-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator LTE / relative value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value <= \'2025-01-01 13:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator GTE / absolute value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'GTE',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value >= \'2025-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field StartDate / Operator GTE / relative value',
        Search       => {
            Field    => 'StartDate',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value >= \'2025-01-01 13:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator EQ / absolute value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'EQ',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value = \'2025-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator EQ / relative value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'EQ',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value = \'2025-01-01 13:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator NE / absolute value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'NE',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                '(vfsp0.preferences_value != \'2025-01-01 12:00:00\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator NE / relative value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'NE',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                '(vfsp0.preferences_value != \'2025-01-01 13:00:00\' OR vfsp0.preferences_value IS NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator LT / absolute value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'LT',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value < \'2025-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator LT / relative value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'LT',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value < \'2025-01-01 13:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator GT / absolute value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'GT',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value > \'2025-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator GT / relative value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'GT',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value > \'2025-01-01 13:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator LTE / absolute value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'LTE',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value <= \'2025-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator LTE / relative value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'LTE',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value <= \'2025-01-01 13:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator GTE / absolute value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'GTE',
            Value    => '2025-01-01 12:00:00'
        },
        Expected     => {
            'IsRelative' => undef,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value >= \'2025-01-01 12:00:00\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field EndDate / Operator GTE / relative value',
        Search       => {
            Field    => 'EndDate',
            Operator => 'GTE',
            Value    => '+1h'
        },
        Expected     => {
            'IsRelative' => 1,
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'Where' => [
                'vfsp0.preferences_value >= \'2025-01-01 13:00:00\''
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
        Name      => 'Sort: Attribute "StartDate"',
        Attribute => 'StartDate',
        Expected  => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'StartDate\''
            ],
            'OrderBy' => [
                'cstartdate'
            ],
            'Select' => [
                'vfsp0.preferences_value AS cstartdate'
            ]
        }
    },
    {
        Name      => 'Sort: Attribute "EndDate"',
        Attribute => 'EndDate',
        Expected  => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key = \'EndDate\''
            ],
            'OrderBy' => [
                'cenddate'
            ],
            'Select' => [
                'vfsp0.preferences_value AS cenddate'
            ]
        }
    },
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

my $HomeDir = $Kernel::OM->Get('Config')->Get('Home');
my @List;
my @Files = (
    {
        Filename    => 'ExampleCA.pem',
        Filesize    => 2_800,
        ContentType => 'application/x-x509-ca-cert',
        CType       => 'SMIME',
        Type        => 'Cert',
        Name        => 'Type .PEM | application/x-x509-ca-cert / Certificate'
    },
    {
        Filename    => 'ExampleKey.pem',
        Filesize    => 1_704,
        ContentType => 'application/x-x509-ca-cert',
        CType       => 'SMIME',
        Type        => 'Private',
        Name        => 'Type .PEM | application/x-x509-ca-cert / Private Key',
        Passphrase  => 'start123'
    },
    {
        Filename    => 'Example.crt',
        Filesize    => 1_310,
        ContentType => 'application/pkix-cert',
        CType       => 'SMIME',
        Type        => 'Cert',
        Name        => 'Type .CRT | application/pkix-cert / Certificate'
    },
    {
        Filename    => 'Example.csr',
        Filesize    => 1_009,
        ContentType => 'application/pkcs10',
        CType       => 'SMIME',
        Type        => 'Cert',
        Name        => 'Type .CSR | application/pkcs10 / Certificate'
    },
    {
        Filename    => 'Example.key',
        Filesize    => 1_751,
        ContentType => 'application/x-iwork-keynote-sffkey',
        CType       => 'SMIME',
        Type        => 'Private',
        Name        => 'Type .KEY | application/x-iwork-keynote-sffkey / Private Key',
        Passphrase  => 'start123'
    }
);

for my $File ( @Files ) {
    my $Content = $Kernel::OM->Get('Main')->FileRead(
        Directory => $HomeDir . '/scripts/test/system/sample/Certificate/Certificates',
        Filename  => $File->{Filename},
        Mode      => 'binmode'
    );

    $Self->True(
        $Content,
        'Read: ' . $File->{Name}
    );

    my $ID = $Kernel::OM->Get('Certificate')->CertificateCreate(
        File => {
            Filename    => $File->{Filename},
            Filesize    => $File->{Filesize},
            ContentType => $File->{ContentType},
            Content     => MIME::Base64::encode_base64( ${$Content} ),
        },
        CType      => $File->{CType},
        Type       => $File->{Type},
        Passphrase => $File->{Passphrase}
    );

    $Self->True(
        $ID,
        'Create: ' . $File->{Name}
    );

    next if !$ID;

    my $Certificate = $Kernel::OM->Get('Certificate')->CertificateGet(
        ID => $ID
    );

    $Self->True(
        IsHashRefWithData($Certificate),
        'Get: ' . $File->{Name}
    );

    next if !$Certificate;

    push (
        @List,
        $Certificate
    );
}

my $CertID1 = $List[0]->{FileID};
my $CertID2 = $List[1]->{FileID};
my $CertID3 = $List[2]->{FileID};
my $CertID4 = $List[3]->{FileID};
my $CertID5 = $List[4]->{FileID};

my $SearchValue1 = $List[0]->{StartDate};
my $SearchValue2 = $List[2]->{EndDate};
my $SearchValue3 = $List[4]->{StartDate};

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Certificate'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field StartDate / Operator EQ / Value ' . $SearchValue1,
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'EQ',
                    Value    => $SearchValue1
                }
            ]
        },
        Expected => [$CertID1, $CertID2]
    },
    {
        Name     => 'Search: Field StartDate / Operator EQ / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'EQ',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field StartDate / Operator NE / Value ' . $SearchValue1,
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'NE',
                    Value    => $SearchValue1
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field StartDate / Operator NE / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'NE',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field StartDate / Operator LT / Value ' . $SearchValue1,
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'LT',
                    Value    => $SearchValue1
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field StartDate / Operator LT / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'LT',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field StartDate / Operator GT / Value ' . $SearchValue1,
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'GT',
                    Value    => $SearchValue1
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field StartDate / Operator GT / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'GT',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field StartDate / Operator LTE / Value ' . $SearchValue1,
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'LTE',
                    Value    => $SearchValue1
                }
            ]
        },
        Expected => [$CertID1, $CertID2]
    },
    {
        Name     => 'Search: Field StartDate / Operator LTE / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'LTE',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field StartDate / Operator GTE / Value ' . $SearchValue1,
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'GTE',
                    Value    => $SearchValue1
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field StartDate / Operator GTE / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'StartDate',
                    Operator => 'GTE',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field EndDate / Operator EQ / Value ' . $SearchValue2,
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'EQ',
                    Value    => $SearchValue2
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field EndDate / Operator EQ / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'EQ',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field EndDate / Operator NE / Value ' . $SearchValue2,
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'NE',
                    Value    => $SearchValue2
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field EndDate / Operator NE / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'NE',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field EndDate / Operator LT / Value ' . $SearchValue2,
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'LT',
                    Value    => $SearchValue2
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field EndDate / Operator LT / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'LT',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field EndDate / Operator GT / Value ' . $SearchValue2,
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'GT',
                    Value    => $SearchValue2
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field EndDate / Operator GT / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'GT',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field EndDate / Operator LTE / Value ' . $SearchValue2,
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'LTE',
                    Value    => $SearchValue2
                }
            ]
        },
        Expected => [$CertID3, $CertID5]
    },
    {
        Name     => 'Search: Field EndDate / Operator LTE / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'LTE',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'Search: Field EndDate / Operator GTE / Value ' . $SearchValue2,
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'GTE',
                    Value    => $SearchValue2
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    },
    {
        Name     => 'Search: Field EndDate / Operator GTE / Value -1Y',
        Search   => {
            'AND' => [
                {
                    Field    => 'EndDate',
                    Operator => 'GTE',
                    Value    => '-1Y'
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID5]
    }
);

for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Certificate',
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
        Name     => 'Sort: Field StartDate',
        Sort     => [
            {
                Field => 'StartDate'
            }
        ],
        Expected => [$CertID1, $CertID2, $CertID3, $CertID5]
    },
    {
        Name     => 'Sort: Field StartDate / Direction ascending',
        Sort     => [
            {
                Field     => 'StartDate',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID1, $CertID2, $CertID3, $CertID5]
    },
    {
        Name     => 'Sort: Field StartDate / Direction descending',
        Sort     => [
            {
                Field     => 'StartDate',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID3, $CertID5, $CertID1, $CertID2]
    },
    {
        Name     => 'Sort: Field EndDate',
        Sort     => [
            {
                Field => 'EndDate'
            }
        ],
        Expected => [$CertID3, $CertID5, $CertID1, $CertID2]
    },
    {
        Name     => 'Sort: Field EndDate / Direction ascending',
        Sort     => [
            {
                Field     => 'EndDate',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID3, $CertID5, $CertID1, $CertID2]
    },
    {
        Name     => 'Sort: Field EndDate / Direction descending',
        Sort     => [
            {
                Field     => 'EndDate',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID1, $CertID2, $CertID3, $CertID5]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Certificate',
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

_RemoveFiles();

sub _RemoveFiles {
    my ( %Param ) = @_;

    for my $Cert ( @List ) {
        my $Pre = $Cert->{Type} eq 'Cert' ? 'certs' : 'private';
        my $Success = $Kernel::OM->Get('Main')->FileDelete(
            Location        => $HomeDir . '/var/ssl/'. $Pre . '/KIX_' . $Cert->{Type} . '_' . $Cert->{FileID}
        );
    }

    return 1;
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
