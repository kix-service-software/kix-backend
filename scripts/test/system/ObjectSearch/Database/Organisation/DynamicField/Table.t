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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Organisation::DynamicField';
my $FieldType       = 'Table';

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

# create dynamic field for unit test
my $DynamicFieldID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
    InternalField => 0,
    Name          => 'UnitTest',
    Label         => 'UnitTest',
    FieldType     => $FieldType,
    ObjectType    => 'Organisation',
    Config        => {},
    ValidID       => 1,
    UserID        => 1,
);
$Self->True(
    $DynamicFieldID,
    'Created dynamic field for UnitTest'
);
my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
    ID => $DynamicFieldID
);

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList->{'DynamicField_UnitTest'},
    {
        IsSearchable => 1,
        IsSortable   => 0,
        Operators    => ['EMPTY'],
        ValueType    => ''
    },
    'GetSupportedAttributes provides expected data'
);

# check Search
# check Search
my @SearchTests = (
    {
        Name     => 'Search: undef search',
        Search   => undef,
        Expected => undef
    },
    {
        Name     => 'Search: Value undef',
        Search   => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EQ',
            Value    => undef

        },
        Expected => undef
    },
    {
        Name     => 'Search: Value invalid',
        Search   => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EQ',
            Value    => 'Test'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Field undef',
        Search   => {
            Field    => undef,
            Operator => 'EQ',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Field invalid',
        Search   => {
            Field    => 'Test',
            Operator => 'EQ',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Operator undef',
        Search   => {
            Field    => 'DynamicField_UnitTest',
            Operator => undef,
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name     => 'Search: Operator invalid',
        Search   => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'Test',
            Value    => '1'
        },
        Expected => undef
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator EMPTY / Value 0',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EMPTY',
            Value    => 0
        },
        Expected     => {
            'IsRelative' => undef,
            'Join'       => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where'      => [
                '(dfv_left0.value_text != \'\' AND dfv_left0.value_text IS NOT NULL)'
            ]
        }
    },
    {
        Name         => 'Search: valid search / Field DynamicField_UnitTest / Operator EMPTY / Value 1',
        Search       => {
            Field    => 'DynamicField_UnitTest',
            Operator => 'EMPTY',
            Value    => 1
        },
        Expected     => {
            'IsRelative' => undef,
            'Join'       => [
                'LEFT OUTER JOIN dynamic_field_value dfv_left0 ON dfv_left0.object_id = o.id AND dfv_left0.field_id = ' . $DynamicFieldID
            ],
            'Where'      => [
                '(dfv_left0.value_text = \'\' OR dfv_left0.value_text IS NULL)'
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
        Name      => 'Sort: Attribute "DynamicField_UnitTest"',
        Attribute => 'DynamicField_UnitTest',
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

## prepare test organisations ##
# first organisation
my $OrganisationID1   = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID1,
    'Created first organisation'
);
my $ValueSet1 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $OrganisationID1,
    Value              => 'Test1',
    UserID             => 1,
);
$Self->True(
    $ValueSet1,
    'Dynamic field value set for first organisation'
);
# second organisation
my $OrganisationID2   = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID2,
    'Created second organisation'
);
my $ValueSet2 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $OrganisationID2,
    Value              => 'Test2',
    UserID             => 1,
);
$Self->True(
    $ValueSet2,
    'Dynamic field value set for first organisation'
);
# third organisation
my $OrganisationID3   = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $Helper->GetRandomID(),
    Name    => $Helper->GetRandomID(),
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $OrganisationID3,
    'Created third organisation without df value'
);

# discard organisation object to process events
$Kernel::OM->ObjectsDiscard(
    Objects => ['Organisation'],
);

# test Search
my @IntegrationSearchTests = (
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator EMPTY / Value 1',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EMPTY',
                    Value    => 1
                }
            ]
        },
        Expected => ['1',$OrganisationID3]
    },
    {
        Name     => 'Search: Field DynamicField_UnitTest / Operator EMPTY / Value 0',
        Search   => {
            'AND' => [
                {
                    Field    => 'DynamicField_UnitTest',
                    Operator => 'EMPTY',
                    Value    => 0
                }
            ]
        },
        Expected => [$OrganisationID1,$OrganisationID2]
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
