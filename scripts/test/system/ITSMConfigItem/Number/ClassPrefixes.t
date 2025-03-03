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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# define needed variable
my $RandomID = $Helper->GetRandomID();

# ------------------------------------------------------------ #
# make preparations
# ------------------------------------------------------------ #
# set config for number generator
$Kernel::OM->Get('Config')->Set(
    Key   => 'ITSMConfigItem::NumberGenerator',
    Value => 'Kernel::System::ITSMConfigItem::Number::ClassPrefixes',
);

# make sure we get a fresh object
$Kernel::OM->ObjectsDiscard(
    Objects => ['ITSMConfigItem'],
);

# add a new config item class
my $ItemID = $Kernel::OM->Get('GeneralCatalog')->ItemAdd(
    Class   => 'ITSM::ConfigItem::Class',
    Name    => 'UnitTest',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $ItemID,
    'Create config item class "UnitTest"',
);

# get system id
my $SystemID = $Kernel::OM->Get('Config')->Get('SystemID');

# define test cases
my @Tests = (
    {
        Name     => 'Empty config',
        Config   => {},
        Expected => $ItemID . '0001'
    },
    {
        Name     => 'Invalid CounterLength in config (negative integer)',
        Config   => {
            CounterLength => -1
        },
        Expected => $ItemID . '0002'
    },
    {
        Name     => 'Invalid CounterLength in config (float)',
        Config   => {
            CounterLength => 1.1
        },
        Expected => $ItemID . '0003'
    },
    {
        Name     => 'Invalid CounterLength in config (letter)',
        Config   => {
            CounterLength => 'a'
        },
        Expected => $ItemID . '0004'
    },
    {
        Name     => 'Minimal valid config, use all fallbacks',
        Config   => {
            DefaultPrefix => ''
        },
        Expected => $ItemID . '0005'
    },
    {
        Name     => 'Complete valid config, no prefix, no default prefix, no separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {},
            Separator       => ''
        },
        Expected => $ItemID . '0006'
    },
    {
        Name     => 'Complete valid config, no prefix, no default prefix, no separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {},
            Separator       => ''
        },
        Expected => $ItemID . $SystemID . '0007'
    },
    {
        Name     => 'Complete valid config, no prefix, no default prefix, no separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {},
            Separator       => ''
        },
        Expected => $ItemID . '00008'
    },
    {
        Name     => 'Complete valid config, no prefix, no default prefix, no separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {},
            Separator       => ''
        },
        Expected => $ItemID . $SystemID . '00009'
    },
    {
        Name     => 'Complete valid config, no prefix, no default prefix, separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {},
            Separator       => '#'
        },
        Expected => $ItemID . '#0010'
    },
    {
        Name     => 'Complete valid config, no prefix, no default prefix, separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {},
            Separator       => '#'
        },
        Expected => $ItemID . '#' . $SystemID . '#0011'
    },
    {
        Name     => 'Complete valid config, no prefix, no default prefix, separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {},
            Separator       => '#'
        },
        Expected => $ItemID . '#00012'
    },
    {
        Name     => 'Complete valid config, no prefix, no default prefix, separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {},
            Separator       => '#'
        },
        Expected => $ItemID . '#' . $SystemID . '#00013'
    },
    {
        Name     => 'Complete valid config, no prefix, default prefix, no separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {},
            Separator       => ''
        },
        Expected => 'DEF0014'
    },
    {
        Name     => 'Complete valid config, no prefix, default prefix, no separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {},
            Separator       => ''
        },
        Expected => 'DEF' . $SystemID . '0015'
    },
    {
        Name     => 'Complete valid config, no prefix, default prefix, no separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {},
            Separator       => ''
        },
        Expected => 'DEF00016'
    },
    {
        Name     => 'Complete valid config, no prefix, default prefix, no separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {},
            Separator       => ''
        },
        Expected => 'DEF' . $SystemID . '00017'
    },
    {
        Name     => 'Complete valid config, no prefix, default prefix, separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {},
            Separator       => '#'
        },
        Expected => 'DEF#0018'
    },
    {
        Name     => 'Complete valid config, no prefix, default prefix, separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {},
            Separator       => '#'
        },
        Expected => 'DEF#' . $SystemID . '#0019'
    },
    {
        Name     => 'Complete valid config, no prefix, default prefix, separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {},
            Separator       => '#'
        },
        Expected => 'DEF#00020'
    },
    {
        Name     => 'Complete valid config, no prefix, default prefix, separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {},
            Separator       => '#'
        },
        Expected => 'DEF#' . $SystemID . '#00021'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, no default prefix, no separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => ''
        },
        Expected => $ItemID . '0022'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, no default prefix, no separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => ''
        },
        Expected => $ItemID . $SystemID . '0023'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, no default prefix, no separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => ''
        },
        Expected => $ItemID . '00024'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, no default prefix, no separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => ''
        },
        Expected => $ItemID . $SystemID . '00025'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, no default prefix, separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => '#'
        },
        Expected => $ItemID . '#0026'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, no default prefix, separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => '#'
        },
        Expected => $ItemID . '#' . $SystemID . '#0027'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, no default prefix, separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => '#'
        },
        Expected => $ItemID . '#00028'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, no default prefix, separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => '#'
        },
        Expected => $ItemID . '#' . $SystemID . '#00029'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, default prefix, no separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => ''
        },
        Expected => 'DEF0030'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, default prefix, no separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => ''
        },
        Expected => 'DEF' . $SystemID . '0031'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, default prefix, no separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => ''
        },
        Expected => 'DEF00032'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, default prefix, no separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => ''
        },
        Expected => 'DEF' . $SystemID . '00033'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, default prefix, separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => '#'
        },
        Expected => 'DEF#0034'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, default prefix, separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => '#'
        },
        Expected => 'DEF#' . $SystemID . '#0035'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, default prefix, separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => '#'
        },
        Expected => 'DEF#00036'
    },
    {
        Name     => 'Complete valid config, no relevant prefix, default prefix, separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {
                Test => 'TEST'
            },
            Separator       => '#'
        },
        Expected => 'DEF#' . $SystemID . '#00037'
    },
    {
        Name     => 'Complete valid config, relevant prefix, no default prefix, no separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => ''
        },
        Expected => 'UT0038'
    },
    {
        Name     => 'Complete valid config, relevant prefix, no default prefix, no separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => ''
        },
        Expected => 'UT' . $SystemID . '0039'
    },
    {
        Name     => 'Complete valid config, relevant prefix, no default prefix, no separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => ''
        },
        Expected => 'UT00040'
    },
    {
        Name     => 'Complete valid config, relevant prefix, no default prefix, no separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => ''
        },
        Expected => 'UT' . $SystemID . '00041'
    },
    {
        Name     => 'Complete valid config, relevant prefix, no default prefix, separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => '#'
        },
        Expected => 'UT#0042'
    },
    {
        Name     => 'Complete valid config, relevant prefix, no default prefix, separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => '#'
        },
        Expected => 'UT#' . $SystemID . '#0043'
    },
    {
        Name     => 'Complete valid config, relevant prefix, no default prefix, separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 0,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => '#'
        },
        Expected => 'UT#00044'
    },
    {
        Name     => 'Complete valid config, relevant prefix, no default prefix, separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => '',
            IncludeSystemID => 1,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => '#'
        },
        Expected => 'UT#' . $SystemID . '#00045'
    },
    {
        Name     => 'Complete valid config, relevant prefix, default prefix, no separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => ''
        },
        Expected => 'UT0046'
    },
    {
        Name     => 'Complete valid config, relevant prefix, default prefix, no separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => ''
        },
        Expected => 'UT' . $SystemID . '0047'
    },
    {
        Name     => 'Complete valid config, relevant prefix, default prefix, no separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => ''
        },
        Expected => 'UT00048'
    },
    {
        Name     => 'Complete valid config,  relevant prefix, default prefix, no separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => ''
        },
        Expected => 'UT' . $SystemID . '00049'
    },
    {
        Name     => 'Complete valid config, relevant prefix, default prefix, separator, content length 4, no system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => '#'
        },
        Expected => 'UT#0050'
    },
    {
        Name     => 'Complete valid config, relevant prefix, default prefix, separator, content length 4, system id',
        Config   => {
            CounterLength   => 4,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => '#'
        },
        Expected => 'UT#' . $SystemID . '#0051'
    },
    {
        Name     => 'Complete valid config, relevant prefix, default prefix, separator, content length 5, no system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 0,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => '#'
        },
        Expected => 'UT#00052'
    },
    {
        Name     => 'Complete valid config, relevant prefix, default prefix, separator, content length 5, system id',
        Config   => {
            CounterLength   => 5,
            DefaultPrefix   => 'DEF',
            IncludeSystemID => 1,
            Prefixes        => {
                UnitTest => 'UT'
            },
            Separator       => '#'
        },
        Expected => 'UT#' . $SystemID . '#00053'
    },
);
for my $Test ( @Tests ) {
    # set config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'ITSMConfigItem::Number::ClassPrefixes',
        Value => $Test->{Config},
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => ['ITSMConfigItem'],
    );

    # generate number
    my $Number = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemNumberCreate(
        ClassID => $ItemID,
        Silent  => defined( $Test->{Expected} ) ? 0 : 1,
    );

    # check result
    if ( defined( $Test->{Expected} ) ) {
        $Self->Is(
            $Number,
            $Test->{Expected},
            $Test->{Name},
        );
    }
    else {
        $Self->False(
            $Number,
            $Test->{Name},
        );
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
