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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Certificate::Filename';

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
        Filename => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN','STARTSWITH','ENDSWITH','CONTAINS','LIKE']
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
            Field    => 'Filename',
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
            Field    => 'Filename',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Filename',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Filename / Operator EQ',
        Search       => {
            Field    => 'Filename',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.filename = \'1\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Filename / Operator NE',
        Search       => {
            Field    => 'Filename',
            Operator => 'NE',
            Value    => '1'
        },
        Expected     => {
            'Where' => [
                'vfs.filename != \'1\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Filename / Operator IN',
        Search       => {
            Field    => 'Filename',
            Operator => 'IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'vfs.filename IN (\'1\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Filename / Operator !IN',
        Search       => {
            Field    => 'Filename',
            Operator => '!IN',
            Value    => ['1']
        },
        Expected     => {
            'Where' => [
                'vfs.filename NOT IN (\'1\')'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Filename / Operator STARTSWITH',
        Search       => {
            Field    => 'Filename',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'vfs.filename LIKE \'Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Filename / Operator ENDSWITH',
        Search       => {
            Field    => 'Filename',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'vfs.filename LIKE \'%Test\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Filename / Operator CONTAINS',
        Search       => {
            Field    => 'Filename',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'vfs.filename LIKE \'%Test%\''
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field Filename / Operator LIKE',
        Search       => {
            Field    => 'Filename',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Where' => [
                'vfs.filename LIKE \'Test\''
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
        Name      => 'Sort: Attribute "Filename"',
        Attribute => 'Filename',
        Expected  => {
            'Select'  => ['vfs.filename'],
            'OrderBy' => ['vfs.filename']
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
my @Certs;
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

    next if !IsHashRefWithData($Certificate);

    my $Name = 'Certificate/'
        . $Certificate->{CType}
        . q{/}
        . $Certificate->{Type}
        . q{/}
        . $Certificate->{Fingerprint};
    push (
        @Certs,
        {
            Name => $Name,
            ID   => $ID
        }
    );
}

my $CertID1 = $Certs[0]->{ID};
my $CertID2 = $Certs[1]->{ID};
my $CertID3 = $Certs[2]->{ID};
my $CertID4 = $Certs[3]->{ID};
my $CertID5 = $Certs[4]->{ID};

my $CertName1 = $Certs[0]->{Name};
my $CertName2 = $Certs[1]->{Name};
my $CertName3 = $Certs[2]->{Name};
my $CertName4 = $Certs[3]->{Name};
my $CertName5 = $Certs[4]->{Name};

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Certificate'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Filename / Operator EQ / Value $CertName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => 'EQ',
                    Value    => $CertName2
                }
            ]
        },
        Expected => [$CertID2]
    },
    {
        Name     => 'Search: Field Filename / Operator NE / Value $CertName2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => 'NE',
                    Value    => $CertName2
                }
            ]
        },
        Expected => [$CertID1,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => 'Search: Field Filename / Operator IN / Value [$CertName1,$CertName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => 'IN',
                    Value    => [$CertName1,$CertName3]
                }
            ]
        },
        Expected => [$CertID1, $CertID3]
    },
    {
        Name     => 'Search: Field Filename / Operator !IN / Value [$CertName1,$CertName3]',
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => '!IN',
                    Value    => [$CertName1,$CertName3]
                }
            ]
        },
        Expected => [$CertID2,$CertID4,$CertID5]
    },
    {
        Name     => "Search: Field Filename / Operator STARTSWITH / Value \$CertName4",
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => 'STARTSWITH',
                    Value    => $CertName4
                }
            ]
        },
        Expected => [$CertID4]
    },
    {
        Name     => "Search: Field Filename / Operator STARTSWITH / Value substr(\$CertName4,0,20)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => 'STARTSWITH',
                    Value    => substr($CertName4,0,20)
                }
            ]
        },
        Expected => [$CertID1,$CertID3,$CertID4]
    },
    {
        Name     => "Search: Field Filename / Operator ENDSWITH / Value \$CertName5",
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => 'ENDSWITH',
                    Value    => $CertName5
                }
            ]
        },
        Expected => [$CertID5]
    },
    {
        Name     => "Search: Field Filename / Operator ENDSWITH / Value substr(\$CertName5,-10)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => 'ENDSWITH',
                    Value    => substr($CertName5,-10)
                }
            ]
        },
        Expected => [$CertID3,$CertID5]
    },
    {
        Name     => "Search: Field Filename / Operator CONTAINS / Value \$CertName1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => 'CONTAINS',
                    Value    => $CertName1
                }
            ]
        },
        Expected => [$CertID1]
    },
    {
        Name     => "Search: Field Filename / Operator CONTAINS / Value substr(\$CertName1,10,-10)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => 'CONTAINS',
                    Value    => substr($CertName1,10,-10)
                }
            ]
        },
        Expected => [$CertID1]
    },
    {
        Name     => "Search: Field Filename / Operator LIKE / Value \$CertName2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Filename',
                    Operator => 'LIKE',
                    Value    => $CertName2
                }
            ]
        },
        Expected => [$CertID2]
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
        Name     => 'Sort: Field Filename',
        Sort     => [
            {
                Field => 'Filename'
            }
        ],
        Expected => [$CertID1, $CertID3, $CertID4, $CertID2, $CertID5]
    },
    {
        Name     => 'Sort: Field Filename / Direction ascending',
        Sort     => [
            {
                Field     => 'Filename',
                Direction => 'ascending'
            }
        ],
        Expected => [$CertID1, $CertID3, $CertID4, $CertID2, $CertID5]
    },
    {
        Name     => 'Sort: Field Filename / Direction descending',
        Sort     => [
            {
                Field     => 'Filename',
                Direction => 'descending'
            }
        ],
        Expected => [$CertID5, $CertID2, $CertID4, $CertID3, $CertID1]
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
