# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;
use File::Path;

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

my $Home = $Kernel::OM->Get('Config')->Get('Home');
my $Success = mkdir( "$Home/plugins/test", 0770 );

$Self->True(
    $Success,
    'Create Plugin Directory',
);

$Success = $Kernel::OM->Get('Main')->FileWrite(
    Location => "$Home/plugins/test/RELEASE",
    Content  => \"PRODUCT = test"
);

$Self->True(
    $Success,
    'Create RELEASE file',
);

my @ConfigTests = (
    {
        Test   => 'no config',
        Config => undef,
        Expect => undef
    },
    {
        Test   => 'empty config',
        Config => {},
        Expect => undef,
    },
    {
        Test   => 'wrong config - SQL missing',
        Config => {
            dummy => 'test'
        },
        Expect => undef,
    },
    {
        Test   => 'invalid SQL option (not a hash)',
        Config => {
            SQL => 'from test'
        },
        Expect => undef,
    },
    {
        Test   => 'invalid SQL - unsupported DBMS',
        Config => {
            SQL => {
                oracle => 'from test'
            }
        },
        Expect => undef,
    },
    {
        Test   => 'wrong SQL (no SELECT)',
        Config => {
            SQL => {
                any => 'INSERT INTO test VALUES (1)'
            }
        },
        Expect => undef,
    },
    {
        Test   => 'valid SQL with wildcard column list',
        Config => {
            SQL => {
                any => 'SELECT * FROM valid'
            }
        },
        Expect => ['id','name', 'create_time', 'create_by', 'change_time', 'change_by'],
    },
    {
        Test   => 'valid SQL but not all columnes explicitly listed',
        Config => {
            SQL => {
                any => 'SELECT *, create_by FROM valid'
            }
        },
        Expect => ['id','name', 'create_time', 'create_by', 'change_time', 'change_by', 'create_by'],
    },
    {
        Test   => 'valid SQL',
        Config => {
            SQL => {
                any => 'SELECT id, name, create_by FROM valid'
            }
        },
        Expect => ['id','name','create_by'],
    },
    {
        Test   => 'valid SQL with table alias',
        Config => {
            SQL => {
                any => 'SELECT t1.id,t1.name,t1.create_by FROM valid t1'
            }
        },
        Expect => ['id','name','create_by'],
    },
    {
        Test   => 'valid SQL with table alias mixed',
        Config => {
            SQL => {
                any => 'SELECT t1.id,t1.name,create_by FROM valid t1'
            }
        },
        Expect => ['id','name','create_by'],
    },
    {
        Test   => 'valid SQL with column alias',
        Config => {
            SQL => {
                any => 'SELECT id AS x,name AS y,create_by AS z FROM valid'
            }
        },
        Expect => ['x','y','z'],
    },
    {
        Test   => 'valid SQL with column alias mixed',
        Config => {
            SQL => {
                any => 'SELECT id AS x,name AS y,create_by FROM valid'
            }
        },
        Expect => ['x','y','create_by'],
    },
    {
        Test   => 'valid SQL with column alias and table alias',
        Config => {
            SQL => {
                any => 'SELECT t1.id AS x,t1.name AS y,t1.create_by AS z FROM valid t1'
            }
        },
        Expect => ['x','y','z'],
    },
    {
        Test   => 'valid SQL with column alias and table alias mixed',
        Config => {
            SQL => {
                any => 'SELECT t1.id AS x,t1.name AS y,create_by FROM valid t1'
            }
        },
        Expect => ['x','y','create_by'],
    },
    {
        Test   => 'invalid SQL with column alias, table alias mixed and two tables (missing WHERE clause)',
        Config => {
            SQL => {
                any => 'SELECT t1.id AS x,t1.name AS y,t1.create_by AS z FROM valid t1, ticket_type'
            }
        },
        Expect => ['x','y','z'],
    },
    {
        Test   => 'valid SQL with column alias, table alias mixed and two tables',
        Config => {
            SQL => {
                any => 'SELECT t1.id AS x,t1.name AS y,t1.create_by AS z FROM valid t1, ticket_type WHERE t1.id = ticket_type.id'
            }
        },
        Expect => ['x','y','z'],
    },
    {
        Test   => 'valid SQL with column alias, table alias, mixed, two tables and ORDER BY',
        Config => {
            SQL => {
                any => 'SELECT t1.id AS x,t1.name AS y,t1.create_by AS z FROM valid t1, ticket_type WHERE t1.id = ticket_type.id ORDER BY t1.id, t1.name'
            }
        },
        Expect => ['x','y','z'],
    },
    {
        Test   => 'valid SQL with column alias, table alias, mixed, two tables, ORDER BY and GROUP BY',
        Config => {
            SQL => {
                any => 'SELECT t1.id AS x,sum(ticket_type.id) AS y FROM valid t1, ticket_type WHERE t1.id = ticket_type.id GROUP BY t1.id ORDER BY t1.id'
            }
        },
        Expect => ['x','y'],
    },
    {
        Test   => 'valid SQL with single SUM function',
        Config => {
            SQL => {
                any => 'SELECT sum(id) AS total FROM valid'
            }
        },
        Expect => ['total'],
    },
    {
        Test   => 'valid SQL with a single COUNT function',
        Config => {
            SQL => {
                any => 'SELECT count(*) AS total FROM valid'
            }
        },
        Expect => ['total'],
    },
);

foreach my $Test ( @ConfigTests ) {
    # wrong config
    my $Result = $ReportingObject->DataSourceGetProperties(
        Source => 'GenericSQL',
        Config => {
            DataSource => $Test->{Config}
        }
    );

    if ( ! ref $Test->{Expect} ) {
        $Self->Is(
            $Result,
            $Test->{Expect},
            'GetProperties() - '.$Test->{Test},
        );
    }
    else {
        $Self->IsDeeply(
            $Result,
            $Test->{Expect},
            'GetProperties() - '.$Test->{Test},
        );
    }
}

my @DataTests = (
    {
        Test   => 'simple count SELECT',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT COUNT(*) AS item_count FROM valid'
                }
            }
        },
        Expect => {
            Columns => ['item_count'],
            Data => [
                { item_count => 3 }
            ]
        }
    },
    {
        Test   => 'simple row SELECT',
        Config => {
            DataSource => {
                SQL => {
                    any => 'SELECT id, name FROM valid ORDER BY id'
                }
            }
        },
        Expect => {
            Columns => ['id', 'name'],
            Data => [
                { id => 1, name => 'valid' },
                { id => 2, name => 'invalid' },
                { id => 3, name => 'invalid-temporarily' }
            ]
        }
    },
    {
        Test   => 'simple row SELECT with WHERE clause and LIMIT',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name FROM valid WHERE name LIKE 'in%' ORDER BY id LIMIT 1"
                }
            }
        },
        Expect => {
            Columns => ['id', 'name'],
            Data => [
                { id => 2, name => 'invalid' }
            ],
        }
    },
    {
        Test   => 'simple row SELECT with WHERE variable',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name FROM valid WHERE name LIKE '\${Parameters.NameVar}%' ORDER BY id LIMIT 1"
                },
            },
            Parameters => [
                {
                    Name => 'NameVar',
                    DataType => 'STRING'
                }
            ]
        },
        Parameters => {
            NameVar => 'inv'
        },
        Expect => {
            Columns => ['id', 'name'],
            Data => [
                { id => 2, name => 'invalid' }
            ],
        }
    },
    {
        Test   => 'simple row SELECT with WHERE variable and fallback',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name FROM valid WHERE name LIKE '\${Parameters.NameVar?inv}%' ORDER BY id LIMIT 1"
                },
            },
            Parameters => [
                {
                    Name => 'NameVar',
                    DataType => 'STRING'
                }
            ]
        },
        Expect => {
            Columns => ['id', 'name'],
            Data => [
                { id => 2, name => 'invalid' }
            ],
        }
    },
    {
        Test   => 'simple row SELECT with WHERE variable as array',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name FROM valid WHERE id IN (\${Parameters.IDList})"
                },
            },
            Parameters => [
                {
                    Name => 'IDList',
                    DataType => 'NUMERIC'
                }
            ]
        },
        Parameters => {
            IDList => [1,2]
        },
        Expect => {
            Columns => ['id', 'name'],
            Data => [
                { id => 1, name => 'valid' },
                { id => 2, name => 'invalid' }
            ],
        }
    },
    {
        Test   => 'simple row SELECT with WHERE variable with default',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name FROM valid WHERE id IN (\${Parameters.IDList})"
                },
            },
            Parameters => [
                {
                    Name => 'IDList',
                    DataType => 'NUMERIC',
                    Default => [1,2]
                }
            ]
        },
        Expect => {
            Columns => ['id', 'name'],
            Data => [
                { id => 1, name => 'valid' },
                { id => 2, name => 'invalid' }
            ],
        }
    },
    {
        Test   => 'simple row SELECT with a part in a fallback',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name FROM valid \${Parameters.NameVar?WHERE name LIKE 'inv%'} ORDER BY id LIMIT 1"
                },
            },
            Parameters => [
                {
                    Name => 'NameVar',
                    DataType => 'STRING'
                }
            ]
        },
        Expect => {
            Columns => ['id', 'name'],
            Data => [
                { id => 2, name => 'invalid' }
            ],
        }
    },
    {
        Test   => 'simple row SELECT with non-sucessful function',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name \${Functions.if_plugin_available('none', ',create_by')} FROM valid WHERE id = 1"
                },
            },
        },
        Expect => {
            Columns => ['id', 'name'],
            Data => [
                { id => 1, name => 'valid' },
            ],
        }
    },
    {
        Test   => 'simple row SELECT with sucessful function',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name \${Functions.if_plugin_available('test', ',create_by')} FROM valid WHERE id = 1"
                },
            },
        },
        Expect => {
            Columns => ['id', 'name', 'create_by'],
            Data => [
                { id => 1, name => 'valid', create_by => 1 },
            ],
        }
    },
    {
        Test   => 'simple row SELECT with sucessful function and parameter',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name \${Functions.if_plugin_available('test', ',\${Parameters.AdditionalColumn}')} FROM valid WHERE id = 1"
                },
            },
            Parameters => [
                {
                    Name => 'AdditionalColumn',
                    DataType => 'STRING',
                    Default => 'create_by'
                }
            ]
        },
        Expect => {
            Columns => ['id', 'name', 'create_by'],
            Data => [
                { id => 1, name => 'valid', create_by => 1 },
            ],
        }
    },
    {
        Test   => 'simple row SELECT with sucessful multiline function and parameter',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name \${Functions.if_plugin_available('test', ',
                    \'dummy\' as test,
                    \${Parameters.AdditionalColumn},
                    change_by'
                    )} FROM valid WHERE id = 1"
                },
            },
            Parameters => [
                {
                    Name => 'AdditionalColumn',
                    DataType => 'STRING',
                    Default => 'create_by'
                }
            ]
        },
        Expect => {
            Columns => ['id', 'name', 'test', 'create_by', 'change_by'],
            Data => [
                { id => 1, name => 'valid', test => 'dummy', create_by => 1, change_by => 1},
            ],
        }
    },
    {
        Test   => 'simple row SELECT with two sucessful functions',
        Config => {
            DataSource => {
                SQL => {
                    any => "SELECT id, name
                    \${Functions.if_plugin_available('test', ',\'dummy\' as test')}
                    \${Functions.if_plugin_available('test', ',\'hello\' as test2')}
                    FROM valid WHERE id = 1"
                },
            },
        },
        Expect => {
            Columns => ['id', 'name', 'test', 'test2'],
            Data => [
                { id => 1, name => 'valid', test => 'dummy', test2 => 'hello' },
            ],
        }
    },
);

foreach my $Test ( @DataTests ) {
    # wrong config
    my $Result = $ReportingObject->DataSourceGetData(
        Source     => 'GenericSQL',
        Config     => $Test->{Config},
        Parameters => $Test->{Parameters},
        UserID     => 1,
    );

    if ( ! ref $Test->{Expect} ) {
        $Self->Is(
            $Result,
            $Test->{Expect},
            'GetData() - '.$Test->{Test},
        );
    }
    else {
        $Self->IsDeeply(
            $Result,
            $Test->{Expect},
            'GetData() - '.$Test->{Test},
        );
    }
}

$Success = rmtree("$Home/plugins/test");
$Self->True(
    $Success,
    'Remove Plugin Directory',
);

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
