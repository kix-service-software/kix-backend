# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get deployment state list
my $DeplStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
    Class => 'ITSM::ConfigItem::DeploymentState',
);
my %DeplStateListReverse = reverse( %{ $DeplStateList } );

# get incident state list
my $InciStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
    Class => 'ITSM::Core::IncidentState',
);
my %InciStateListReverse = reverse( %{ $InciStateList } );

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
my $ClassAID   = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'ITSM::ConfigItem::Class',
    Name    => $ClassAName,
    Comment => q{},
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ClassAID,
    'Create class ' . $ClassAName,
);
my $ClassADefID = $Kernel::OM->Get('ITSMConfigItem')->DefinitionAdd(
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
my $ClassBID   = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'ITSM::ConfigItem::Class',
    Name    => $ClassBName,
    Comment => q{},
    ValidID => 1,
    UserID  => 1
);
$Self->True(
    $ClassBID,
    'Create class ' . $ClassBName,
);
my $ClassBDefID = $Kernel::OM->Get('ITSMConfigItem')->DefinitionAdd(
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

my $CIName1    = 'Asset1';
my $CIName2    = 'Asset10';             # contains value of $CIName1
my $CINumber1  = '123';
my $CINumber2  = '1234';                # contains value of $CINumber1
my $FQDNValue1 = 'some.fqdn.com';
my $FQDNValue2 = 'sub.some.fqdn.com';   # contains value of $FQDNValue1
my $IPValue1   = '1.2.3.4';
my $IPValue2   = '5.6.7.8';
my $IPValue3   = '1.2.3.41';            # contains value of $IPValue1

#####################
# create config items
# item for value from body - should be found
my $ConfigItemAID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $Helper->GetRandomNumber(),
    ClassID => $ClassAID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemAID,
    'Create config item A',
);
if ( $ConfigItemAID ) {
    my $ConfigItemAVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
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
                                        Content => $FQDNValue1,   # relevant value as second value
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
my $ConfigItemBID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $Helper->GetRandomNumber(),
    ClassID => $ClassAID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemBID,
    'Create config item B',
);
if ( $ConfigItemBID ) {
    my $ConfigItemBVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
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
                                        Content => $IPValue1,
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
my $ConfigItemCID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $Helper->GetRandomNumber(),
    ClassID => $ClassAID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemCID,
    'Create config item C',
);
if ( $ConfigItemCID ) {
    my $ConfigItemCVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
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
my $ConfigItemDID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $Helper->GetRandomNumber(),
    ClassID => $ClassBID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemDID,
    'Create config item D',
);
if ( $ConfigItemDID ) {
    my $ConfigItemDVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
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
                                        Content => $IPValue1,
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

# item for value not matching value but containing the matching value - should NOT be found
my $ConfigItemEID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $Helper->GetRandomNumber(),
    ClassID => $ClassAID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemEID,
    'Create config item E',
);
if ( $ConfigItemEID ) {
    my $ConfigItemEVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
        ConfigItemID => $ConfigItemEID,
        Name         => 'ConfigItem E - 1st version',
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
                                        Content => $FQDNValue2,
                                    }
                                ]
                            },
                            {
                                IP => [
                                    undef,
                                    {
                                        Content => $IPValue3,
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
        $ConfigItemEVersionID,
        'Create version E',
    );
}
$Kernel::OM->ObjectsDiscard(
    Objects => [
        'ITSMConfigItem'
    ]
);

# item for matching number - should be found
my $ConfigItemFID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $CINumber1,
    ClassID => $ClassAID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemFID,
    'Create config item F',
);
if ( $ConfigItemFID ) {
    my $ConfigItemFVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
        ConfigItemID => $ConfigItemFID,
        Name         => 'ConfigItem E - 1st version',
        DefinitionID => $ClassADefID,
        DeplStateID  => $DeplStateListReverse{Production},
        InciStateID  => $InciStateListReverse{Operational},
        UserID       => 1,
        XMLData      => [
            undef,
            {
                Version => [
                    undef
                ]
            }
        ]
    );
    $Self->True(
        $ConfigItemFVersionID,
        'Create version F',
    );
}
$Kernel::OM->ObjectsDiscard(
    Objects => [
        'ITSMConfigItem'
    ]
);

# item for matching name - should be found
my $ConfigItemGID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $Helper->GetRandomNumber(),
    ClassID => $ClassAID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemGID,
    'Create config item G',
);
if ( $ConfigItemGID ) {
    my $ConfigItemGVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
        ConfigItemID => $ConfigItemGID,
        Name         => $CIName1,
        DefinitionID => $ClassADefID,
        DeplStateID  => $DeplStateListReverse{Production},
        InciStateID  => $InciStateListReverse{Operational},
        UserID       => 1,
        XMLData      => [
            undef,
            {
                Version => [
                    undef
                ]
            }
        ]
    );
    $Self->True(
        $ConfigItemGVersionID,
        'Create version G',
    );
}
$Kernel::OM->ObjectsDiscard(
    Objects => [
        'ITSMConfigItem'
    ]
);

# item for not matching name and number but containing values of F (number) and G (name) - should be found
my $ConfigItemHID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
    Number  => $CINumber2,
    ClassID => $ClassAID,
    UserID  => 1,
);
$Self->True(
    $ConfigItemHID,
    'Create config item H',
);
if ( $ConfigItemHID ) {
    my $ConfigItemHVersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
        ConfigItemID => $ConfigItemHID,
        Name         => $CIName2,
        DefinitionID => $ClassADefID,
        DeplStateID  => $DeplStateListReverse{Production},
        InciStateID  => $InciStateListReverse{Operational},
        UserID       => 1,
        XMLData      => [
            undef,
            {
                Version => [
                    undef
                ]
            }
        ]
    );
    $Self->True(
        $ConfigItemHVersionID,
        'Create version H',
    );
}
$Kernel::OM->ObjectsDiscard(
    Objects => [
        'ITSMConfigItem'
    ]
);

#####################
# set relevant configs
$Kernel::OM->Get('Config')->Set(
    Key   => 'TicketAutoLinkConfigItem::CISearchInClasses',
    Value => {
        $ClassAName => 'Name,Number,SectionHost::FQDN,SectionHost::IP',
        $ClassBName => 'Name,Number,SectionHost::FQDN,SectionHost::IP'
    }
);
my $SearchClasses = $Kernel::OM->Get('Config')->Get('TicketAutoLinkConfigItem::CISearchInClasses');
$Self->True(
    IsHashRefWithData( $SearchClasses ) || 0,
    "Config CISearchInClasses is a hash ref",
);
if ( IsHashRefWithData( $SearchClasses ) ) {
    $Self->Is(
        $SearchClasses->{ $ClassAName },
        'Name,Number,SectionHost::FQDN,SectionHost::IP',
        "Config CISearchInClasses has new value (A)",
    );
    $Self->Is(
        $SearchClasses->{ $ClassBName },
        'Name,Number,SectionHost::FQDN,SectionHost::IP',
        "Config CISearchInClasses has new value (B)",
    );
}
# only accept class A
$Kernel::OM->Get('Config')->Set(
    Key   => 'TicketAutoLinkConfigItem::CISearchInClassesPerRecipient',
    Value => {
        'sysmon-' . $ClassAName . '-mailbox@example.com' => $ClassAName
    }
);
my $ClassesPerRecipient = $Kernel::OM->Get('Config')->Get('TicketAutoLinkConfigItem::CISearchInClassesPerRecipient');
$Self->True(
    IsHashRefWithData( $ClassesPerRecipient ) || 0,
    "Config CISearchInClassesPerRecipient is a hash ref",
);
if ( IsHashRefWithData( $ClassesPerRecipient ) ) {
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
    'Host: ' . $FQDNValue1 . "\n",
    'Address: 192.168.10.9' . "\n",
    "\n",
    'Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.' . "\n",
    "\n",
);
$Kernel::OM->Get('Config')->Set(
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
$Kernel::OM->ObjectsDiscard(
    Objects => [
        'Ticket'
    ]
);
if ($Return[0] == 1) {
    # check if asset A is set by body text ("Host:")
    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );
    $Self->IsDeeply(
        $Ticket{DynamicField_AffectedAsset},
        [ $ConfigItemAID ],
        'Ticket has config item A in DF AffectedAsset',
        1
    );

    #####################
    # dynamic field test (use IPValue for SySMonXAddress)
    my $AddressDynamicField = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        Name => 'SysMonXAddress',
    );
    $Self->True(
        IsHashRefWithData( $AddressDynamicField ) || 0,
        'Get DF "SysMonXAddress"',
    );
    if ( IsHashRefWithData( $AddressDynamicField ) ) {
        my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
            DynamicFieldConfig => $AddressDynamicField,
            ObjectID           => $Return[1],
            Value              => [ $IPValue1 ],
            UserID             => 1,
        );
        $Self->True(
            $Success || 0,
            'Set DF "SysMonXAddress" value',
        );
        $Kernel::OM->ObjectsDiscard(
            Objects => [
                'Ticket'
            ]
        );
        if ( $Success ) {
            # check if assets (A and B) are set
            %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                TicketID      => $Return[1],
                DynamicFields => 1,
            );
            $Self->IsDeeply(
                $Ticket{DynamicField_AffectedAsset},
                [ $ConfigItemAID, $ConfigItemBID ],
                'Ticket has config item A and B in DF AffectedAsset',
                1
            );
        }
    }

    # further article tests
    my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
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
    $Self->True(
        $ArticleID,
        'Article created with IPValue2',
    );
    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Ticket'
        ]
    );
    if ( $ArticleID ) {
        # check if assets (A and B) are set
        %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID      => $Return[1],
            DynamicFields => 1,
        );
        $Self->IsDeeply(
            $Ticket{DynamicField_AffectedAsset},
            [ $ConfigItemAID, $ConfigItemBID ],
            'Ticket has config item A and B in DF AffectedAsset',
            1
        );
    }

    # repeat but with inactive FirstArticleOnly
    my $EventConfig = $Kernel::OM->Get('Config')->Get('Ticket::EventModulePost')->{'500-TicketAutoLinkConfigItem'};
    $Self->True(
        IsHashRefWithData( $EventConfig ) || 0,
        "Event-Config 500-TicketAutoLinkConfigItem is a hash ref",
    );

    if ( IsHashRefWithData( $EventConfig ) ) {
        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::EventModulePost###500-TicketAutoLinkConfigItem',
            Value => {
                %{ $EventConfig },
                FirstArticleOnly => 0
            }
        );

        $EventConfig = $Kernel::OM->Get('Config')->Get('Ticket::EventModulePost')->{'500-TicketAutoLinkConfigItem'};
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

        $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
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
        $Self->True(
            $ArticleID,
            'Article created with IPValue2',
        );
        $Kernel::OM->ObjectsDiscard(
            Objects => [
                'Ticket'
            ]
        );
        if ( $ArticleID ) {
            %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                TicketID      => $Return[1],
                DynamicFields => 1,
            );
            $Self->IsDeeply(
                $Ticket{DynamicField_AffectedAsset},
                [ $ConfigItemAID, $ConfigItemBID, $ConfigItemCID ],
                'Ticket has config item A, B and C in DF AffectedAsset',
                1
            );
        }

        $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
            TicketID         => $Return[1],
            Channel          => 'note',
            SenderType       => 'agent',
            Subject          => 'third article',
            Body             => "Lorem ipsum dolor sit amet\nHost: $CINumber1\nLorem ipsum dolor sit amet",
            Charset          => 'utf-8',
            MimeType         => 'text/plain',
            HistoryType      => 'AddNote',
            HistoryComment   => 'Some comment!',
            UserID           => 1,
        );
        $Self->True(
            $ArticleID,
            'Article created with CINumber1',
        );
        $Kernel::OM->ObjectsDiscard(
            Objects => [
                'Ticket'
            ]
        );
        if ( $ArticleID ) {
            %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                TicketID      => $Return[1],
                DynamicFields => 1,
            );
            $Self->IsDeeply(
                $Ticket{DynamicField_AffectedAsset},
                [ $ConfigItemAID, $ConfigItemBID, $ConfigItemCID, $ConfigItemFID ],
                'Ticket has config item A, B, C and F in DF AffectedAsset',
                1
            );
        }

        $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
            TicketID         => $Return[1],
            Channel          => 'note',
            SenderType       => 'agent',
            Subject          => 'third article',
            Body             => "Lorem ipsum dolor sit amet\nHost: $CIName1\nLorem ipsum dolor sit amet",
            Charset          => 'utf-8',
            MimeType         => 'text/plain',
            HistoryType      => 'AddNote',
            HistoryComment   => 'Some comment!',
            UserID           => 1,
        );
        $Self->True(
            $ArticleID,
            'Article created with CIName1',
        );
        $Kernel::OM->ObjectsDiscard(
            Objects => [
                'Ticket'
            ]
        );
        if ( $ArticleID ) {
            %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                TicketID      => $Return[1],
                DynamicFields => 1,
            );
            $Self->IsDeeply(
                $Ticket{DynamicField_AffectedAsset},
                [ $ConfigItemAID, $ConfigItemBID, $ConfigItemCID, $ConfigItemFID , $ConfigItemGID ],
                'Ticket has config item A, B, C, F and G in DF AffectedAsset',
                1
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
