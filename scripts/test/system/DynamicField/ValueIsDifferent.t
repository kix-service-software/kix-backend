# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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

# get dynamic field backend object
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
            DefaultValue => 'Default',
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
            DefaultValue => "Multi\nLine",
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
            DefaultValue       => 2,
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
            DefaultValue       => 2,
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
            DefaultValue  => '2013-08-21 16:45:00',
            Link          => q{},
            YearsInFuture => '5',
            YearsInPast   => '5',
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
            DefaultValue  => '2013-08-21 00:00:00',
            Link          => q{},
            YearsInFuture => '5',
            YearsInPast   => '5',
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
);

# define tests
my @Tests = (
    {
        Name    => 'No Params',
        Config  => undef,
        Success => 0,
        Silent  => 1
    },

    {
        Name    => 'Empty Config',
        Config  => {},
        Success => 0,
        Silent  => 1
    },
    {
        Name   => 'Missing DynamicFieldConfig',
        Config => {
            DynamicFieldConfig => undef,
        },
        Success => 0,
        Silent  => 1
    },

    # Dynamic Field Text
    {
        Name   => 'Text: Value1 undef, Value2 empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => undef,
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'Text: Value1 undef, Value2 array with empty string',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => undef,
            Value2             => [''],
        },
        Success => 1,
    },
    {
        Name   => 'Text: Value1 empty, Value2 undef',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => q{},
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'Text: Value1 array with empty string, Value2 undef',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => [''],
            Value2             => undef,
        },
        Success => 1,
    },
    {
        Name   => 'Text: Both undefs',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => undef,
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'Text: Both empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => q{},
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'Text: Both equals',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => 'abcde',
            Value2             => 'abcde',
        },
        Success => 0,
    },
    {
        Name   => 'Text: Both equals utf8',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => 'äëïöüÄËÏÖÜáéíóúÁÉÍÓÚñÑ€исß',
            Value2             => 'äëïöüÄËÏÖÜáéíóúÁÉÍÓÚñÑ€исß',
        },
        Success => 0,
    },
    {
        Name   => 'Text: Different case',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => 'A',
            Value2             => 'a',
        },
        Success => 1,
    },
    {
        Name   => 'Text: Different using utf8',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => 'a',
            Value2             => 'á',
        },
        Success => 1,
    },
    {
        Name   => 'Text: Different using utf8 (both)',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value1             => 'ä',
            Value2             => 'á',
        },
        Success => 1,
    },

    # Dynamic Field TextArea
    {
        Name   => 'TextArea: Value1 undef, Value2 empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => undef,
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'TextArea: Value1 undef, Value2 array with empty string',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => undef,
            Value2             => [''],
        },
        Success => 1,
    },
    {
        Name   => 'TextArea: Value1 empty, Value2 undef',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => q{},
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'TextArea: Value1 array with empty string, Value2 undef',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             =>  [''],
            Value2             => undef,
        },
        Success => 1,
    },
    {
        Name   => 'TextArea: Both undefs',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => undef,
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'TextArea: Both empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => q{},
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'TextArea: Both equals',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => 'abcde',
            Value2             => 'abcde',
        },
        Success => 0,
    },
    {
        Name   => 'TextArea: Both equals utf8',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => 'äëïöüÄËÏÖÜáéíóúÁÉÍÓÚñÑ€исß',
            Value2             => 'äëïöüÄËÏÖÜáéíóúÁÉÍÓÚñÑ€исß',
        },
        Success => 0,
    },
    {
        Name   => 'TextArea: Different case',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => 'A',
            Value2             => 'a',
        },
        Success => 1,
    },
    {
        Name   => 'TextArea: Different using utf8',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => 'a',
            Value2             => 'á',
        },
        Success => 1,
    },
    {
        Name   => 'TextArea: Different using utf8 (both)',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => 'ä',
            Value2             => 'á',
        },
        Success => 1,
    },
    {
        Name   => 'TextArea: Different mutiline',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => 'This is a multiline\ntext',
            Value2             => 'This is a multiline\nentry',
        },
        Success => 1,
    },
    {
        Name   => 'TextArea: Same mutiline',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value1             => 'This is a multiline\ntext',
            Value2             => 'This is a multiline\ntext',
        },
        Success => 0,
    },

    # Dynamic Field Dropdown (Multiselect as single selection)
    {
        Name   => 'Dropdown: Value1 undef, Value2 empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value1             => undef,
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'Dropdown: Value1 empty, Value2 undef',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value1             => q{},
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'Dropdown: Both undefs',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value1             => undef,
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'Dropdown: Both empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value1             => q{},
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'Dropdown: Both equals',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value1             => 'abcde',
            Value2             => 'abcde',
        },
        Success => 0,
    },
    {
        Name   => 'Dropdown: Both equals utf8',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value1             => 'äëïöüÄËÏÖÜáéíóúÁÉÍÓÚñÑ€исß',
            Value2             => 'äëïöüÄËÏÖÜáéíóúÁÉÍÓÚñÑ€исß',
        },
        Success => 0,
    },
    {
        Name   => 'Dropdown: Different case',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value1             => 'A',
            Value2             => 'a',
        },
        Success => 1,
    },
    {
        Name   => 'Dropdown: Different using utf8',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value1             => 'a',
            Value2             => 'á',
        },
        Success => 1,
    },
    {
        Name   => 'Dropdown: Different using utf8 (both)',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value1             => 'ä',
            Value2             => 'á',
        },
        Success => 1,
    },

    # Dynamic Field Multiselect
    {
        Name   => 'Multiselect: Value1 undef, Value2 empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => undef,
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Value1 empty, Value2 undef',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => q{},
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Value1 undef, Value2 empty array',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => undef,
            Value2             => [],
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Value1 empty array, Value2 undef',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => [],
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Both undefs',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => undef,
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Both empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => q{},
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Both empty arrays',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => [],
            Value2             => [],
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Both equals',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => 'abcde',
            Value2             => 'abcde',
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Both equals utf8',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => 'äëïöüÄËÏÖÜáéíóúÁÉÍÓÚñÑ€исß',
            Value2             => 'äëïöüÄËÏÖÜáéíóúÁÉÍÓÚñÑ€исß',
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Different case',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => 'A',
            Value2             => 'a',
        },
        Success => 1,
    },
    {
        Name   => 'Multiselect: Different using utf8',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => 'a',
            Value2             => 'á',
        },
        Success => 1,
    },
    {
        Name   => 'Multiselect: Different using utf8 (both)',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => 'ä',
            Value2             => 'á',
        },
        Success => 1,
    },
    {
        Name   => 'Multiselect: Both equal arrays',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => ['abcde'],
            Value2             => ['abcde'],
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Both equals utf8 arrays',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => ['äëïöüÄËÏÖÜáéíóúÁÉÍÓÚñÑ€исß'],
            Value2             => ['äëïöüÄËÏÖÜáéíóúÁÉÍÓÚñÑ€исß'],
        },
        Success => 0,
    },
    {
        Name   => 'Multiselect: Different case arrays',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => ['A'],
            Value2             => ['a'],
        },
        Success => 1,
    },
    {
        Name   => 'Multiselect: Different using utf8 arrays',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => ['a'],
            Value2             => ['á'],
        },
        Success => 1,
    },
    {
        Name   => 'Multiselect: Different using utf8 (both) arrays',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => ['ä'],
            Value2             => ['á'],
        },
        Success => 1,
    },
    {
        Name   => 'Multiselect: Different order arrays',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => [ 'A', 'B', ],
            Value2             => [ 'B', 'A', ],
        },
        Success => 1,
    },
    {
        Name   => 'Multiselect: Same arrays',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value1             => [ 'A', 'B', ],
            Value2             => [ 'A', 'B', ],
        },
        Success => 0,
    },

    # Dynamic Field DateTime
    {
        Name   => 'DateTime: Value1 undef, Value2 empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value1             => undef,
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'DateTime: Value1 empty, Value2 undef',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value1             => q{},
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'DateTime: Both undefs',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value1             => undef,
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'DateTime: Both empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value1             => q{},
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'DateTime: Both equals',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value1             => '2013-08-21 16:45:00',
            Value2             => '2013-08-21 16:45:00',
        },
        Success => 0,
    },
    {
        Name   => 'DateTime: Different date/time',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value1             => '2013-08-21 16:45:00',
            Value2             => '2013-08-21 16:45:01',
            ,
        },
        Success => 1,
    },

    # Dynamic Field Date
    {
        Name   => 'Date: Value1 undef, Value2 empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value1             => undef,
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'Date: Value1 empty, Value2 undef',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value1             => q{},
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'Date: Both undefs',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value1             => undef,
            Value2             => undef,
        },
        Success => 0,
    },
    {
        Name   => 'Date: Both empty',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value1             => q{},
            Value2             => q{},
        },
        Success => 0,
    },
    {
        Name   => 'Date: Both equals',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value1             => '2013-08-21 00:00:00',
            Value2             => '2013-08-21 00:00:00',
        },
        Success => 0,
    },
    {
        Name   => 'Date: Different date/time',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value1             => '2013-08-21 00:00:00',
            Value2             => '2013-08-22 00:00:00',
            ,
        },
        Success => 1,
    },

);

# execute tests
for my $Test (@Tests) {

    my $Result = $DFBackendObject->ValueIsDifferent(
        %{ $Test->{Config} },
        Silent => $Test->{Silent} || 0
    );

    if ( $Test->{Success} ) {
        $Self->True(
            $Result,
            "$Test->{Name} | ValueIsDifferent() with true",
        );
    }
    else {
        $Self->Is(
            $Result,
            undef,
            "$Test->{Name} | ValueIsDifferent() (should be undef)",
        );
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
