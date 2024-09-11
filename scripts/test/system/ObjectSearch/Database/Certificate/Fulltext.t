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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Certificate::Fulltext';

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
        Fulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['LIKE']
        }
    },
    'GetSupportedAttributes provides expected data'
);

# Quoting ESCAPE character backslash
my $QuoteBack = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteBack');
my $Escape = "\\";
if ( $QuoteBack ) {
    $Escape =~ s/\\/$QuoteBack\\/g;
}

# Quoting single quote character
my $QuoteSingle = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSingle');

# Quoting semicolon character
my $QuoteSemicolon = $Kernel::OM->Get('DB')->GetDatabaseFunction('QuoteSemicolon');

# check if database is casesensitive
my $CaseSensitive = $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive');

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
            Field    => 'Name',
            Operator => 'LIKE',
            Value    => undef

        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field undef',
        Search       => {
            Field    => undef,
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Field invalid',
        Search       => {
            Field    => 'Test',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator undef',
        Search       => {
            Field    => 'Name',
            Operator => undef,
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: Operator invalid',
        Search       => {
            Field    => 'Name',
            Operator => 'Test',
            Value    => 'Test'
        },
        Expected     => undef
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator LIKE',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Join' => [
                'INNER JOIN virtual_fs_preferences vfsp0 ON vfsp0.virtual_fs_id = vfs.id',
                'AND vfsp0.preferences_key IN (\'Subject\',\'Email\')'
            ],
            'Where' => [
                $CaseSensitive ? '(LOWER(vfsp0.preferences_value) LIKE LOWER(\'%Test%\') ESCAPE \'' . $Escape . '\') ' : '(vfsp0.preferences_value LIKE \'%Test%\' ESCAPE \'' . $Escape . '\') '
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
        Name      => 'Sort: Attribute "Fulltext"',
        Attribute => 'Fulltext',
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

my $SearchValue1 = $List[0]->{Subject};
my $SearchValue2 = $List[2]->{Email};
my $SearchValue3 = $List[3]->{Subject};

# discard contact object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Certificate'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$SearchValue1",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $SearchValue1 . q{"}
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue1,0,20)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($SearchValue1,0,20) . q{"}
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue1,-10)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($SearchValue1,-10) . q{"}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue1,10,-10)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($SearchValue1,10,-10) . q{"}
                }
            ]
        },
        Expected => [$CertID1,$CertID2]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue2,0,4)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($SearchValue2,0,4) . q{"}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue2,-5)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($SearchValue2,-5) . q{"}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue2,2,-2)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($SearchValue2,2,-2) . q{"}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$SearchValue2",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $SearchValue2 . q{"}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue3,0,15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($SearchValue3,0,15) . q{"}
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue3,-15)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($SearchValue3,-15) . q{"}
                }
            ]
        },
        Expected => [$CertID1,$CertID2,$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value substr(\$SearchValue3,8,-8)",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . substr($SearchValue3,8,-8) . q{"}
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
    },
    {
        Name     => "Search: Field Fulltext / Operator LIKE / Value \$SearchValue3",
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => q{"} . $SearchValue3 . q{"}
                }
            ]
        },
        Expected => [$CertID3,$CertID4,$CertID5]
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
