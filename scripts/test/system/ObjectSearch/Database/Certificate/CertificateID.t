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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Certificate::CertificateID';

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
    $AttributeList,
    {
        CertificateID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
        },
        ID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','LT','LTE','GT','GTE'],
            ValueType    => 'NUMERIC'
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
            Field    => 'CertificateID',
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
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'CertificateID',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'CertificateID',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field CertificateID / Operator EQ',
        Search       => {
            Field    => 'CertificateID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CertificateID / Operator NE',
        Search       => {
            Field    => 'CertificateID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CertificateID / Operator IN',
        Search       => {
            Field    => 'CertificateID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'vfs.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CertificateID / Operator !IN',
        Search       => {
            Field    => 'CertificateID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'vfs.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CertificateID / Operator LT',
        Search       => {
            Field    => 'CertificateID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CertificateID / Operator LTE',
        Search       => {
            Field    => 'CertificateID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CertificateID / Operator GT',
        Search       => {
            Field    => 'CertificateID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field CertificateID / Operator GTE',
        Search       => {
            Field    => 'CertificateID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id >= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator EQ',
        Search       => {
            Field    => 'ID',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id = 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator NE',
        Search       => {
            Field    => 'ID',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id <> 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator IN',
        Search       => {
            Field    => 'ID',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'vfs.id IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator !IN',
        Search       => {
            Field    => 'ID',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'vfs.id NOT IN (1)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator LT',
        Search       => {
            Field    => 'ID',
            Operator => 'LT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id < 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator LTE',
        Search       => {
            Field    => 'ID',
            Operator => 'LTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id <= 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator GT',
        Search       => {
            Field    => 'ID',
            Operator => 'GT',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id > 1'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field ID / Operator GTE',
        Search       => {
            Field    => 'ID',
            Operator => 'GTE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.id >= 1'
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
        Name      => 'Sort: Attribute "CertificateID"',
        Attribute => 'CertificateID',
        Expected  => {
            'Select'  => ['vfs.id'],
            'OrderBy' => ['vfs.id']
        }
    },
    {
        Name      => 'Sort: Attribute "ID"',
        Attribute => 'ID',
        Expected  => {
            'Select'  => ['vfs.id'],
            'OrderBy' => ['vfs.id']
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

## prepare test certificates ##
my $HomeDir = $Kernel::OM->Get('Config')->Get('Home');
my @CertificateIDs;
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
        Directory => $HomeDir . '/scripts/test/system/sample/Certificate',
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
    push (
        @CertificateIDs,
        $ID
    );
}

my $CertID1 = $CertificateIDs[0];
my $CertID2 = $CertificateIDs[1];
my $CertID3 = $CertificateIDs[2];
my $CertID4 = $CertificateIDs[3];
my $CertID5 = $CertificateIDs[4];

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Certificate'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field CertificateID / Operator EQ / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CertificateID',
                    Operator => 'EQ',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID2]
    },
    {
        Name     => 'Search: Field CertificateID / Operator NE / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CertificateID',
                    Operator => 'NE',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID1,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field CertificateID / Operator IN / Value [$CertID1,$CertID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CertificateID',
                    Operator => 'IN',
                    Value    => [$CertID1,$CertID3]
                }
            ]
        },
        Expected => [$CertID1, $CertID3]
    },
    {
        Name     => 'Search: Field CertificateID / Operator !IN / Value [$CertID1,$CertID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'CertificateID',
                    Operator => '!IN',
                    Value    => [$CertID1,$CertID3]
                }
            ]
        },
        Expected => [$CertID2,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field CertificateID / Operator LT / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CertificateID',
                    Operator => 'LT',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID1]
    },
    {
        Name     => 'Search: Field CertificateID / Operator LTE / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CertificateID',
                    Operator => 'LTE',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field CertificateID / Operator GT / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CertificateID',
                    Operator => 'GT',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field CertificateID / Operator GTE / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'CertificateID',
                    Operator => 'GTE',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field ID / Operator EQ / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'EQ',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID2]
    },
    {
        Name     => 'Search: Field ID / Operator NE / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'NE',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID1,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field ID / Operator IN / Value [$CertID1,$CertID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'IN',
                    Value    => [$CertID1,$CertID3]
                }
            ]
        },
        Expected => [$CertID1, $CertID3]
    },
    {
        Name     => 'Search: Field ID / Operator !IN / Value [$CertID1,$CertID3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => '!IN',
                    Value    => [$CertID1,$CertID3]
                }
            ]
        },
        Expected => [$CertID2,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field ID / Operator LT / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LT',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID1]
    },
    {
        Name     => 'Search: Field ID / Operator LTE / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'LTE',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => 'Search: Field ID / Operator GT / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GT',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field ID / Operator GTE / Value $CertID2',
        Search   => {
            'AND' => [
                {
                    Field    => 'ID',
                    Operator => 'GTE',
                    Value    => $CertID2
                }
            ]
        },
        Expected => [$CertID2,$CertID3,$CertID4,$CertID5]
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
        Name     => 'Sort: Field CertificateID',
        Sort     => [
            {
                Field => 'CertificateID'
            }
        ],
        Expected => [$CertID1, $CertID2, $CertID3, $CertID4, $CertID5]
    },
    {
        Name     => 'Sort: Field CertificateID / Direction ascending',
        Sort     => [
            {
                Field     => 'CertificateID',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID1, $CertID2, $CertID3, $CertID4, $CertID5]
    },
    {
        Name     => 'Sort: Field CertificateID / Direction descending',
        Sort     => [
            {
                Field     => 'CertificateID',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID5, $CertID4, $CertID3, $CertID2, $CertID1]
    },
    {
        Name     => 'Sort: Field ID',
        Sort     => [
            {
                Field => 'ID'
            }
        ],
        Expected => [$CertID1, $CertID2, $CertID3, $CertID4, $CertID5]
    },
    {
        Name     => 'Sort: Field ID / Direction ascending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID1, $CertID2, $CertID3, $CertID4, $CertID5]
    },
    {
        Name     => 'Sort: Field ID / Direction descending',
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID5, $CertID4, $CertID3, $CertID2, $CertID1]
    }
);
for my $Test ( @IntegrationSortTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Certificate',
        Result     => 'ARRAY',
        Sort       => $Test->{Sort},
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
