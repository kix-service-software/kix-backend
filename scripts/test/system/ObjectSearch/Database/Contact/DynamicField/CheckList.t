# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

my $AttributeModule = 'Kernel::System::ObjectSearch::Database::Contact::DynamicField';
my $FieldType       = 'CheckList';

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
    ObjectType    => 'Contact',
    Config        => {},
    ValidID       => 1,
    UserID        => 1,
);
$Self->True(
    $DynamicFieldID,
    'Created dynamic field for UnitTest'
);

# check GetSupportedAttributes
my $AttributeList = $AttributeObject->GetSupportedAttributes();
$Self->IsDeeply(
    $AttributeList->{'DynamicField_UnitTest'},
    {
        IsSearchable => 0,
        IsSortable   => 0,
        Operators    => [],
        ValueType    => ''
    },
    'GetSupportedAttributes provides expected data'
);

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
# test Search
# attributes of this backend are not searchable

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
