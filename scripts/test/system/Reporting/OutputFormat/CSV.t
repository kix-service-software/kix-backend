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

use Kernel::System::VariableCheck qw(:all);
use vars (qw($Self));

# get ReportDefinition object
my $ReportingObject = $Kernel::OM->Get('Reporting');

#
# log tests
#

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my @ConfigTests = (
    {
        Test   => 'no config',
        Config => undef,
        Expect => 1
    },
    {
        Test   => 'empty config',
        Config => {},
        Expect => 1,
    },
    {
        Test   => 'wrong config',
        Config => {
            dummy => 'test'
        },
        Expect => 1,
    },
    {
        Test   => 'invalid Columns',
        Config => {
            Columns => 'abc'
        },
        Expect => undef,
    },
    {
        Test   => 'invalid Separator',
        Config => {
            Separator => ''
        },
        Expect => undef,
    },
    {
        Test   => 'invalid Quote',
        Config => {
            Quote => ''
        },
        Expect => undef,
    },
    {
        Test   => 'invalid language',
        Config => {
            TranslateColumnNames => 'cn'
        },
        Expect => undef,
    },
    {
        Test   => 'valid Config - only columns',
        Config => {
            Columns => ['ColumnA']
        },
        Expect => 1,
    },
    {
        Test   => 'valid Config - complete',
        Config => {
            Columns             => ['ColumnC', 'ColumnA', 'ColumnB'],
            Quote               => "'",
            Separator           => ';',
            IncludeColumnHeader => 1,
            Title               => 'This is a test',
        },
        Expect => 1
    },
);

foreach my $Test ( @ConfigTests ) {
    # wrong config
    my $Result = $ReportingObject->OutputFormatValidateConfig(
        Format => 'CSV',
        Config => $Test->{Config}
    );

    if ( ! ref $Test->{Expect} ) {
        $Self->Is(
            $Result,
            $Test->{Expect},
            'OutputFormatValidateConfig() - '.$Test->{Test},
        );
    }
    else {
        $Self->IsDeeply(
            $Result,
            $Test->{Expect},
            'OutputFormatValidateConfig() - '.$Test->{Test},
        );
    }
}

my @DataTests = (
    {
        Test   => 'only one column from multiple in data',
        Config => {
            OutputFormats => {
                CSV => {
                    Columns => ['ColumnA']
                }
            }
        },
        Data => {
            Columns => ['ColumnA', 'ColumnB', 'ColumnC'],
            Data   => [
                {
                    ColumnA => 'line 1: column A content',
                    ColumnB => 'line 1: column B content',
                    ColumnC => 'line 1: column C content',
                },
                {
                    ColumnA => 'line 2: column A content',
                    ColumnB => 'line 2: column B content',
                    ColumnC => 'line 2: column C content',
                },
                {
                    ColumnA => 'line 3: column A content',
                    ColumnB => 'line 3: column B content',
                    ColumnC => 'line 3: column C content',
                },
            ],
        },
        Expect => {
            ContentType => 'text/csv',
            Content     => [
                '"ColumnA"',
                '"line 1: column A content"',
                '"line 2: column A content"',
                '"line 3: column A content"',
                ''
            ]
        }
    },
    {
        Test   => 'only one column from multiple in data but without column header',
        Config => {
            OutputFormats => {
                CSV => {
                    Columns => ['ColumnA'],
                    IncludeColumnHeader => 0
                }
            }
        },
        Data => {
            Columns => ['ColumnA', 'ColumnB', 'ColumnC'],
            Data   => [
                {
                    ColumnA => 'line 1: column A content',
                    ColumnB => 'line 1: column B content',
                    ColumnC => 'line 1: column C content',
                },
                {
                    ColumnA => 'line 2: column A content',
                    ColumnB => 'line 2: column B content',
                    ColumnC => 'line 2: column C content',
                },
                {
                    ColumnA => 'line 3: column A content',
                    ColumnB => 'line 3: column B content',
                    ColumnC => 'line 3: column C content',
                },
            ],
        },
        Expect => {
            ContentType => 'text/csv',
            Content     => [
                '"line 1: column A content"',
                '"line 2: column A content"',
                '"line 3: column A content"',
                ''
            ]
        }
    },
    {
        Test   => 'multiple columns in different order + quote + separator + header + title',
        Config => {
            OutputFormats => {
                CSV => {
                    Columns             => ['ColumnC', 'ColumnA', 'ColumnB'],
                    Quote               => "'",
                    Separator           => ';',
                    IncludeColumnHeader => 1,
                    Title               => 'This is a test',
                }
            }
        },
        Data => {
            Columns => ['ColumnA', 'ColumnB', 'ColumnC'],
            Data   => [
                {
                    ColumnA => 'line 1: column A content',
                    ColumnB => 'line 1: column B content',
                    ColumnC => 'line 1: column C content',
                },
                {
                    ColumnA => 'line 2: column A content',
                    ColumnB => 'line 2: column B content',
                    ColumnC => 'line 2: column C content',
                },
                {
                    ColumnA => 'line 3: column A content',
                    ColumnB => 'line 3: column B content',
                    ColumnC => 'line 3: column C content',
                },
            ],
        },
        Expect => {
            ContentType => 'text/csv',
            Content     => [
                "'This is a test'",
                "'ColumnC';'ColumnA';'ColumnB'",
                "'line 1: column C content';'line 1: column A content';'line 1: column B content'",
                "'line 2: column C content';'line 2: column A content';'line 2: column B content'",
                "'line 3: column C content';'line 3: column A content';'line 3: column B content'",
                ""
            ]
        }
    },
    {
        Test   => 'config - use defaults',
        Config => {
            OutputFormats => {
                CSV => {
                }
            }
        },
        Data => {
            Columns => ['ColumnA', 'ColumnB', 'ColumnC'],
            Data   => [
                {
                    ColumnA => 'line 1: column A content',
                    ColumnB => 'line 1: column B content',
                    ColumnC => 'line 1: column C content',
                },
                {
                    ColumnA => 'line 2: column A content',
                    ColumnB => 'line 2: column B content',
                    ColumnC => 'line 2: column C content',
                },
                {
                    ColumnA => 'line 3: column A content',
                    ColumnB => 'line 3: column B content',
                    ColumnC => 'line 3: column C content',
                },
            ],
        },
        Expect => {
            ContentType => 'text/csv',
            Content     => [
                '"ColumnA";"ColumnB";"ColumnC"',
                '"line 1: column A content";"line 1: column B content";"line 1: column C content"',
                '"line 2: column A content";"line 2: column B content";"line 2: column C content"',
                '"line 3: column A content";"line 3: column B content";"line 3: column C content"',
                ""
            ]
        }
    },
    {
        Test   => 'translate columns',
        Config => {
            OutputFormats => {
                CSV => {
                    TranslateColumnNames => 1
                }
            }
        },
        Data => {
            Columns => ['new', 'open', 'closed'],
            Data   => [],
        },
        Expect => {
            ContentType => 'text/csv',
            Content     => [
                '"neu";"offen";"geschlossen"',
                ""
            ]
        }
    },
    {
        Test   => 'translate columns with given language',
        Config => {
            OutputFormats => {
                CSV => {
                    TranslateColumnNames => 'de'
                }
            }
        },
        Data => {
            Columns => ['new', 'open', 'closed'],
            Data   => [],
        },
        Expect => {
            ContentType => 'text/csv',
            Content     => [
                '"neu";"offen";"geschlossen"',
                ""
            ]
        }
    },
    {
        Test   => 'do not translate columns',
        Config => {
            OutputFormats => {
                CSV => {
                    TranslateColumnNames => 0
                }
            }
        },
        Data => {
            Columns => ['new', 'open', 'closed'],
            Data   => [],
        },
        Expect => {
            ContentType => 'text/csv',
            Content     => [
                '"new";"open";"closed"',
                ""
            ]
        }
    },
    {
        Test   => 'columns with spaces',
        Config => {
            OutputFormats => {
                CSV => {
                    TranslateColumnNames => 0
                }
            }
        },
        Data => {
            Columns => ['this is a test'],
            Data   => [],
        },
        Expect => {
            ContentType => 'text/csv',
            Content     => [
                '"this is a test"',
                ""
            ]
        }
    },
);

foreach my $Test ( @DataTests ) {
    # wrong config
    my $Result = $ReportingObject->GenerateOutput(
        Format => 'CSV',
        Config => $Test->{Config},
        Data   => $Test->{Data}
    );

    my $ExpectedContent = join("\n", @{$Test->{Expect}->{Content}});

    $Self->Is(
        $Result->{ContentType},
        $Test->{Expect}->{ContentType},
        'GenerateOutput() - content type '.$Test->{Test},
    );

    $Self->Is(
        $Result->{Content},
        $ExpectedContent,
        'GenerateOutput() - content '.$Test->{Test},
    );
}

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
