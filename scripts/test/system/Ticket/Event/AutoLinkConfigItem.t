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

use Kernel::System::PostMaster;

# get needed objects for rollback
my $UserObject           = $Kernel::OM->Get('User'); # without, config changes are ignored!!

# get needed objects
my $ConfigObject         = $Kernel::OM->Get('Config');
my $TicketObject         = $Kernel::OM->Get('Ticket');
my $ConfigItemObject     = $Kernel::OM->Get('ITSMConfigItem');
my $GeneralCatalogObject = $Kernel::OM->Get('GeneralCatalog');
my $DynamicFieldObject   = $Kernel::OM->Get('DynamicField');
my $DFBackendObject      = $Kernel::OM->Get('DynamicField::Backend');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get deployment state list
my $DeplStateList = $GeneralCatalogObject->ItemList(
    Class => 'ITSM::ConfigItem::DeploymentState',
);
my %DeplStateListReverse = reverse %{$DeplStateList};

# get incident state list
my $InciStateList = $GeneralCatalogObject->ItemList(
    Class => 'ITSM::Core::IncidentState',
);
my %InciStateListReverse = reverse %{$InciStateList};

my $DefString = <<'END';
[
    {
        Key          => 'SectionHost',
        Name         => 'Host',
        CountDefault => 0,
        CountMax     => 1,
        CountMin     => 0,
        Input        => {
            Type => 'Dummy'
        },
        Sub => [
            {
                Key          => 'FQDN',
                Name         => 'FQDN',
                Searchable   => 1,
                CountDefault => 0,
                CountMax     => 3,
                CountMin     => 0,
                Input        => {
                    Type => 'Text'
                }
            },
            {
                Key          => 'IP',
                Name         => 'IP',
                Searchable   => 1,
                CountDefault => 0,
                CountMax     => 3,
                CountMin     => 0,
                Input        => {
                    Type => 'Text'
                }
            }
        ]
    }
]
END

my $ClassAName = 'AutoLink' . $Helper->GetRandomNumber();
my $ClassAID = $GeneralCatalogObject->ItemAdd(
    Class    => 'ITSM::ConfigItem::Class',
    Name     => $ClassAName,
    Comment  => q{},
    ValidID  => 1,
    UserID   => 1
);
$Self->True(
    $ClassAID,
    'Create class ' . $ClassAName,
);

my $ClassADefID = $ConfigItemObject->DefinitionAdd(
    ClassID    => $ClassAID,
    UserID     => 1,
    Definition => $DefString
);
$Self->True(
    $ClassADefID,
    'Create class definition of ' . $ClassAName,
);

$Kernel::OM->ObjectsDiscard(
    Objects => [
        'GeneralCatalog',
        'ITSMConfigItem'
    ]
);

my $ClassBName = 'AutoLink' . $Helper->GetRandomNumber();
my $ClassBID = $GeneralCatalogObject->ItemAdd(
    Class    => 'ITSM::ConfigItem::Class',
    Name     => $ClassBName,
    Comment  => q{},
    ValidID  => 1,
    UserID   => 1
);
$Self->True(
    $ClassBID,
    'Create class ' . $ClassBName,
);

my $ClassBDefID = $ConfigItemObject->DefinitionAdd(
    ClassID    => $ClassBID,
    UserID     => 1,
    Definition => $DefString
);
$Self->True(
    $ClassBDefID,
    'Create class definition of ' . $ClassBName,
);

$Kernel::OM->ObjectsDiscard(
    Objects => [
        'GeneralCatalog',
        'ITSMConfigItem'
    ]
);

my $FQDNValue = 'some.fqdn.com';
my $IPValue   = '1.2.3.4';
my $IPValue2  = '5.6.7.8';

#####################
# create config items
# item for value from body - should be found
my $ConfigItemAID = $ConfigItemObject->ConfigItemAdd(
    Number  => $Helper->GetRandomNumber(),
    ClassID => $ClassAID,
    UserID  => 1,
);

$Self->True(
    $ConfigItemAID,
    'Create config item A',
);

if ($ConfigItemAID) {
    my $ConfigItemAVersionID = $ConfigItemObject->VersionAdd(
        ConfigItemID => $ConfigItemAID,
        Name         => 'ConfigItem A - 1st version',
        DefinitionID => $ClassADefID,
        DeplStateID  => $DeplStateListReverse{Production},
        InciStateID  => $InciStateListReverse{Operational},
        UserID       => 1,
        XMLData      => [
            undef,
            {
                Version => [
                    undef,
                    {
                        SectionHost => [
                            undef,
                            {
                                FQDN => [
                                    undef,
                                    {
                                        Content => 'some.otherfqdn.com',
                                    },
                                    {
                                        Content => $FQDNValue,   # relevant value as second value
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    );
    $Self->True(
        $ConfigItemAVersionID,
        'Create version A',
    );
}

$Kernel::OM->ObjectsDiscard(
    Objects => [
        'ITSMConfigItem'
    ]
);

# item for value from DF - should be found
my $ConfigItemBID = $ConfigItemObject->ConfigItemAdd(
    Number  => $Helper->GetRandomNumber(),
    ClassID => $ClassAID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemBID,
    'Create config item B',
);
if ($ConfigItemBID) {
    my $ConfigItemBVersionID = $ConfigItemObject->VersionAdd(
        ConfigItemID => $ConfigItemBID,
        Name         => 'ConfigItem B - 1st version',
        DefinitionID => $ClassADefID,
        DeplStateID  => $DeplStateListReverse{Production},
        InciStateID  => $InciStateListReverse{Operational},
        UserID       => 1,
        XMLData      => [
            undef,
            {
                Version => [
                    undef,
                    {
                        SectionHost => [
                            undef,
                            {
                                IP => [
                                    undef,
                                    {
                                        Content => $IPValue,
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    );
    $Self->True(
        $ConfigItemBVersionID,
        'Create version B',
    );
}

$Kernel::OM->ObjectsDiscard(
    Objects => [
        'ITSMConfigItem'
    ]
);

# item for value from DF but not matching value - should NOT be found
my $ConfigItemCID = $ConfigItemObject->ConfigItemAdd(
    Number  => $Helper->GetRandomNumber(),
    ClassID => $ClassAID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemCID,
    'Create config item C',
);
if ($ConfigItemCID) {
    my $ConfigItemCVersionID = $ConfigItemObject->VersionAdd(
        ConfigItemID => $ConfigItemCID,
        Name         => 'ConfigItem C - 1st version',
        DefinitionID => $ClassADefID,
        DeplStateID  => $DeplStateListReverse{Production},
        InciStateID  => $InciStateListReverse{Operational},
        UserID       => 1,
        XMLData      => [
            undef,
            {
                Version => [
                    undef,
                    {
                        SectionHost => [
                            undef,
                            {
                                IP => [
                                    undef,
                                    {
                                        Content => $IPValue2,
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    );
    $Self->True(
        $ConfigItemCVersionID,
        'Create version C',
    );
}

$Kernel::OM->ObjectsDiscard(
    Objects => [
        'ITSMConfigItem'
    ]
);

# item for value from DF with matching value but not used class - should NOT be found
my $ConfigItemDID = $ConfigItemObject->ConfigItemAdd(
    Number  => $Helper->GetRandomNumber(),
    ClassID => $ClassBID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemDID,
    'Create config item D',
);
if ($ConfigItemDID) {
    my $ConfigItemDVersionID = $ConfigItemObject->VersionAdd(
        ConfigItemID => $ConfigItemDID,
        Name         => 'ConfigItem D - 1st version',
        DefinitionID => $ClassBDefID,
        DeplStateID  => $DeplStateListReverse{Production},
        InciStateID  => $InciStateListReverse{Operational},
        UserID       => 1,
        XMLData      => [
            undef,
            {
                Version => [
                    undef,
                    {
                        SectionHost => [
                            undef,
                            {
                                IP => [
                                    undef,
                                    {
                                        Content => $IPValue,
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    );
    $Self->True(
        $ConfigItemDVersionID,
        'Create version D',
    );
}

$Kernel::OM->ObjectsDiscard(
    Objects => [
        'ITSMConfigItem'
    ]
);

#####################
# set relevant configs
$ConfigObject->Set(
    Key   => 'TicketAutoLinkConfigItem::CISearchInClasses',
    Value => {
        $ClassAName => 'SectionHost::FQDN,SectionHost::IP',
        $ClassBName => 'SectionHost::FQDN,SectionHost::IP'
    }
);
my $SearchClasses = $ConfigObject->Get('TicketAutoLinkConfigItem::CISearchInClasses');
$Self->True(
    IsHashRefWithData($SearchClasses) || 0,
    "Config CISearchInClasses is a hash ref",
);
if (IsHashRefWithData($SearchClasses)) {
    $Self->Is(
        $SearchClasses->{$ClassAName},
        'SectionHost::FQDN,SectionHost::IP',
        "Config CISearchInClasses has new value (A)",
    );
    $Self->Is(
        $SearchClasses->{$ClassBName},
        'SectionHost::FQDN,SectionHost::IP',
        "Config CISearchInClasses has new value (B)",
    );
}
# only accept class A
$ConfigObject->Set(
    Key   => 'TicketAutoLinkConfigItem::CISearchInClassesPerRecipient',
    Value => {
        'sysmon-' . $ClassAName . '-mailbox@example.com' => $ClassAName
    }
);
my $ClassesPerRecipient = $ConfigObject->Get('TicketAutoLinkConfigItem::CISearchInClassesPerRecipient');
$Self->True(
    IsHashRefWithData($ClassesPerRecipient) || 0,
    "Config CISearchInClassesPerRecipient is a hash ref",
);
if (IsHashRefWithData($ClassesPerRecipient)) {
    $Self->Is(
        $ClassesPerRecipient->{'sysmon-' . $ClassAName . '-mailbox@example.com'},
        $ClassAName,
        "Config CISearchInClassesPerRecipient has new value (A)",
    );
}

#####################
# read mail - new ticket (use FQDNValue for host)
my @NewTicketMail = (
    'Return-Path: <SysMon@example.com>' . "\n",
    'To: sysmon-' . $ClassAName . '-mailbox@example.com' . "\n",
    'Subject: Autolink Test Mail by FQDN/IP' . "\n",
    'Date: Sun, 10 May 2021 01:00:00 +0100 (CET)' . "\n",
    'From: sysmon@example.com' . "\n",
    'Mime-Version: 1.0' . "\n",
    'Message-Id: <20210510010000.01@example.com>' . "\n",
    "\n",
    'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.' . "\n",
    "\n",
    'Host: ' . $FQDNValue . "\n",
    'Address: 192.168.10.9' . "\n",
    "\n",
    'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.' . "\n",
    "\n",
);
$ConfigObject->Set(
    Key   => 'PostmasterDefaultState',
    Value => 'new'
);
my $PostMasterObject = Kernel::System::PostMaster->new(
    Email => \@NewTicketMail,
);
my @Return = $PostMasterObject->Run();
@Return = @{ $Return[0] || [] };
$Self->Is(
    $Return[0] || 0,
    1,
    'New ticket created',
);
if ($Return[0] == 1) {

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    # check if asset A is set by body text ("Host:")
    $Self->True(
        IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) || 0,
        "Ticket has affected assets",
    );
    if ( IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) ) {
        $Self->ContainedIn(
            $ConfigItemAID,
            $Ticket{DynamicField_AffectedAsset},
            'Ticket has config item A',
        );
    }

    #####################
    # dynamic field test (use IPValue for SySMonXAddress)
    my $AddressDynamicField = $DynamicFieldObject->DynamicFieldGet(
        Name => 'SysMonXAddress',
    );

    $Self->True(
        IsHashRefWithData($AddressDynamicField) || 0,
        'Get DF "SysMonXAddress"',
    );

    if (IsHashRefWithData($AddressDynamicField)) {
        my $Success = $DFBackendObject->ValueSet(
            DynamicFieldConfig => $AddressDynamicField,
            ObjectID           => $Return[1],
            Value              => [$IPValue],
            UserID             => 1,
        );

        $Self->True(
            $Success || 0,
            'Set DF "SysMonXAddress" value',
        );

        if ($Success) {
            %Ticket = $TicketObject->TicketGet(
                TicketID      => $Return[1],
                DynamicFields => 1,
            );

            # check if assets (A and B) are set
            $Self->True(
                IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) || 0,
                "Ticket has affected assets (2nd check)",
            );

            if ( IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) ) {
                $Self->Is(
                    scalar @{ $Ticket{DynamicField_AffectedAsset} },
                    2,
                    'Ticket has 2 config items in "AffectedAsset"',
                );
                $Self->ContainedIn(
                    $ConfigItemAID,
                    $Ticket{DynamicField_AffectedAsset},
                    'Ticket has config item A (2nd check)',
                );
                $Self->ContainedIn(
                    $ConfigItemBID,
                    $Ticket{DynamicField_AffectedAsset},
                    'Ticket has config item B',
                );
                $Self->NotContainedIn(
                    $ConfigItemCID,
                    $Ticket{DynamicField_AffectedAsset},
                    'Ticket has NOT config item C',
                );
                $Self->NotContainedIn(
                    $ConfigItemDID,
                    $Ticket{DynamicField_AffectedAsset},
                    'Ticket has NOT config item D',
                );
            }
        }
    }

    # further article tests
    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID         => $Return[1],
        Channel          => 'note',
        SenderType       => 'agent',
        Subject          => 'second article',
        Body             => "Lorem ipsum dolor sit amet\nAddress: $IPValue2\nLorem ipsum dolor sit amet",
        Charset          => 'utf-8',
        MimeType         => 'text/plain',
        HistoryType      => 'AddNote',
        HistoryComment   => 'Some comment!',
        UserID           => 1,
    );

    %Ticket = $TicketObject->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    # check if asset C is NOT set by body text ("Address:" - FirstArticleOnly is active)
    $Self->True(
        IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) || 0,
        "Ticket has affected assets (3rd check)",
    );

    if ( IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) ) {
        $Self->Is(
            scalar @{ $Ticket{DynamicField_AffectedAsset} },
            2,
            'Ticket has 2 config items in "AffectedAsset"',
        );
        $Self->ContainedIn(
            $ConfigItemAID,
            $Ticket{DynamicField_AffectedAsset},
            'Ticket has config item A (3rd check)',
        );
        $Self->ContainedIn(
            $ConfigItemBID,
            $Ticket{DynamicField_AffectedAsset},
            'Ticket has config item B (2nd check)',
        );
        $Self->NotContainedIn(
            $ConfigItemCID,
            $Ticket{DynamicField_AffectedAsset},
            'Ticket has NOT config item C',
        );
    }

    # repeat but with inactive FirstArticleOnly

    my $EventConfig = $ConfigObject->Get('Ticket::EventModulePost')->{'500-TicketAutoLinkConfigItem'};
    $Self->True(
        IsHashRefWithData($EventConfig) || 0,
        "Event-Config 500-TicketAutoLinkConfigItem is a hash ref",
    );

    if ( IsHashRefWithData($EventConfig) ) {
        $ConfigObject->Set(
            Key   => 'Ticket::EventModulePost###500-TicketAutoLinkConfigItem',
            Value => {
                %{$EventConfig},
                FirstArticleOnly => 0
            }
        );

        $EventConfig = $ConfigObject->Get('Ticket::EventModulePost')->{'500-TicketAutoLinkConfigItem'};
        $Self->True(
            IsHashRefWithData($EventConfig) || 0,
            "Event-Config 500-TicketAutoLinkConfigItem is a hash ref (2nd)",
        );

        if (IsHashRefWithData($EventConfig)) {
            $Self->Is(
                $EventConfig->{FirstArticleOnly},
                0,
                "Event-Config param FirstArticleOnly has new value (inactive)",
            );
        }

        $ArticleID = $TicketObject->ArticleCreate(
            TicketID         => $Return[1],
            Channel          => 'note',
            SenderType       => 'agent',
            Subject          => 'third article',
            Body             => "Lorem ipsum dolor sit amet\nAddress: $IPValue2\nLorem ipsum dolor sit amet",
            Charset          => 'utf-8',
            MimeType         => 'text/plain',
            HistoryType      => 'AddNote',
            HistoryComment   => 'Some comment!',
            UserID           => 1,
        );

        %Ticket = $TicketObject->TicketGet(
            TicketID      => $Return[1],
            DynamicFields => 1,
        );

        # check if asset C is NOT set by body text ("Address:" - FirstArticleOnly is active)
        $Self->True(
            IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) || 0,
            "Ticket has affected assets (4th check)",
        );

        if ( IsArrayRefWithData($Ticket{DynamicField_AffectedAsset}) ) {
            $Self->Is(
                scalar @{ $Ticket{DynamicField_AffectedAsset} },
                3,
                'Ticket has 3 config items in "AffectedAsset"',
            );
            $Self->ContainedIn(
                $ConfigItemAID,
                $Ticket{DynamicField_AffectedAsset},
                'Ticket has config item A (4th check)',
            );
            $Self->ContainedIn(
                $ConfigItemBID,
                $Ticket{DynamicField_AffectedAsset},
                'Ticket has config item B (3rd check)',
            );
            $Self->ContainedIn(
                $ConfigItemCID,
                $Ticket{DynamicField_AffectedAsset},
                'Ticket has config item C now',
            );
        }
    }
}

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
