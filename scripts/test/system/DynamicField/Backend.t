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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');
$Helper->BeginWork();

# get needed objects
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $BackendObject      = $Kernel::OM->Get('DynamicField::Backend');
my $TicketObject       = $Kernel::OM->Get('Ticket');

# define needed variable
my $RandomID = $Helper->GetRandomNumber();

# create a ticket
my $TicketID = $TicketObject->TicketCreate(
    Title          => 'Some Ticket Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'new',
    OrganisationID => '123465',
    Contact        => 'customer@example.com',
    OwnerID        => 1,
    UserID         => 1,
);

# sanity check
$Self->True(
    $TicketID,
    "TicketCreate() successful for Ticket ID $TicketID",
);

# create a dynamic field
my $DynamicFieldName = "dynamicfieldtest$RandomID";
my $FieldID          = $DynamicFieldObject->DynamicFieldAdd(
    Name       => $DynamicFieldName,
    Label      => 'a description',
    FieldOrder => 9991,
    FieldType  => 'Text',
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue => 'a value',
    },
    ValidID => 1,
    UserID  => 1,
);

my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
    ID => $FieldID,
);

# sanity check
$Self->True(
    $FieldID,
    "DynamicFieldAdd() successful for Field ID $FieldID",
);

# get the Dynamic Fields configuration
my $DynamicFieldsConfig = $Kernel::OM->Get('Config')->Get('DynamicFields::Driver');

# sanity check
$Self->Is(
    ref $DynamicFieldsConfig,
    'HASH',
    'Dynamic Field confguration',
);
$Self->IsNotDeeply(
    $DynamicFieldsConfig,
    {},
    'Dynamic Field confguration is not empty',
);

$Self->True(
    $BackendObject,
    'Backend object was created',
);

$Self->Is(
    ref $BackendObject,
    'Kernel::System::DynamicField::Backend',
    'Backend object was created successfuly',
);

# check all registered backend delegates
for my $FieldType ( sort keys %{$DynamicFieldsConfig} ) {
    $Self->True(
        $BackendObject->{ 'DynamicField' . $FieldType . 'Object' },
        "Backend delegate for field type $FieldType was created",
    );

    $Self->Is(
        ref $BackendObject->{ 'DynamicField' . $FieldType . 'Object' },
        $DynamicFieldsConfig->{$FieldType}->{Module},
        "Backend delegate for field type $FieldType was created successfuly",
    );
}

my @Tests = (
    {
        Name      => 'No DynamicFieldConfig',
        ObjectID  => $TicketID,
        UserID    => 1,
        Success   => 0,
        ShouldGet => 0,
        Silent    => 1
    },
    {
        Name               => 'No ObjectID',
        DynamicFieldConfig => {
            ID         => -1,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
        },
        UserID    => 1,
        Success   => 0,
        ShouldGet => 0,
        Silent    => 1
    },
    {
        Name               => 'Invalid DynamicFieldConfig',
        DynamicFieldConfig => {},
        ObjectID           => $TicketID,
        UserID             => 1,
        Success            => 0,
        ShouldGet          => 0,
        Silent             => 1
    },
    {
        Name               => 'No ID',
        DynamicFieldConfig => {
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
        },
        ObjectID  => $TicketID,
        UserID    => 1,
        Success   => 0,
        ShouldGet => 0,
        Silent    => 1
    },
    {
        Name               => 'No UserID',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Text',
        },
        ObjectID  => $TicketID,
        Success   => 0,
        ShouldGet => 0,
        Silent    => 1
    },
    {
        Name               => 'Non Existing Backend',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'NonExistingBackend',
        },
        ObjectID  => $TicketID,
        Value     => 'a text',
        UserID    => 1,
        Success   => 0,
        ShouldGet => 0,
        Silent    => 1
    },

    {
        Name               => 'Multiselect - No PossibleValues',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Multiselect',
        },
        ObjectID  => $TicketID,
        Value     => 'a text',
        UserID    => 1,
        Success   => 0,
        ShouldGet => 0,
        Silent    => 1
    },
    {
        Name               => 'Multiselect - Invalid PossibleValues',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Multiselect',
            Config     => {
                PossibleValues => q{},
            }
        },
        ObjectID  => $TicketID,
        Value     => 'a text',
        UserID    => 1,
        Success   => 0,
        ShouldGet => 0,
        Silent    => 1
    },

    {
        Name               => 'Set Text Value',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Text',
        },
        ObjectID  => $TicketID,
        Value     => ['a text'],
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
    },
    {
        Name               => 'Set Text Value - empty',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Text',
        },
        ObjectID  => $TicketID,
        Value     => q{},
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
    },
    {
        Name               => 'Set Text Value - unicode',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Text',
        },
        ObjectID  => $TicketID,
        Value     => ['äöüßÄÖÜ€ис'],
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
    },
    {
        Name               => 'Set TextArea Value',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'TextArea',
        },
        ObjectID  => $TicketID,
        Value     => ['a text'],
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
    },
    {
        Name               => 'Set TextArea Value - empty',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'TextArea',
        },
        ObjectID  => $TicketID,
        Value     => q{},
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
    },
    {
        Name               => 'Set TextArea Value - unicode',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'TextArea',
        },
        ObjectID  => $TicketID,
        Value     => ['äöüßÄÖÜ€ис'],
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
    },
    {
        Name               => 'Set DateTime Value',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'DateTime',
        },
        ObjectID  => $TicketID,
        Value     => ['2011-01-01 01:01:01'],
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
    },

    # options validation are now just on the frontend then this test should be successful
    {
        Name               => 'Multiselect - Invalid Option',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Multiselect',
            Config     => {
                PossibleValues => {
                    Key1 => 'Value1',
                    Key2 => 'Value2',
                    Key3 => 'Value3',
                },
            },
        },
        ObjectID => $TicketID,
        Value    => [
            'Key4'
        ],
        UserID    => 1,
        Success   => 0,
        ShouldGet => 1,
        Silent    => 1
    },
    {
        Name               => 'Multiselect - Valid Option',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Multiselect',
            Config     => {
                PossibleValues => {
                    Key1 => 'Value1',
                    Key2 => 'Value2',
                    Key3 => 'Value3',
                },
            },
        },
        ObjectID => $TicketID,
        Value    => [
            'Key3'
        ],
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
        Silent    => 0
    },
    {
        Name               => 'Multiselect - multiple values',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Multiselect',
            Config     => {
                CountMax       => 2,
                PossibleValues => {
                    Key1 => 'Value1',
                    Key2 => 'Value2',
                    Key3 => 'Value3',
                    Key4 => 'Value4',
                    Key5 => 'Value5',
                },
            },
        },
        ObjectID => $TicketID,
        Value    => [
            'Key2',
            'Key4'
        ],
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
        Silent    => 0
    },
    {
        Name               => 'Set DateTime Value - invalid date',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'DateTime',
        },
        ObjectID  => $TicketID,
        Value     => '2011-02-31 01:01:01',
        UserID    => 1,
        Success   => 0,
        ShouldGet => 1,
        Silent    => 1
    },
    {
        Name               => 'Set DateTime Value - wrong data',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'DateTime',
        },
        ObjectID  => $TicketID,
        Value     => 'Aug 1st',
        UserID    => 1,
        Success   => 0,
        ShouldGet => 1,
        Silent    => 1
    },
    {
        Name               => 'Set DateTime Value - no data',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'DateTime',
        },
        ObjectID  => $TicketID,
        Value     => undef,
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
        Silent    => 1
    },
    {
        Name               => 'Set Date Value - invalid date',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Date',
        },
        ObjectID  => $TicketID,
        Value     => '2011-02-31 01:01:01',
        UserID    => 1,
        Success   => 0,
        ShouldGet => 1,
        Silent    => 1
    },
    {
        Name               => 'Set Date Value - invalid time',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'Date',
        },
        ObjectID  => $TicketID,
        Value     => '2011-31-02 01:01:01',
        UserID    => 1,
        Success   => 0,
        ShouldGet => 1,
        Silent    => 1
    },
    {
        Name               => 'Set Date Value - wrong data',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'DateTime',
        },
        ObjectID  => $TicketID,
        Value     => 'Aug 1st',
        UserID    => 1,
        Success   => 0,
        ShouldGet => 1,
        Silent    => 1
    },
    {
        Name               => 'Set Date Value - no data',
        DynamicFieldConfig => {
            ID         => $FieldID,
            Name       => "dynamicfieldtest$RandomID",
            ObjectType => 'Ticket',
            FieldType  => 'DateTime',
        },
        ObjectID  => $TicketID,
        Value     => undef,
        UserID    => 1,
        Success   => 1,
        ShouldGet => 1,
        Silent    => 1
    },

);

# execute tests
for my $Test (@Tests) {
    my $Success = $BackendObject->ValueSet(
        DynamicFieldConfig => $Test->{DynamicFieldConfig},
        ObjectID           => $Test->{ObjectID},
        Value              => $Test->{Value},
        UserID             => $Test->{UserID},
        Silent             => $Test->{Silent} || 0
    );

    if ( !$Test->{Success} ) {
        $Self->False(
            $Success,
            "ValueSet() - Test ($Test->{Name}) - with False",
        );

        # Try to get the value with ValueGet()
        my $Value = $BackendObject->ValueGet(
            DynamicFieldConfig => $Test->{DynamicFieldConfig},
            ObjectID           => $Test->{ObjectID},
            Silent             => $Test->{Silent} || 0
        );

        # fix Value if it's an array ref
        if (
            defined $Value
            && ref $Value eq 'ARRAY'
        ) {
            if (
                IsArrayRefWithData($Value)
                && scalar @{$Value} == 1
                && !$Value->[0]
            ) {
                $Value = q{};
            }
            else {
                $Value = join( q{,} , @{$Value});
            }
        }

        # compare data
        if ( $Test->{ShouldGet} ) {

            $Self->IsNot(
                $Value,
                $Test->{Value},
                "ValueGet() after unsuccessful ValueSet() - (Test $Test->{Name}) - Value",
            );
        }
        else {
            $Self->Is(
                $Value,
                undef,
                "ValueGet() after unsuccessful ValueSet() - (Test $Test->{Name}) - Value undef",
            );
        }
    }
    else {
        $Self->True(
            $Success,
            "ValueSet() - Test ($Test->{Name}) - with True",
        );

        # get the value with ValueGet()
        my $Value = $BackendObject->ValueGet(
            DynamicFieldConfig => $Test->{DynamicFieldConfig},
            ObjectID           => $Test->{ObjectID},
            Silent             => $Test->{Silent} || 0
        );

        # workaround for oracle
        # oracle databases can't determine the difference between NULL and ''
        if (
            !defined $Value
            || $Value eq q{}
        ) {

            # test falseness
            $Self->False(
                $Value,
                "ValueGet() after successful ValueSet() - (Test $Test->{Name}) - "
                    . "Value (Special case for '')"
            );
        }
        else {
            if ( ref $Value eq 'ARRAY' ) {

                # compare data
                $Self->IsDeeply(
                    $Value,
                    $Test->{Value},
                    "ValueGet() after successful ValueSet() - (Test $Test->{Name}) - Value",
                );

            }
            else {

                # compare data
                $Self->Is(
                    $Value,
                    $Test->{Value},
                    "ValueGet() after successful ValueSet() - (Test $Test->{Name}) - Value",
                );
            }
        }
    }
}

# specific tests for ValueGet()
@Tests = (
    {
        Name               => 'Wrong FieldID',
        DynamicFieldConfig => {
            ID         => -1,
            ObjectType => 'Ticket',
            FieldType  => 'Text',
        },
        ObjectID => $TicketID,
        UserID   => 1,
    },
    {
        Name               => 'Wrong ObjectType',
        DynamicFieldConfig => {
            ID         => $FieldID,
            ObjectType => 'InvalidObject',
            FieldType  => 'Text',
        },
        ObjectID => $TicketID,
        UserID   => 1,
    },
    {
        Name               => 'Wrong ObjectID',
        DynamicFieldConfig => {
            ID         => $FieldID,
            ObjectType => 'Ticket',
            FieldType  => 'Text',
        },
        ObjectID => -1,
        UserID   => 1,
    },
);

for my $Test (@Tests) {

    # try to get the value with ValueGet()
    my $Value = $BackendObject->ValueGet(
        DynamicFieldConfig => $Test->{DynamicFieldConfig},
        ObjectID           => $Test->{ObjectID},
    );

    $Self->False(
        $Value->{ID},
        "ValueGet() - Test ($Test->{Name}) - with False",
    );

}

# specific tests for TicketDelete, it must clean up the dynamic field values()
my $Value = 123;

$BackendObject->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $TicketID,
    Value              => $Value,
    UserID             => 1,
);

my %TicketValueDeleteData = $TicketObject->TicketGet(
    TicketID      => $TicketID,
    DynamicFields => 1,
    UserID        => 1,
);

$Self->Is(
    $TicketValueDeleteData{ 'DynamicField_' . $DynamicFieldName }->[0],
    $Value,
    "Should have value '$Value' set.",
);

$BackendObject->ValueDelete(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $TicketID,
    UserID             => 1,
);

%TicketValueDeleteData = $TicketObject->TicketGet(
    TicketID      => $TicketID,
    DynamicFields => 1,
    UserID        => 1,
);

$Self->False(
    $TicketValueDeleteData{ 'DynamicField_' . $DynamicFieldName },
    "Ticket shouldn't have a value.",
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $TicketID,
    Value              => $Value,
    UserID             => 1,
);
my $ReturnValue1 = $BackendObject->ValueGet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $TicketID,
    UserID             => 1,
);

$Self->Is(
    $ReturnValue1->[0],
    $Value,
    'TicketDelete() DF value correctly set',
);

# delete the ticket
my $TicketDelete = $TicketObject->TicketDelete(
    TicketID => $TicketID,
    UserID   => 1,
);

# sanity check
$Self->True(
    $TicketDelete,
    "TicketDelete() successful for Ticket ID $TicketID",
);

my $ReturnValue2 = $BackendObject->ValueGet(
    DynamicFieldConfig => $DynamicFieldConfig,
    ObjectID           => $TicketID,
    UserID             => 1,
);

$Self->Is(
    $ReturnValue2,
    scalar undef,
    'TicketDelete() DF value was deleted by ticket delete',
);

my $ValuesDelete = $BackendObject->AllValuesDelete(
    DynamicFieldConfig => $DynamicFieldConfig,
    UserID             => 1,
);

# sanity check
$Self->True(
    $ValuesDelete,
    "AllValuesDelete() successful for Field ID $FieldID",
);

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
