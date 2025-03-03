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

use vars qw($Self);

# get needed objects
my $DBObject             = $Kernel::OM->Get('DB');
my $ConfigObject         = $Kernel::OM->Get('Config');
my $ConfigItemObject     = $Kernel::OM->Get('ITSMConfigItem');
my $GeneralCatalogObject = $Kernel::OM->Get('GeneralCatalog');
my $LinkObject           = $Kernel::OM->Get('LinkObject');
my $UserObject           = $Kernel::OM->Get('User');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# define needed variable
my $RandomID = $Helper->GetRandomID();

# ------------------------------------------------------------ #
# make preparations
# ------------------------------------------------------------ #

# get class list
my $ClassList = $GeneralCatalogObject->ItemList(
    Class => 'ITSM::ConfigItem::Class',
);
my %ClassListReverse = reverse %{$ClassList};

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

# get latest definition
my %DefinitionList;
foreach my $Class ( sort keys %ClassListReverse ) {
    $DefinitionList{$Class} = $ConfigItemObject->DefinitionList(
        ClassID => $ClassListReverse{$Class},
    );
}

my @ConfigItemClasses = (
    'Computer', 'Computer', 'Computer', 'Computer',
    'Hardware', 'Hardware', 'Hardware', 'Hardware',
    'Software', 'Software'
);

# create the config items
my %ConfigItemIDs;
for my $Counter (1..10) {
    my $Class = $ConfigItemClasses[$Counter-1];

    my $Name = "Test$Counter-$Class";

    # add the new config item
    my $ConfigItemID = $ConfigItemObject->ConfigItemAdd(
        Name    => $Name,
        ClassID => $ClassListReverse{$Class},
        UserID  => 1,
    );
    $Self->True(
        $ConfigItemID,
        "ConfigItemAdd() - new config item $Name (ID: $ConfigItemID)",
    );

    if ($ConfigItemID) {
        $ConfigItemIDs{$Name} = $ConfigItemID;
    }

    my $VersionID = $ConfigItemObject->VersionAdd(
        ConfigItemID => $ConfigItemID,
        Name         => $Name,
        DefinitionID => $DefinitionList{$Class}->[0]->{DefinitionID},
        DeplStateID  => $DeplStateListReverse{Production},
        InciStateID  => $InciStateListReverse{Operational},
        UserID       => 1,
    );
    $Self->True(
        $VersionID,
        "VersionAdd() - for config item $Name",
    );

    # discard config item object to process events
    $Kernel::OM->ObjectsDiscard( Objects => ['ITSMConfigItem'] );
}

# define the links
my %Links = (
    'Test2-Computer' => {
        DependsOn => ['Test1-Computer']
    },
    'Test3-Computer' => {
        DependsOn => ['Test1-Computer','Test2-Computer']
    },
    'Test4-Computer' => {
        AlternativeTo => ['Test2-Computer']
    },
    'Test5-Hardware' => {
        DependsOn => ['Test3-Computer']
    },
    'Test6-Hardware' => {
        DependsOn => ['Test3-Computer']
    },
    'Test7-Hardware' => {
        DependsOn => ['Test5-Hardware','Test6-Hardware']
    },
    'Test8-Hardware' => {
        DependsOn => ['Test4-Computer']
    },
    'Test9-Software' => {
        DependsOn => ['Test8-Hardware']
    },
    'Test10-Software' => {
        DependsOn => ['Test8-Hardware']
    },
);

# create the links
SOURCE:
foreach my $Source ( sort keys %Links ) {
    LINK:
    foreach my $LinkType ( sort keys %{$Links{$Source}} ) {
        TARGET:
        foreach my $Target ( @{$Links{$Source}->{$LinkType}} ) {
            $LinkObject->LinkAdd(
                SourceObject => 'ConfigItem',
                SourceKey    => $ConfigItemIDs{$Source},
                TargetObject => 'ConfigItem',
                TargetKey    => $ConfigItemIDs{$Target},
                Type         => $LinkType,
                State        => 'Valid',
                UserID       => 1,
            );
        }
    }
}

# define the tests
my @Tests = (
    {
        Name  => 'without any config',
        Input => {
            ConfigItemID => $ConfigItemIDs{'Test1-Computer'}
        },
        Expect => {
            Nodes => [
                'Test1-Computer','Test2-Computer','Test3-Computer','Test4-Computer',
                'Test5-Hardware','Test6-Hardware','Test7-Hardware','Test8-Hardware',
                'Test9-Software','Test10-Software'
            ],
            Links => [
                {
                    Source => 'Test2-Computer',
                    Target => 'Test1-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test3-Computer',
                    Target => 'Test2-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test4-Computer',
                    Target => 'Test2-Computer',
                    Type   => 'AlternativeTo'
                },
                {
                    Source => 'Test5-Hardware',
                    Target => 'Test3-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test6-Hardware',
                    Target => 'Test3-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test7-Hardware',
                    Target => 'Test6-Hardware',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test8-Hardware',
                    Target => 'Test4-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test9-Software',
                    Target => 'Test8-Hardware',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test10-Software',
                    Target => 'Test8-Hardware',
                    Type   => 'DependsOn'
                },
            ]
        }
    },
    {
        Name  => 'with MaxDepth 1',
        Input => {
            ConfigItemID => $ConfigItemIDs{'Test1-Computer'},
            Config       => {
                MaxDepth => 1
            }
        },
        Expect => {
            Nodes => [
                'Test1-Computer','Test2-Computer','Test3-Computer'
            ],
            Links => [
                {
                    Source => 'Test2-Computer',
                    Target => 'Test1-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test3-Computer',
                    Target => 'Test2-Computer',
                    Type   => 'DependsOn'
                },
            ]
        }
    },
    {
        Name  => 'with MaxDepth 2',
        Input => {
            ConfigItemID => $ConfigItemIDs{'Test1-Computer'},
            Config       => {
                MaxDepth => 2
            }
        },
        Expect => {
            Nodes => [
                'Test1-Computer','Test2-Computer','Test3-Computer','Test4-Computer',
            ],
            Links => [
                {
                    Source => 'Test2-Computer',
                    Target => 'Test1-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test3-Computer',
                    Target => 'Test2-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test4-Computer',
                    Target => 'Test2-Computer',
                    Type   => 'AlternativeTo'
                },
            ]
        }
    },
    {
        Name  => 'with MaxDepth 3',
        Input => {
            ConfigItemID => $ConfigItemIDs{'Test1-Computer'},
            Config       => {
                MaxDepth => 3
            }
        },
        Expect => {
            Nodes => [
                'Test1-Computer','Test2-Computer','Test3-Computer','Test4-Computer',
                'Test5-Hardware','Test6-Hardware','Test8-Hardware',
            ],
            Links => [
                {
                    Source => 'Test2-Computer',
                    Target => 'Test1-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test3-Computer',
                    Target => 'Test2-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test4-Computer',
                    Target => 'Test2-Computer',
                    Type   => 'AlternativeTo'
                },
                {
                    Source => 'Test5-Hardware',
                    Target => 'Test3-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test6-Hardware',
                    Target => 'Test3-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test8-Hardware',
                    Target => 'Test4-Computer',
                    Type   => 'DependsOn'
                },
            ]
        }
    },
    {
        Name  => 'with RelevantLinkTypes "AlternativeTo"',
        Input => {
            ConfigItemID => $ConfigItemIDs{'Test1-Computer'},
            Config       => {
                RelevantLinkTypes => ['AlternativeTo'],
            }
        },
        Expect => {
            Nodes => ['Test1-Computer'],
            Links => []
        }
    },
    {
        Name  => 'with RelevantClasses "Computer"',
        Input => {
            ConfigItemID => $ConfigItemIDs{'Test1-Computer'},
            Config       => {
                RelevantClasses => ['Computer'],
            }
        },
        Expect => {
            Nodes => [
                'Test1-Computer','Test2-Computer','Test3-Computer','Test4-Computer',
            ],
            Links => [
                {
                    Source => 'Test2-Computer',
                    Target => 'Test1-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test3-Computer',
                    Target => 'Test2-Computer',
                    Type   => 'DependsOn'
                },
                {
                    Source => 'Test4-Computer',
                    Target => 'Test2-Computer',
                    Type   => 'AlternativeTo'
                },
            ]
        }
    },
    {
        Name  => 'with RelevantClasses "Hardware"',
        Input => {
            ConfigItemID => $ConfigItemIDs{'Test1-Computer'},
            Config       => {
                RelevantClasses => ['Hardware'],
            }
        },
        Expect => {
            Nodes => ['Test1-Computer'],
            Links => []
        }
    }
);

# execute the tests
foreach my $Test ( @Tests ) {
    # generate the graph
    my $Graph = $ConfigItemObject->GenerateLinkGraph(
        %{$Test->{Input}},
        UserID => 1,
    );

    my %Nodes = map { $_->{Object}->{Name} => $_->{NodeID} } @{$Graph->{Nodes}};

    my %Links;
    foreach my $Link ( @{$Graph->{Links}} ) {
        $Links{$Link->{SourceNodeID}}->{$Link->{TargetNodeID}}->{$Link->{LinkType}} = $Link
    };

    # check expectations
    $Self->IsDeeply(
        [ sort keys %Nodes ],
        [ sort @{$Test->{Expect}->{Nodes}} ],
        'Test: ' . $Test->{Name} . ' - nodes'
    );

    foreach my $Link ( @{$Test->{Expect}->{Links}} ) {
        my $FoundLink = $Links{$Nodes{$Link->{Source}||''}||''}->{$Nodes{$Link->{Target}||''}||''}->{$Link->{Type}||''};

        $Self->True(
            $FoundLink,
            'Test: ' . $Test->{Name} . " - link $Link->{Source} -> $Link->{Target} ($Link->{Type})"
        )
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
