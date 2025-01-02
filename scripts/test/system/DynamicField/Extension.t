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

# get config object
## IMPORTANT - First get DynamicField::Backend object,
## or it will not use the same config object as the test somehow
my $DFBackendObject = $Kernel::OM->Get('DynamicField::Backend');
my $ConfigObject    = $Kernel::OM->Get('Config');

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
            DefaultValue => '',
            Link         => '',
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
            DefaultValue => '',
            Rows         => '',
            Cols         => '',
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
            DefaultValue       => '',
            PossibleNone       => 1,
            TranslatableValues => '',
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
            DefaultValue  => '',
            Link          => '',
            YearsInFuture => '',
            YearsInPast   => '',
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
            DefaultValue  => '',
            Link          => '',
            YearsInFuture => '',
            YearsInPast   => '',
        },
        ValidID    => 1,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-06-11 17:22:00',
    },
);

# add dynamic field registration settings to the new config object
$ConfigObject->Set(
    Key   => 'DynamicFields::Extension::Backend###100-DFDummy',
    Value => {
        Module => 'scripts::test::system::sample::DynamicField::DummyBackend',
    },
);

$ConfigObject->Set(
    Key   => 'DynamicFields::Extension::Driver::Text###100-DFDummy',
    Value => {
        Module     => 'scripts::test::system::sample::DynamicField::Driver::DummyText',
        Properties => {
            Dummy1 => 1,
        },
    },
);
$ConfigObject->Set(
    Key   => 'DynamicFields::Extension::Driver::TextArea###100-DFDummy',
    Value => {
        Module     => 'scripts::test::system::sample::DynamicField::Driver::DummyTextArea',
        Properties => {
            Dummy1 => 1,
        },
    },
);
$ConfigObject->Set(
    Key   => 'DynamicFields::Extension::Driver::Multiselect###100-DFDummy',
    Value => {
        Module     => 'scripts::test::system::sample::DynamicField::Driver::DummyMultiselect',
        Properties => {
            Dummy2 => 1,
        },
    },
);
$ConfigObject->Set(
    Key   => 'DynamicFields::Extension::Driver::Date###100-DFDummy',
    Value => {
        Module     => 'scripts::test::system::sample::DynamicField::Driver::DummyDate',
        Properties => {
        },
    },
);
$ConfigObject->Set(
    Key   => 'DynamicFields::Extension::Driver::DateTime###100-DFDummy',
    Value => {
        Module => 'scripts::test::system::sample::DynamicField::Driver::DummyDateTime',
    },
);

# Make sure that the TicketObject gets recreated for each loop.
$Kernel::OM->ObjectsDiscard( Objects => ['DynamicField::Backend'] );

# get a new backend object including the extension registrations from the config object
$DFBackendObject = $Kernel::OM->Get('DynamicField::Backend');

my @Behaviors = (qw(Dummy1 Dummy2));
my %Functions = (
    Dummy1 => ['DummyFunction1'],
    Dummy2 => ['DummyFunction2'],
);

# define tests
my @Tests = (
    {
        Name   => 'Dynamic Field Text',
        Config => {
            FieldConfig => $DynamicFieldConfigs{Text},
        },
        ExpectedResutls => {
            Functions => {
                DummyFunction1 => 1,
                DummyFunction2 => undef,
            },
            Behaviors => {
                Dummy1 => 1,
                Dummy2 => undef,
            },
        },
    },
    {
        Name   => 'Dynamic Field TextArea',
        Config => {
            FieldConfig => $DynamicFieldConfigs{TextArea},
        },
        ExpectedResutls => {
            Functions => {
                DummyFunction1 => 'TextArea',
                DummyFunction2 => undef,
            },
            Behaviors => {
                Dummy1 => 1,
                Dummy2 => undef,
            },
        },
    },
    {
        Name   => 'Dynamic Field Multiselect',
        Config => {
            FieldConfig => $DynamicFieldConfigs{Multiselect},
        },
        ExpectedResutls => {
            Functions => {
                DummyFunction1 => undef,
                DummyFunction2 => 'Multiselect',
            },
            Behaviors => {
                Dummy1 => undef,
                Dummy2 => 1,
            },
        },
    },
    {
        Name   => 'Dyanmic Field Multiselect',
        Config => {
            FieldConfig => $DynamicFieldConfigs{Multiselect},
        },
        ExpectedResutls => {
            Functions => {
                DummyFunction1 => undef,
                DummyFunction2 => 'Multiselect',
            },
            Behaviors => {
                Dummy1 => undef,
                Dummy2 => 1,
            },
        },
    },
    {
        Name   => 'Dynamic Field Date',
        Config => {
            FieldConfig => $DynamicFieldConfigs{Date},
        },
        ExpectedResutls => {
            Functions => {
                DummyFunction1 => 1,
                DummyFunction2 => 1,
            },
            Behaviors => {
                Dummy1 => undef,
                Dummy2 => undef,
            },
        },
    },
    {
        Name   => 'Dynamic Field DateTime',
        Config => {
            FieldConfig => $DynamicFieldConfigs{DateTime},
        },
        ExpectedResutls => {
            Functions => {
                DummyFunction1 => 'DateTime',
                DummyFunction2 => 'DynamicField',
            },
            Behaviors => {
                Dummy1 => undef,
                Dummy2 => undef,
            },
        },
    },
);

# execute tests
for my $Test (@Tests) {
    for my $Property (@Behaviors) {
        my $GetPropertyResult = $DFBackendObject->GetProperty(
            DynamicFieldConfig => $Test->{Config}->{FieldConfig},
            Property           => $Property,
        );

        $Self->Is(
            $GetPropertyResult,
            $Test->{ExpectedResutls}->{Behaviors}->{$Property},
            "$Test->{Name} GetProperty $Property",
        );
        for my $FunctionName ( @{ $Functions{$Property} } ) {
            my $FunctionResult = $DFBackendObject->$FunctionName(
                DynamicFieldConfig => $Test->{Config}->{FieldConfig},
            );

            $Self->Is(
                $FunctionResult,
                $Test->{ExpectedResutls}->{Functions}->{$FunctionName},
                "$Test->{Name} Function $FunctionName",
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
