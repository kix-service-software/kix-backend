# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get dynamic field backend object
my $DFBackendObject = $Kernel::OM->Get('DynamicField::Backend');

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
            CountMax           => 2,
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
    {
        Name   => 'Missing Value Text',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value              => undef,
        },
        ExpectedResults => {
            Value => q{},
            Title => q{},
        },
        Success => 1,
    },
    {
        Name   => 'Missing Value TextArea',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value              => undef,
        },
        ExpectedResults => {
            Value => q{},
            Title => q{},
        },
        Success => 1,
    },
    {
        Name   => 'Missing Value Dropdown',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value              => undef,
        },
        ExpectedResults => {
            Value => q{},
            Title => q{},
        },
        Success => 1,
    },
    {
        Name   => 'Missing Value Multiselect',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value              => undef,
        },
        ExpectedResults => {
            Value => q{},
            Title => q{},
        },
        Success => 1,
    },
    {
        Name   => 'Missing Value Date',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value              => undef,
        },
        ExpectedResults => {
            Value => q{},
            Title => q{},
        },
        Success => 1,
    },
    {
        Name   => 'Missing Value DateTime',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value              => undef,
        },
        ExpectedResults => {
            Value => q{},
            Title => q{},
        },
        Success => 1,
    },
    {
        Name   => 'UTF8 Value Text',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value              => 'ÁäñƱƩ⨅ß',
        },
        ExpectedResults => {
            Value => 'ÁäñƱƩ⨅ß',
            Title => 'ÁäñƱƩ⨅ß',
        },
        Success => 1,
    },
    {
        Name   => 'UTF8 Value TextArea',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value              => 'Line1\nÁäñƱƩ⨅ß\nLine3',
        },
        ExpectedResults => {
            Value => 'Line1\nÁäñƱƩ⨅ß\nLine3',
            Title => 'Line1\nÁäñƱƩ⨅ß\nLine3',
        },
        Success => 1,
    },
    {
        Name   => 'Long Value Dropdown',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value              => 'Looooooooooooooooooooooooooooong',
        },
        ExpectedResults => {
            Value => 'Looooooooooooooooooooooooooooong',
            Title => 'Looooooooooooooooooooooooooooong',
        },
        Success => 1,
    },
    {
        Name   => 'Single Value Multiselect',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value              => 'Value1',
        },
        ExpectedResults => {
            Value => 'Value1',
            Title => 'Value1',
        },
        Success => 1,
    },
    {
        Name   => 'Multiple Values Multiselect',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value              => [ 'Value1', 'Value2' ],
        },
        ExpectedResults => {
            Value => 'Value1, Value2',
            Title => 'Value1, Value2',
        },
        Success => 1,
    },
    {
        Name   => 'Correct Date Value Date',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value              => '1977-12-12',
        },
        ExpectedResults => {
            Value => '1977-12-12',
            Title => '1977-12-12',
        },
        Success => 1,
    },
    {
        Name   => 'Incorrect Date Value Date',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Date},
            Value              => '2013-02-31 05:00:00',
        },
        ExpectedResults => {
            Value => '2013-02-31 00:00:00',
            Title => '2013-02-31 00:00:00',
        },
        Success => 0,
    },
    {
        Name   => 'Correct DateTime Value DateTime',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value              => '1977-12-12 12::59:32',
        },
        ExpectedResults => {
            Value => '1977-12-12 12::59:32',
            Title => '1977-12-12 12::59:32',
        },
        Success => 1,
    },
    {
        Name   => 'Incorrect Date Value DateTime',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{DateTime},
            Value              => '2013-02-31 56:00:28',
        },
        ExpectedResults => {
            Value => '2013-02-31 56:00:28',
            Title => '2013-02-31 56:00:28',
        },
        Success => 1,
    },
    {
        Name   => 'UTF8 Value Text (reduced)',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Text},
            Value              => 'ÁäñƱƩ⨅ß',
            ValueMaxChars      => 2,
            TitleMaxChars      => 4,
        },
        ExpectedResults => {
            Value => 'Áä...',
            Title => 'ÁäñƱ...',
        },
        Success => 1,
    },
    {
        Name   => 'UTF8 Value TextArea (reduced)',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{TextArea},
            Value              => 'Line1\nÁäñƱƩ⨅ß\nLine3',
            ValueMaxChars      => 2,
            TitleMaxChars      => 4,
        },
        ExpectedResults => {
            Value => 'Li...',
            Title => 'Line...',
        },
        Success => 1,
    },
    {
        Name   => 'Long Value Dropdown (reduced)',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
            Value              => 'Looooooooooooooooooooooooooooong',
            ValueMaxChars      => 2,
            TitleMaxChars      => 4,
        },
        ExpectedResults => {
            Value => 'Lo...',
            Title => 'Looo...',
        },
        Success => 1,
    },
    {
        Name   => 'Single Value Multiselect (reduced)',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value              => 'Value1',
            ValueMaxChars      => 2,
            TitleMaxChars      => 4,
        },
        ExpectedResults => {
            Value => 'Va...',
            Title => 'Valu...',
        },
        Success => 1,
    },
    {
        Name   => 'Multiple Values Multiselect (reduced)',
        Config => {
            DynamicFieldConfig => $DynamicFieldConfigs{Multiselect},
            Value              => [ 'Value1', 'Value2' ],
            ValueMaxChars      => 2,
            TitleMaxChars      => 4,
        },
        ExpectedResults => {
            Value => 'Va...',
            Title => 'Valu...',
        },
        Success => 1,
    },
);

# execute tests
for my $Test (@Tests) {

    my $ValueStrg = $DFBackendObject->ReadableValueRender(
        %{ $Test->{Config} },
        Silent => $Test->{Silent} || 0
    );

    if ( $Test->{Success} ) {
        $Self->IsDeeply(
            $ValueStrg,
            $Test->{ExpectedResults},
            "$Test->{Name} | ReadableValueRender()",
        );
    }
    else {
        if ( ref $Test->{ExpectedResults} eq 'HASH' ) {
            $Self->IsNotDeeply(
                $ValueStrg,
                $Test->{ExpectedResults},
                "$Test->{Name} | ReadableValueRender() is not similiar",
            );
        }
        else {
            $Self->Is(
                $ValueStrg,
                undef,
                "$Test->{Name} | ReadableValueRender() should be undef",
            );
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
