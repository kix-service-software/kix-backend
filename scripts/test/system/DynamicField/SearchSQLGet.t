# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $DBObject        = $Kernel::OM->Get('DB');
my $DFBackendObject = $Kernel::OM->Get('DynamicField::Backend');

my $UserID = 1;

# theres is not really needed to add the dynamic fields for this test, we can define a static
# set of configurations
my %DynamicFieldConfigs = (
    Text => {
        ID            => 123,
        InternalField => 0,
        Name          => 'TextField',
        Label         => 'TextField',
        FieldOrder    => 123,
        FieldType     => 'Text',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue => q{},
            Link         => q{},
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    TextArea => {
        ID            => 123,
        InternalField => 0,
        Name          => 'TextAreaField',
        Label         => 'TextAreaField',
        FieldOrder    => 123,
        FieldType     => 'TextArea',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue => q{},
            Rows         => q{},
            Cols         => q{},
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    Dropdown => {
        ID            => 123,
        InternalField => 0,
        Name          => 'DropdownField',
        Label         => 'DropdownField',
        FieldOrder    => 123,
        FieldType     => 'Multiselect',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue       => q{},
            Link               => q{},
            PossibleNone       => 1,
            TranslatableValues => q{},
            PossibleValues     => {
                1 => 'A',
                2 => 'B',
            },
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    Multiselect => {
        ID            => 123,
        InternalField => 0,
        Name          => 'MultiselectField',
        Label         => 'MultiselectField',
        FieldOrder    => 123,
        FieldType     => 'Multiselect',
        ObjectType    => 'Ticket',
        Config        => {
            CountMax           => 2,
            DefaultValue       => q{},
            PossibleNone       => 1,
            TranslatableValues => q{},
            PossibleValues     => {
                1 => 'A',
                2 => 'B',
            },
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    DateTime => {
        ID            => 123,
        InternalField => 0,
        Name          => 'DateTimeField',
        Label         => 'DateTimeField',
        FieldOrder    => 123,
        FieldType     => 'DateTime',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue  => q{},
            Link          => q{},
            YearsInFuture => q{},
            YearsInPast   => q{},
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
    Date => {
        ID            => 123,
        InternalField => 0,
        Name          => 'DateField',
        Label         => 'DateField',
        FieldOrder    => 123,
        FieldType     => 'Date',
        ObjectType    => 'Ticket',
        Config        => {
            DefaultValue  => q{},
            Link          => q{},
            YearsInFuture => q{},
            YearsInPast   => q{},
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
);

# define tests
my @Tests = (
    {
        Name   => 'No Params',
        Config => undef,
        Silent => 1,
    },
    {
        Name   => 'Empty Config',
        Config => {},
        Silent => 1,
    },
    {
        Name   => 'Missing DynamicFieldConfig',
        Config => {
            DynamicFieldConfig => undef,
        },
        Silent => 1,
    },
    {
        Name   => 'Missing TableAlias',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            TableAlias         => undef,
        },
        Silent => 1,
    },
    {
        Name   => 'Missing Operator',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            TableAlias         => 'dfv',
            Operator           => undef,
        },
        Silent => 1,
    },
    {
        Name   => 'Missing SearchTerm',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            TableAlias         => 'dfv',
            Operator           => 'Equals',
            SearchTerm         => undef,
        },
        Silent => 1,
    },
    {
        Name   => 'Wrong Operator',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            TableAlias         => 'dfv',
            Operator           => 'Equal',
            SearchTerm         => 'Foo',
        },
        Silent => 1,
    },
    {
        Name   => 'Text',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            TableAlias         => 'dfv',
            TestOperators      => {
                Equals            => 'Foo',
                GreaterThan       => 'Foo',
                GreaterThanEquals => 'Foo',
                Like              => '*Foo*', # was Foo* before, but in the BaseText is fixed %<sometext>%
                SmallerThan       => 'Foo',
                SmallerThanEquals => 'Foo',
            },
        },
        ExpectedResult => {
            Equals            => " dfv.value_text = 'Foo' ",
            GreaterThan       => " dfv.value_text > 'Foo' ",
            GreaterThanEquals => " dfv.value_text >= 'Foo' ",
            Like              => {
                ColumnKey => 'dfv.value_text',
            },
            SmallerThan       => " dfv.value_text < 'Foo' ",
            SmallerThanEquals => " dfv.value_text <= 'Foo' ",
        },
    },
    {
        Name   => 'TextArea',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            TableAlias         => 'dfv',
            TestOperators      => {
                Equals            => 'Foo',
                GreaterThan       => 'Foo',
                GreaterThanEquals => 'Foo',
                Like              => '*Foo*', # was Foo* before, but in the BaseText is fixed %<sometext>%
                SmallerThan       => 'Foo',
                SmallerThanEquals => 'Foo',
            },
        },
        ExpectedResult => {
            Equals            => " dfv.value_text = 'Foo' ",
            GreaterThan       => " dfv.value_text > 'Foo' ",
            GreaterThanEquals => " dfv.value_text >= 'Foo' ",
            Like              => {
                ColumnKey => 'dfv.value_text',
            },
            SmallerThan       => " dfv.value_text < 'Foo' ",
            SmallerThanEquals => " dfv.value_text <= 'Foo' ",
        },
    },
    {
        Name   => 'Dropdown',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            TableAlias         => 'dfv',
            TestOperators      => {
                Equals            => 'Foo',
                GreaterThan       => 'Foo',
                GreaterThanEquals => 'Foo',
                Like              => 'Foo*',
                SmallerThan       => 'Foo',
                SmallerThanEquals => 'Foo',
            },
        },
        ExpectedResult => {
            Equals            => " dfv.value_text = 'Foo' ",
            GreaterThan       => " dfv.value_text > 'Foo' ",
            GreaterThanEquals => " dfv.value_text >= 'Foo' ",
            Like              => {
                ColumnKey => 'dfv.value_text',
            },
            SmallerThan       => " dfv.value_text < 'Foo' ",
            SmallerThanEquals => " dfv.value_text <= 'Foo' ",
        },
    },
    {
        Name   => 'Multiselect',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            TableAlias         => 'dfv',
            TestOperators      => {
                Equals            => 'Foo',
                GreaterThan       => 'Foo',
                GreaterThanEquals => 'Foo',
                Like              => 'Foo*',
                SmallerThan       => 'Foo',
                SmallerThanEquals => 'Foo',
            },
        },
        ExpectedResult => {
            Equals            => " dfv.value_text = 'Foo' ",
            GreaterThan       => " dfv.value_text > 'Foo' ",
            GreaterThanEquals => " dfv.value_text >= 'Foo' ",
            Like              => {
                ColumnKey => 'dfv.value_text',
            },
            SmallerThan       => " dfv.value_text < 'Foo' ",
            SmallerThanEquals => " dfv.value_text <= 'Foo' ",
        },
    },
    {
        Name   => 'DateTime',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            TableAlias         => 'dfv',
            TestOperators      => {
                Equals            => '2023-01-01 00:00:00',
                GreaterThan       => '2023-01-01 00:00:00',
                GreaterThanEquals => '2023-01-01 00:00:00',
                Like              => '2023-01-01 00:00:00',
                SmallerThan       => '2023-01-01 00:00:00',
                SmallerThanEquals => '2023-01-01 00:00:00',
            },
        },
        ExpectedResult => {
            Equals            => " dfv.value_date = '2023-01-01 00:00:00' ",
            GreaterThan       => " dfv.value_date > '2023-01-01 00:00:00' ",
            GreaterThanEquals => " dfv.value_date >= '2023-01-01 00:00:00' ",
            Like              => undef,
            SmallerThan       => " dfv.value_date < '2023-01-01 00:00:00' ",
            SmallerThanEquals => " dfv.value_date <= '2023-01-01 00:00:00' ",
        },
        Silent => 1,
    },
    {
        Name   => 'Date',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            TableAlias         => 'dfv',
            TestOperators      => {
                Equals            => '2023-01-01',
                GreaterThan       => '2023-01-01',
                GreaterThanEquals => '2023-01-01',
                Like              => '2023-01-01',
                SmallerThan       => '2023-01-01',
                SmallerThanEquals => '2023-01-01',
            },
        },
        ExpectedResult => {
            Equals            => " dfv.value_date = '2023-01-01 00:00:00' ",
            GreaterThan       => " dfv.value_date > '2023-01-01 00:00:00' ",
            GreaterThanEquals => " dfv.value_date >= '2023-01-01 00:00:00' ",
            Like              => undef,
            SmallerThan       => " dfv.value_date < '2023-01-01 00:00:00' ",
            SmallerThanEquals => " dfv.value_date <= '2023-01-01 00:00:00' ",
        },
        Silent => 1,
    },
);

# execute tests
for my $Test (@Tests) {

    if (
        !IsHashRefWithData( $Test->{Config} )
        || !IsHashRefWithData( $Test->{Config}->{TestOperators} )
    ) {
        my $Result = $DFBackendObject->SearchSQLGet(
            %{ $Test->{Config} },
            Silent => $Test->{Silent} || 0
        );

        $Self->Is(
            $Result,
            undef,
            "$Test->{Name} | SearchSQLGet() (should be undef)",
        );
    }
    else {
        for my $Operator ( sort keys %{ $Test->{Config}->{TestOperators} } ) {

            # define the complete config
            my %Config = (
                %{ $Test->{Config} },
                Operator   => $Operator,
                SearchTerm => $Test->{Config}->{TestOperators}->{$Operator},
            );

            # execute the operation
            my $Result = $DFBackendObject->SearchSQLGet(
                %Config,
                Silent => $Test->{Silent} || 0
            );

            if ( $Operator ne 'Like' || !defined $Test->{ExpectedResult}->{'Like'} ) {
                $Self->Is(
                    $Result,
                    $Test->{ExpectedResult}->{$Operator},
                    "$Test->{Name} | $Operator SearchSQLGet()",
                );
            }
            else {

                # like Operator is very complex and depends on the DB
                my $SQL = $DBObject->QueryCondition(
                    Key   => $Test->{ExpectedResult}->{$Operator}->{ColumnKey},
                    Value => $Config{SearchTerm},
                );
                $Self->Is(
                    $Result,
                    $SQL,
                    "$Test->{Name} | $Operator SearchSQLGet()",
                );
            }
        }
    }
}

# we don't need any cleanup

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
