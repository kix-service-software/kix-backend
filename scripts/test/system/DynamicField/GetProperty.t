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
            PossibleNone       => q{},
            TranslatableValues => q{},
            PossibleValues     => {
                A => 'A',
                B => 'B',
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
            PossibleNone       => q{},
            TranslatableValues => q{},
            PossibleValues     => {
                A => 'A',
                B => 'B',
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
        Name    => 'No Params',
        Config  => undef,
        Success => 0,
        Silent  => 1,
    },
    {
        Name    => 'Empty Config',
        Config  => {},
        Success => 0,
        Silent  => 1,
    },
    {
        Name    => 'Missing DynamicFieldConfig',
        Config  => {
            DynamicFieldConfig => undef,
        },
        Success => 0,
        Silent  => 1,
    },
    {
        Name   => 'DynamicField Text',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
        },
        ExpectedResults => {
            'IsSearchable'    => 1,
            'IsSortable'      => 1,
            'SearchOperators' => ['EQ','GT','GTE','LT','LTE','LIKE','STARTSWITH','ENDSWITH']
        },
        Success => 1,
    },
    {
        Name   => 'DynamicField Text Area',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
        },
        ExpectedResults => {
            'IsSearchable'    => 1,
            'IsSortable'      => 1,
            'SearchOperators' => ['EQ','GT','GTE','LT','LTE','LIKE','STARTSWITH','ENDSWITH']
        },
        Success => 1,
    },
    {
        Name   => 'DynamicField Dropdown',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
        },
        ExpectedResults => {
            'IsSearchable'    => 1,
            'IsSortable'      => 1,
            'SearchOperators' => ['EQ','GT','GTE','LT','LTE','LIKE']
        },
        Success => 1,
    },
    {
        Name   => 'DynamicField Multiselect',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
        },
        ExpectedResults => {
            'IsSearchable'    => 1,
            'IsSortable'      => 1,
            'SearchOperators' => ['EQ','GT','GTE','LT','LTE','LIKE']
        },
        Success => 1,
    },
    {
        Name   => 'DynamicField DateTime',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
        },
        ExpectedResults => {
            'IsSearchable'    => 1,
            'IsSortable'      => 1,
            'SearchOperators' => ['EQ','GT','GTE','LT','LTE'],
            'SearchValueType' => 'DATETIME'
        },
        Success => 1,
    },
    {
        Name   => 'DynamicField Date',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
        },
        ExpectedResults => {
            'IsSearchable'    => 1,
            'IsSortable'      => 1,
            'SearchOperators' => ['EQ','GT','GTE','LT','LTE'],
            'SearchValueType' => 'DATE'
        },
        Success => 1,
    },
);

# execute tests
for my $Test (@Tests) {

    # set known behaviors
    BEHAVIOR:
    for my $Property (
        qw(
            IsSearchable IsSortable SearchOperators SearchValueType
            NotExisting
        )
    ) {

        # to store the config (also for each behavior)
        my %Config;

        # add the behavior if there is a config where to add it.
        if ( IsHashRefWithData( $Test->{Config} ) ) {
            %Config = (
                %{ $Test->{Config} },
                Property => $Property,
            );
        }

        # call GetProperty for each test for each known behavior
        my $Success = $Kernel::OM->Get('DynamicField::Backend')->GetProperty(
            %Config,
            Silent => $Test->{Silent},
        );

        # if the test is a success then check the expected results with true
        if ($Success) {
            $Self->True(
                $Test->{ExpectedResults}->{$Property},
                "$Test->{Name} GetProperty() for $Property executed with True",
            );
        }

        # otherwise if there is a DynamicField config check the expected results with false
        else {
            if ( $Test->{Success} ) {
                $Self->False(
                    $Test->{ExpectedResults}->{$Property},
                    "$Test->{Name} GetProperty() for $Property executed with False",
                );
            }

            # if there is no DynamicField config, then it should fail, don't need further checks
            else {
                $Self->True(
                    1,
                    "$Test->{Name} GetProperty() Should not run on missing configuration",
                );

                # if the tests supposed to fail due to missing essential configuration there is no
                # need to keep testing with other behaviors
                last BEHAVIOR;
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
