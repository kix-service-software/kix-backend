# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get MacroAction object
my $AutomationObject = $Kernel::OM->Get('Automation');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $TextContent = $Kernel::OM->Get('Main')->FileRead(
    Location => $Kernel::OM->Get('Config')->Get('Home') . '/scripts/test/system/sample/Automation/MacroAction/test.txt',
    Mode     => 'binmode'
);
$Self->True(
    $TextContent,
    'load test.txt',
);
my $TestPNGBase64 = ${$TextContent};
my $PNGContent = $Kernel::OM->Get('Main')->FileRead(
    Location => $Kernel::OM->Get('Config')->Get('Home') . '/scripts/test/system/sample/Automation/MacroAction/test.png',
    Mode     => 'binmode'
);
$Self->True(
    $PNGContent,
    'load test.png',
);
my $TestPNGBin = ${$PNGContent};
my $TestPNGBinJSON = $Kernel::OM->Get('JSON')->Encode(
    Data => $TestPNGBin
);

my $NameRandom  = $Helper->GetRandomID();
my %MacroActions = (
    'test-macroaction-' . $NameRandom . '-1' => {
        Type => 'TitleSet',
        NewType => 'StateSet',
        Parameters => {
            Title => 'test',
        }
    },
    'test-macroaction-' . $NameRandom . '-2' => {
        Type => 'StateSet',
        Parameters => {
            State => 'open',
        }
    },
    'test-macroaction-' . $NameRandom . '-3' => {
        Type => 'PrioritySet',
        Parameters => {
            Priority => '3 normal'
        }
    },
);

# create macro
my $MacroID = $AutomationObject->MacroAdd(
    Name    => 'test-macro-' . $NameRandom,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroID,
    'MacroAdd() for new macro.',
);

# try to add macroactions
for my $Name ( sort keys %MacroActions ) {
    my $MacroActionID = $AutomationObject->MacroActionAdd(
        MacroID => $MacroID,
        Type    => $MacroActions{$Name}->{Type},
        Parameters => $MacroActions{$Name}->{Parameters},
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $MacroActionID,
        'MacroActionAdd() for new macro action ' . $Name,
    );

    if ($MacroActionID) {
        $MacroActions{$Name}->{ID} = $MacroActionID;
    }
    my %MacroAction = $AutomationObject->MacroActionGet(
        ID => $MacroActionID
    );

    $Self->Is(
        $MacroAction{Type},
        $MacroActions{$Name}->{Type},
        'MacroActionGet() for macro action ' . $Name,
    );
}

# list MacroActions
my %MacroActionList = $AutomationObject->MacroActionList(
    MacroID => $MacroID
);
for my $Name ( sort keys %MacroActions ) {
    my $MacroActionID = $MacroActions{$Name}->{ID};

    $Self->True(
        exists $MacroActionList{$MacroActionID} && $MacroActionList{$MacroActionID} eq $MacroActions{$Name}->{Type},
        'MacroActionList() contains macro action ' . $Name . ' with ID ' . $MacroActionID,
    );
}

# change type of a single MacroAction
my $NameToChange = 'test-macroaction-' . $NameRandom . '-1';
my $IDToChange   = $MacroActions{$NameToChange}->{ID};

my $MacroActionUpdateResult = $AutomationObject->MacroActionUpdate(
    ID      => $IDToChange,
    Type    => $MacroActions{$NameToChange}->{NewType},
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroActionUpdateResult,
    'MacroActionUpdate() for changing type of macro action ' . $NameToChange . ' to ' . $MacroActions{$NameToChange}->{NewType},
);

# update parameters of a single MacroAction
$MacroActionUpdateResult = $AutomationObject->MacroActionUpdate(
    ID      => $IDToChange,
    Type    => $MacroActions{$NameToChange}->{NewType},
    Parameters => {
        State => 'new'
    },
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroActionUpdateResult,
    'MacroActionUpdate() for changing parameters of macro action.',
);

my %MacroAction = $AutomationObject->MacroActionGet( ID => $IDToChange );

$Self->True(
    $MacroAction{Parameters},
    'MacroActionGet() for macro action with parameters.',
);

# delete an existing macroaction
my $MacroActionDelete = $AutomationObject->MacroActionDelete(
    ID      => $IDToChange,
    UserID  => 1,
);

$Self->True(
    $MacroActionDelete,
    'MacroActionDelete() delete existing macroaction',
);

# delete a non existent macroaction
$MacroActionDelete = $AutomationObject->MacroActionDelete(
    ID      => 9999,
    UserID  => 1,
    Silent  => 1
);

$Self->False(
    $MacroActionDelete,
    'MacroActionDelete() delete non existent macroaction',
);

# check variable replacement
my @Tests = (
    {
        Name => 'simple',
        MacroResults => {
            Test1 => 'test1_value',
        },
        Data => {
            Dummy => '${Test1}',
        },
        Expected => {
            Dummy => 'test1_value',
        }
    },
    {
        Name => 'simple as part of a string',
        MacroResults => {
            Test1 => 'test1_value',
        },
        Data => {
            Dummy => '${Test1}/dummy',
        },
        Expected => {
            Dummy => 'test1_value/dummy',
        }
    },
    {
        Name => 'array',
        MacroResults => {
            Test1 => [
                1,2,3
            ]
        },
        Data => {
            Dummy => '${Test1:1}',
        },
        Expected => {
            Dummy => '2',
        }
    },
    {
        Name => 'hash',
        MacroResults => {
            Test1 => {
                Test2 => 'test2'
            }
        },
        Data => {
            Dummy => '${Test1.Test2}',
        },
        Expected => {
            Dummy => 'test2',
        }
    },
    {
        Name => 'array of hashes with arrays of hashes',
        MacroResults => {
            Test1 => [
                {},
                {
                    Test2 => [
                        {
                            Test3 => 'test3'
                        }
                    ]
                }
            ]
        },
        Data => {
            Dummy => '${Test1:1.Test2:0.Test3}',
        },
        Expected => {
            Dummy => 'test3',
        }
    },
    {
        Name => 'array of hashes with arrays of hashes in text',
        MacroResults => {
            Test1 => [
                {},
                {
                    Test2 => [
                        {
                            Test3 => 'test'
                        }
                    ]
                }
            ]
        },
        Data => {
            Dummy => 'this is a ${Test1:1.Test2:0.Test3}. a good one',
        },
        Expected => {
            Dummy => 'this is a test. a good one',
        }
    },
    {
        Name => 'array of hashes with arrays of hashes direct assignment of structure',
        MacroResults => {
            Test1 => [
                {},
                {
                    Test2 => [
                        {
                            Test3 => 'test'
                        }
                    ]
                }
            ]
        },
        Data => {
            Dummy => '${Test1:1.Test2}',
        },
        Expected => {
            Dummy => [
                {
                    Test3 => 'test'
                }
            ]
        }
    },
    {
        Name => 'nested variables (2 levels)',
        MacroResults => {
            Test1 => {
                Test2 => {
                    Test3 => 'found!'
                }
            },
            Indexes => {
                '1st' => 'Test2',
                '2nd' => 'Test3'
            }
        },
        Data => {
            Dummy => '${Test1.${Indexes.1st}.${Indexes.2nd}}',
        },
        Expected => {
            Dummy => 'found!'
        }
    },
    {
        Name => 'nested variables (4 levels)',
        MacroResults => {
            Test1 => {
                Test2 => {
                    Test3 => 'found!'
                }
            },
            Indexes => {
                '1st' => 'Test2',
                '2nd' => 'Test3'
            },
            Which => {
                'the first one' => '1st',
                Index => {
                    Should => {
                        I => {
                            Use => [
                                'none',
                                '2nd',
                                'the first one',
                                '3rd'
                            ]
                        }
                    }
                }
            },
        },
        Data => {
            Dummy => '${Test1.${Indexes.${Which.${Which.Index.Should.I.Use:2}}}.${Indexes.2nd}}',
        },
        Expected => {
            Dummy => 'found!'
        }
    },
    {
        Name => 'nested variable in filter',
        MacroResults => {
            Variable1 => '2022-10-01 12:22:33',
            Variable2 => 3,
            Variable3 => 'TimeStamp'
        },
        Data => {
            Result => '${Variable1|DateUtil.Calc(+${Variable2}M)|DateUtil.UnixTime|DateUtil.${Variable3}}',
        },
        Expected => {
            Result => '2023-01-01 12:22:33'
        }
    },
    {
        Name => 'base64 filter',
        MacroResults => {
            Variable1 => 'test123',
        },
        Data => {
            Result => '
1: ${Variable1|base64}
2: ${Variable1|ToBase64}
3: ${Variable1|ToBase64|FromBase64}
',
        },
        Expected => {
            Result => '
1: dGVzdDEyMw==
2: dGVzdDEyMw==
3: test123
'
        }
    },
    {
        Name => 'base64 filter with binary content containing pipe characters',
        MacroResults => {
            Variable1 => $TestPNGBase64,
        },
        Data => {
            Result => '${Variable1|FromBase64}',
        },
        Expected => {
            Result => $TestPNGBin,
        }
    },
    {
        Name => 'base64 filter with binary content containing pipe characters in json-text',
        MacroResults => {
            Article => {
                Attachments => [
                    {
                        Filename    => 'test.png',
                        ContentType => 'image/png',
                        Content     => $TestPNGBase64,
                    }
                ]
            },
        },
        Data => {
            Result => <<'END'
[
    {
        "file": [
            null,
            "${Article.Attachments:0.Filename}",
            {
                "content-type": "${Article.Attachments:0.ContentType}"
            },
            {
                "content": "${Article.Attachments:0.Content|FromBase64|ToJSON}"
            }
        ]
    }
]
END
        },
        Expected => {
            Result => <<"END"
[
    {
        "file": [
            null,
            "test.png",
            {
                "content-type": "image/png"
            },
            {
                "content": $TestPNGBinJSON
            }
        ]
    }
]
END
        }
    },
    {
        Name => 'JSON filter in text',
        MacroResults => {
            Variable1 => {
                key => 'test123',
            }
        },
        Data => {
            Result => '
1: ${Variable1|JSON}
2: ${Variable1|ToJSON}
',
        },
        Expected => {
            Result => '
1: {"key":"test123"}
2: {"key":"test123"}
'
        }
    },
    {
        Name => 'JSON filter as object assignment',
        MacroResults => {
            Variable1 => {
                key => 'test123',
            }
        },
        Data => {
            Result => '${Variable1|ToJSON|FromJSON}',
        },
        Expected => {
            Result => {
                key => 'test123',
            }
        }
    },
    {
        Name => 'jq filter',
        MacroResults => {
            Variable1 => '[
                { "Key": 1, "Value": 1111, "Flag": "a" },
                { "Key": 2, "Value": 2222, "Flag": "b" },
                { "Key": 3, "Value": 3333, "Flag": "a" }
            ]'
        },
        Data => {
            Result => '${Variable1|jq(. - map(. :: select(.Flag=="b")) :: .[] .Key)}',
        },
        Expected => {
            Result => '1
3',
        }
    },
    {
        Name => 'Combine variables as array',
        MacroResults => {
            Test1 => 'Test1',
            Test2 => 'Test2',
        },
        Data => {
            Dummy => '${Test1,Test2}',
        },
        Expected => {
            Dummy => ['Test1','Test2'],
        }
    },
    {
        Name => 'Combine variables containing arrays as array',
        MacroResults => {
            Test1 => [
                'Test1.1',
                'Test1.2'
            ],
            Test2 => [
                'Test2.1',
                'Test2.2'
            ],
        },
        Data => {
            Dummy => '${Test1,Test2}',
        },
        Expected => {
            Dummy => ['Test1.1','Test1.2','Test2.1','Test2.2'],
        }
    },
);

# load additional filter
$AutomationObject->_GetVariableFilter();

my $TestCount = 0;
foreach my $Test ( @Tests ) {
    $TestCount++;

    $AutomationObject->{MacroResults} = $Test->{MacroResults};

    my %Data = %{$Test->{Data}};

    $AutomationObject->_ReplaceResultVariables(
        Data => \%Data,
    );

    $Self->IsDeeply(
        \%Data,
        $Test->{Expected},
        '_ReplaceResultVariables() Test "'.$Test->{Name}.'"',
    );
}

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
