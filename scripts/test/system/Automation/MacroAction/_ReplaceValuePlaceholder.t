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

# begin transaction on database
$Helper->BeginWork();

my %Data = (
    Title => 'MacroDFPlaceholderTest',
    PossibleValues => {
        Key1 => "Value1",
        Key2 => "Value2",
        Key3 => "Value3"
    },
    Keys   => ['Key1', 'Key2'],
    Values => ['Value1', 'Value2'],
    Separator => '#'
);

# load macro action module module
my $BackendObject = $Kernel::OM->Get('Automation')->_LoadMacroActionTypeBackend(
    MacroType => 'Ticket',
    Name      => 'VariableSet',
);
$Self->True(
    $BackendObject,
    "Get backend module",
);
if ($BackendObject) {

    my $TicketID = _AddObjects();

    if ($TicketID) {

        my $ReplacedValue = $BackendObject->_ReplaceValuePlaceholder(
            Value => '<KIX_TICKET_Title>',
            Data  => {
                TicketID => $TicketID
            }
        );
        $Self->Is(
            $ReplacedValue,
            $Data{Title},
            "ticket title",
        );

        $ReplacedValue = $BackendObject->_ReplaceValuePlaceholder(
            Value => '<KIX_TICKET_DynamicField_PlaceholderTestSelection_ObjectValue>',
            Data  => {
                TicketID => $TicketID
            }
        );
        $Self->IsDeeply(
            $ReplacedValue,
            $Data{Keys},
            "_ObjectValue",
        );

        $ReplacedValue = $BackendObject->_ReplaceValuePlaceholder(
            Value => 'Keys: <KIX_TICKET_DynamicField_PlaceholderTestSelection_ObjectValue>',
            Data  => {
                TicketID => $TicketID
            }
        );
        $Self->Is(
            $ReplacedValue,
            'Keys: ' . join(',',@{ $Data{Keys} }),
            "_ObjectValue (with string)",
        );

        $ReplacedValue = $BackendObject->_ReplaceValuePlaceholder(
            Value => '<KIX_TICKET_DynamicField_PlaceholderTestSelection_Key>',
            Data  => {
                TicketID => $TicketID
            }
        );
        $Self->Is(
            $ReplacedValue,
            join($Data{Separator},@{ $Data{Keys} }),
            "_Key (as string)",
        );

        $ReplacedValue = $BackendObject->_ReplaceValuePlaceholder(
            Value => '<KIX_TICKET_DynamicField_PlaceholderTestSelection_Key>',
            Data  => {
                TicketID => $TicketID
            },
            HandleKeyLikeObjectValue => 1           # Key as ObjectValue
        );
        $Self->IsDeeply(
            $ReplacedValue,
            $Data{Keys},
            "_Key (as _ObjectValue)",
        );

        $ReplacedValue = $BackendObject->_ReplaceValuePlaceholder(
            Value => '<KIX_TICKET_DynamicField_PlaceholderTestSelection_Value>',
            Data  => {
                TicketID => $TicketID
            }
        );
        $Self->Is(
            $ReplacedValue,
            join($Data{Separator},@{ $Data{Values} }),
            "_Value",
        );
    }
}

# rollback transaction on database
$Helper->Rollback();

sub _AddObjects {
    my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title     => $Data{Title},
        OwnerID   => 1,
        Queue     => 'Junk',
        Lock      => 'unlock',
        Priority  => '3 normal',
        State     => 'closed',
        UserID    => 1
    );
    $Self->True(
        $TicketID,
        '_AddObjects - create ticket'
    );
    return if (!$TicketID);

    my $SelectionDFID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        Name            => 'PlaceholderTestSelection',
        Label           => 'PlaceholderTestSelection',
        FieldType       => 'Multiselect',
        ObjectType      => 'Ticket',
        Config          => {
                CountMin => 0,
                CountMax => 2,
                CountDefault => 0,
                ItemSeparator => $Data{Separator},
                DefaultValue => undef,
                PossibleValues => $Data{PossibleValues}
        },
        ValidID => 1,
        UserID  => 1
    );
    $Self->True(
        $SelectionDFID,
        '_AddObjectss - create selection dynamic field'
    );
    return if (!$SelectionDFID);
    my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        ID => $SelectionDFID
    );
    $Self->True(
        IsHashRefWithData($DynamicFieldConfig),
        '_AddObjectss - get selection dynamic field config'
    );
    return if (!IsHashRefWithData($DynamicFieldConfig));

    my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicFieldConfig,
        ObjectID => $TicketID,
        Value    => ['Key1', 'Key2'],
        UserID => 1
    );
    $Self->True(
        $Success,
        '_AddObjectss - set value'
    );
    return if (!$Success);

    return $TicketID;
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
