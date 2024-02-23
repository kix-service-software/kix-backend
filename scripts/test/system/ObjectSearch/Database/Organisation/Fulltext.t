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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Organisation::Fulltext';

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
    $AttributeList, {
        Fulltext => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['STARTSWITH','ENDSWITH','CONTAINS','LIKE']
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
            Field    => 'Name',
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
        Name         => 'Search: valid search / Field Fulltext / Operator STARTSWITH',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'STARTSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field' => 'Name',
                        'Operator' => 'STARTSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Number',
                        'Operator' => 'STARTSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Street',
                        'Operator' => 'STARTSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Zip',
                        'Operator' => 'STARTSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'City',
                        'Operator' => 'STARTSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Country',
                        'Operator' => 'STARTSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Url',
                        'Operator' => 'STARTSWITH',
                        'Value' => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator ENDSWITH',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'ENDSWITH',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field' => 'Name',
                        'Operator' => 'ENDSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Number',
                        'Operator' => 'ENDSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Street',
                        'Operator' => 'ENDSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Zip',
                        'Operator' => 'ENDSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'City',
                        'Operator' => 'ENDSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Country',
                        'Operator' => 'ENDSWITH',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Url',
                        'Operator' => 'ENDSWITH',
                        'Value' => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator CONTAINS',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'CONTAINS',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field' => 'Name',
                        'Operator' => 'CONTAINS',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Number',
                        'Operator' => 'CONTAINS',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Street',
                        'Operator' => 'CONTAINS',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Zip',
                        'Operator' => 'CONTAINS',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'City',
                        'Operator' => 'CONTAINS',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Country',
                        'Operator' => 'CONTAINS',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Url',
                        'Operator' => 'CONTAINS',
                        'Value' => 'Test'
                    }
                ]
            }
        }
    },
    {
        Name         => 'Search: valid search / Field Fulltext / Operator LIKE',
        Search       => {
            Field    => 'Fulltext',
            Operator => 'LIKE',
            Value    => 'Test'
        },
        Expected     => {
            'Search' => {
                'OR' => [
                    {
                        'Field' => 'Name',
                        'Operator' => 'LIKE',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Number',
                        'Operator' => 'LIKE',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Street',
                        'Operator' => 'LIKE',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Zip',
                        'Operator' => 'LIKE',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'City',
                        'Operator' => 'LIKE',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Country',
                        'Operator' => 'LIKE',
                        'Value' => 'Test'
                    },
                    {
                        'Field' => 'Url',
                        'Operator' => 'LIKE',
                        'Value' => 'Test'
                    }
                ]
            }
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

## prepare test organisation ##
my $TestData1 = 'Test001';
my $TestData2 = 'test002';
my $TestData3 = 'Test003';
my $TestData4 = 'Test004';

# first organisation
my $OrganisationID1 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $TestData1,
    Name    => $Helper->GetRandomID(),
    Street  => $Helper->GetRandomID(),
    Zip     => $Helper->GetRandomID(),
    City    => $Helper->GetRandomID(),
    Country => $Helper->GetRandomID(),
    Url     => $Helper->GetRandomID(),
    Comment => $Helper->GetRandomID(),
    UserID  => 1
);
$Self->True(
    $OrganisationID1,
    'Created first organisation'
);
# second organisation
my $OrganisationID2 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    Street  => $TestData2,
    UserID  => 1
);
$Self->True(
    $OrganisationID2,
    'Created second organisation'
);
# third organisation
my $OrganisationID3 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $TestData3,
    Comment => $Helper->GetRandomID(),
    UserID  => 1
);
$Self->True(
    $OrganisationID3,
    'Created third organisation'
);
# fourth organisation
my $OrganisationID4 = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $TestData4,
    Name    => $TestData4,
    UserID  => 1
);
$Self->True(
    $OrganisationID4,
    'Created fourth organisation without optional parameter'
);

# discard ticket object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Organisation'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field Fulltext / Operator STARTSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'STARTSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Fulltext / Operator STARTSWITH / Value substr($TestData2,0,4)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'STARTSWITH',
                    Value    => substr($TestData2,0,4)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Fulltext / Operator ENDSWITH / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'ENDSWITH',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Fulltext / Operator ENDSWITH / Value substr($TestData2,-5)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'ENDSWITH',
                    Value    => substr($TestData2,-5)
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Fulltext / Operator CONTAINS / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'CONTAINS',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    },
    {
        Name     => 'Search: Field Fulltext / Operator CONTAINS / Value substr($TestData2,2,-2)',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'CONTAINS',
                    Value    => substr($TestData2,2,-2)
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2,$OrganisationID3,$OrganisationID4]
    },
    {
        Name     => 'Search: Field Fulltext / Operator LIKE / Value $TestData2',
        Search   => {
            'AND' => [
                {
                    Field    => 'Fulltext',
                    Operator => 'LIKE',
                    Value    => $TestData2
                }
            ]
        },
        Expected => [$OrganisationID2]
    }
);
for my $Test ( @IntegrationSearchTests ) {
    my @Result = $ObjectSearch->Search(
        ObjectType => 'Organisation',
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
