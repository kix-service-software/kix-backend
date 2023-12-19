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
        Name           => 'No Params',
        Config         => undef,
        Silent         => 1,
        ExpectedResult => undef
    },
    {
        Name           => 'Empty Config',
        Config         => {},
        Silent         => 1,
        ExpectedResult => undef
    },
    {
        Name   => 'Missing DynamicFieldConfig',
        Config => {
            DynamicFieldConfig => undef,
        },
        Silent => 1,
        ExpectedResult => undef
    },
    {
        Name   => 'Missing TableAlias',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            TableAlias         => undef,
        },
        Silent => 1,
        ExpectedResult => undef
    },
    {
        Name   => 'Text',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            TableAlias         => 'dfv',
        },
        ExpectedResult => {
            Column => "dfv.value_text"
        }
    },
    {
        Name   => 'TextArea',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            TableAlias         => 'dfv',
        },
        ExpectedResult => {
            Column => "dfv.value_text"
        }
    },
    {
        Name   => 'Multiselect',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            TableAlias         => 'dfv',
        },
        ExpectedResult => {
            Column => "dfv.value_text"
        }
    },
    {
        Name   => 'DateTime',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            TableAlias         => 'dfv',
        },
        ExpectedResult => {
            Column => "dfv.value_date"
        },
        Silent => 1,
    },
    {
        Name   => 'Date',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            TableAlias         => 'dfv',
        },
        ExpectedResult => {
            Column => "dfv.value_date"
        },
        Silent => 1,
    }
);

# execute tests
for my $Test (@Tests) {

    if ( !IsHashRefWithData( $Test->{Config} ) ) {
        my $Result = $Kernel::OM->Get('DynamicField::Backend')->SearchSQLSearchFieldGet(
            %{ $Test->{Config} },
            Silent => $Test->{Silent} || 0
        );

        $Self->Is(
            $Result,
            $Test->{ExpectedResult},
            "$Test->{Name} | SearchSQLSearchFieldGet() (should be undef)",
        );
    }
    else {
        my $Result = $Kernel::OM->Get('DynamicField::Backend')->SearchSQLSearchFieldGet(
            %{ $Test->{Config} },
            Silent => $Test->{Silent} || 0
        );

        $Self->IsDeeply(
            $Result,
            $Test->{ExpectedResult},
            "$Test->{Name} | SearchSQLSearchFieldGet()",
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
