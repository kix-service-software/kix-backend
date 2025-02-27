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

# discard current auth object
$Kernel::OM->ObjectsDiscard(
    Objects => ['Auth'],
);

# set minimal config for methods test
$Kernel::OM->Get('Config')->Set(
    Key   => 'Authentication',
    Value => {
        'UnitTest' => [
            {
                'Enabled' => 0
            }
        ]
    }
);
$Kernel::OM->Get('Config')->Set(
    Key   => 'MultiFactorAuthentication',
    Value => {}
);

# check supported methods
for my $Method ( qw(GetPreAuthTypes GetMFAuthTypes GetAuthMethods PreAuth Auth MFASecretGenerate GetLastErrorMessage) ) {
    $Self->True(
        $Kernel::OM->Get('Auth')->can($Method),
        'Auth object can "' . $Method . '"'
    );
}

### SHORTCUTS ###
# AUTH   > SysConfig 'Authentication'
# MFA    > SysConfig 'MultiFactorAuthentication'
# PARAM  > used Paramenter
# A=*    > Auth is not defined
# A=A    > Auth provides 'admin'
# A=U    > Auth provides 'unknown'
# MFA=*  > MFAuth is not defined
# MFA=0  > MFAuth provides '0'
# MFA=1  > MFAuth provides '1'
# PA=*   > PreAuth is not defined
# PA=0   > PreAuth provides '0'
# PA=1   > PreAuth provides '1'
# AT=*   > AuthType not restricted/set
# AT=T   > AuthType restricted/set to Test
# AT=U   > AuthType restricted/set to UnitTest
# MFAT=* > MFAuthType not restricted/set
# MFAT=T > MFAuthType restricted/set to Test
# MFAT=U > MFAuthType restricted/set to UnitTest
# UC=*   > UsageContext not restricted/set
# UC=A   > UsageContext restricted/set to Agent
# UC=C   > UsageContext restricted/set to Customer
# GS=*   > GenerateSecret is not defined
# GS=T   > GenerateSecret provides 'Test'
# GS=U   > GenerateSecret provides undefined value

# test GetPreAuthTypes
my @GetPreAuthTypesTests = (
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=*,UC=*}], PARAM{}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=1,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [ 'UnitTest' ]
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=1,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [ 'UnitTest' ]
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=1,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [ 'UnitTest' ]
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=1,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=1,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=1,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [ 'UnitTest' ]
    },
    {
        Name      => 'GetPreAuthTypes: AUTH[{PA=1,UC=*},{PA=1,UC=*},{PA=1,UC=*},{PA=1,UC=*},{PA=*,UC=*},{PA=1,UC=A},{PA=1,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest1',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest1'
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest2',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest2'
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest3',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest1'
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest4',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest'
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest5',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 0,
                    'GetPreAuthType' => ''
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest6',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest6'
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest7',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'           => 'admin',
                    'PreAuth'        => 1,
                    'GetPreAuthType' => 'UnitTest7'
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent',
            Silent       => 1
        },
        Expected  => [ 'UnitTest', 'UnitTest1', 'UnitTest2', 'UnitTest6' ]
    }
);
for my $Test ( @GetPreAuthTypesTests ) {
    # discard current auth object
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Auth'],
    );

    # set config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'Authentication',
        Value => {
            'UnitTest' => $Test->{Config}
        }
    );

    my $GetPreAuthTypesReturn = $Kernel::OM->Get('Auth')->GetPreAuthTypes(
        %{ $Test->{Parameter} || {} },
        Silent => ( defined( $Test->{Expected} ) && !$Test->{Parameter}->{Silent} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $GetPreAuthTypesReturn,
        $Test->{Expected},
        $Test->{Name}
    );
}

# test GetMFAuthTypes
my @GetMFAuthTypesTests = (
    {
        Name      => 'GetMFAuthTypes: MFA[], PARAM{}',
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'GetMFAuthTypes: MFA[], PARAM{UC=A}',
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetMFAuthTypes: MFA[], PARAM{UC=C}',
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetMFAuthTypes: MFA[{AT=*,UC=*}], PARAM{UC=A}',
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [ 'UnitTest' ]
    },
    {
        Name      => 'GetMFAuthTypes: MFA[{AT=*,UC=*}], PARAM{UC=C}',
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [ 'UnitTest' ]
    },
    {
        Name      => 'GetMFAuthTypes: MFA[{AT=*,UC=A}], PARAM{UC=A}',
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [ 'UnitTest' ]
    },
    {
        Name      => 'GetMFAuthTypes: MFA[{AT=*,UC=A}], PARAM{UC=C}',
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetMFAuthTypes: MFA[{AT=*,UC=C}], PARAM{UC=A}',
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetMFAuthTypes: MFA[{AT=*,UC=C}], PARAM{UC=C}',
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [ 'UnitTest' ]
    },
    {
        Name      => 'GetMFAuthTypes: MFA[{AT=*,UC=*},{AT=*,UC=*},{AT=*,UC=*},{AT=*,UC=*},{AT=*,UC=A},{AT=*,UC=C}], PARAM{UC=A}',
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest1',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest1',
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest2',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest2',
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest3',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest1',
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest4',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest',
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest5',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest5',
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest6',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'        => 1,
                    'GetMFAuthType' => 'UnitTest6',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [ 'UnitTest', 'UnitTest1', 'UnitTest2', 'UnitTest5' ]
    }
);
for my $Test ( @GetMFAuthTypesTests ) {
    # discard current auth object
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Auth'],
    );

    # set config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'Authentication',
        Value => {
            'UnitTest' => [
                {
                    'Enabled' => 0,
                }
            ]
        }
    );
    $Kernel::OM->Get('Config')->Set(
        Key   => 'MultiFactorAuthentication',
        Value => {
            'UnitTest' => $Test->{MFAConfig}
        }
    );

    my $GetMFAuthTypesReturn = $Kernel::OM->Get('Auth')->GetMFAuthTypes(
        %{ $Test->{Parameter} || {} },
        Silent => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $GetMFAuthTypesReturn,
        $Test->{Expected},
        $Test->{Name}
    );
}

# test GetAuthMethods
my @GetAuthMethodsTests = (
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[], PARAM{}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetMFAuthTypes: AUTH[{AT=*,PA=*,UC=*}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetMFAuthTypes: AUTH[{AT=*,PA=*,UC=A}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetMFAuthTypes: AUTH[{AT=*,PA=*,UC=C}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'Type'    => 'UnitTest',
                'PreAuth' => 0,
                'MFA'     => []
            }
        ]
    },
    {
        Name      => 'GetMFAuthTypes: AUTH[{AT=U,PA=0,UC=*}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'Type'    => 'UnitTest',
                'PreAuth' => 0,
                'MFA'     => []
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'Type'    => 'UnitTest',
                'PreAuth' => 0,
                'MFA'     => []
            }
        ]
    },
    {
        Name      => 'GetMFAuthTypes: AUTH[{AT=U,PA=0,UC=A}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetMFAuthTypes: AUTH[{AT=U,PA=0,UC=C}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'Type'    => 'UnitTest',
                'PreAuth' => 0,
                'MFA'     => []
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'Type'    => 'UnitTest',
                'PreAuth' => 1,
                'MFA'     => []
            }
        ]
    },
    {
        Name      => 'GetMFAuthTypes: AUTH[{AT=U,PA=1,UC=*}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'Type'    => 'UnitTest',
                'PreAuth' => 1,
                'MFA'     => []
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'Type'    => 'UnitTest',
                'PreAuth' => 1,
                'MFA'     => []
            }
        ]
    },
    {
        Name      => 'GetMFAuthTypes: AUTH[{AT=U,PA=1,UC=A}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetMFAuthTypes: AUTH[{AT=U,PA=1,UC=C}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'Type'    => 'UnitTest',
                'PreAuth' => 1,
                'MFA'     => []
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'  => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=*,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=*}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=A}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=*,PA=*,UC=C}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin'
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'  => 1,
                'Name'     => 'UnitTest',
                'Module'   => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType' => 'UnitTest',
                'Config'   => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=*}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=A}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=0,UC=C}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=*}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=A}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => []
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=T,PA=1,UC=C}], MFA[{AT=U,MFAT=U,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 1
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [],
                'PreAuth' => 1,
                'Type'    => 'Test'
            }
        ]
    },
    {
        Name      => 'GetAuthMethods: AUTH[{AT=U,PA=1,UC=*},{AT=T,PA=0,UC=*}], MFA[{AT=*,MFAT=U,UC=*},{AT=U,MFAT=T,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 1
                    }
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'Config'       => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'UnitTest',
                        Data => {}
                    }
                }
            },
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth'          => 1,
                    'GetMFAuthMethod' => {
                        Type => 'Test',
                        Data => {}
                    }
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => [
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    },
                    {
                        Type => 'Test',
                        Data => {}
                    }
                ],
                'PreAuth' => 1,
                'Type'    => 'UnitTest'
            },
            {
                'MFA'     => [
                    {
                        Type => 'UnitTest',
                        Data => {}
                    }
                ],
                'PreAuth' => 0,
                'Type'    => 'Test'
            }
        ]
    },
);
for my $Test ( @GetAuthMethodsTests ) {
    # discard current auth object
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Auth'],
    );

    # set config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'Authentication',
        Value => {
            'UnitTest' => $Test->{Config}
        }
    );
    $Kernel::OM->Get('Config')->Set(
        Key   => 'MultiFactorAuthentication',
        Value => {
            'UnitTest' => $Test->{MFAConfig}
        }
    );

    my $GetAuthMethodsReturn = $Kernel::OM->Get('Auth')->GetAuthMethods(
        %{ $Test->{Parameter} || {} },
        Silent => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $GetAuthMethodsReturn,
        $Test->{Expected},
        $Test->{Name}
    );
}

# test PreAuth
my @PreAuthTests = (
    {
        Name      => 'PreAuth: AUTH[{PA=*,UC=*}], PARAM{}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin',
                }
            }
        ],
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=*,UC=C}]], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=*,UC=A}]], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin',
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=0,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'    => 'admin',
                    'PreAuth' => 0
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => 0
    },
    {
        Name      => 'PreAuth: AUTH[{PA=0,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'    => 'admin',
                    'PreAuth' => 0
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => 0
    },
    {
        Name      => 'PreAuth: AUTH[{PA=0,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'    => 'admin',
                    'PreAuth' => 0
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => 0
    },
    {
        Name      => 'PreAuth: AUTH[{PA=0,UC=A}]], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'    => 'admin',
                    'PreAuth' => 0
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=0,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'    => 'admin',
                    'PreAuth' => 0
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=0,UC=C}]], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'    => 'admin',
                    'PreAuth' => 0
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => 0
    },
    {
        Name      => 'PreAuth: AUTH[{PA=1,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'    => 'admin',
                    'PreAuth' => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => 1
    },
    {
        Name      => 'PreAuth: AUTH[{PA=1,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'    => 'admin',
                    'PreAuth' => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => 1
    },
    {
        Name      => 'PreAuth: AUTH[{PA=1,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'    => 'admin',
                    'PreAuth' => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => 1
    },
    {
        Name      => 'PreAuth: AUTH[{PA=1,UC=A}]], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth'    => 'admin',
                    'PreAuth' => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=1,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'    => 'admin',
                    'PreAuth' => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'PreAuth: AUTH[{PA=1,UC=C}]], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth'    => 'admin',
                    'PreAuth' => 1
                }
            }
        ],
        Parameter => {
            UsageContext => 'Customer'
        },
        Expected  => 1
    },
);
for my $Test ( @PreAuthTests ) {
    # discard current auth object
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Auth'],
    );

    # set config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'Authentication',
        Value => {
            'UnitTest' => $Test->{Config}
        }
    );

    my $GetAuthMethodsReturn = $Kernel::OM->Get('Auth')->PreAuth(
        %{ $Test->{Parameter} || {} },
        Silent => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $GetAuthMethodsReturn,
        $Test->{Expected},
        $Test->{Name}
    );
}

# test Auth
my @AuthTests = (
    {
        Name      => 'Auth: AUTH[{A=*,AT=*,UC=*}], MFA[], PARAM{}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => undef,
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=*,UC=*}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => undef,
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=*,UC=*}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => undef,
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=*,UC=*}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=*,UC=*}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=*,UC=*}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'unknown',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=*,UC=*}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'unknown',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=*,UC=A}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => undef,
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=*,UC=A}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => undef,
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=*,UC=A}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=*,UC=A}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'admin',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=*,UC=A}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'unknown',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=*,UC=A}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'Auth' => 'unknown',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=*,UC=C}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => undef,
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=*,UC=C}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => undef,
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=*,UC=C}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=*,UC=C}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'admin',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=*,UC=C}], MFA[], PARAM{UC=A}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'unknown',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=*,UC=C}], MFA[], PARAM{UC=C}',
        Config    => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'Auth' => 'unknown',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=*,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => undef,
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=*,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => undef,
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=*,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=*,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'admin',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=*,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'unknown',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=*,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth' => 'unknown',
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=T,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=T,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=T,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=T,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=T,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=T,UC=*}], MFA[{MFA=*,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=T,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=T,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=T,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTestTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=T,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=T,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=T,UC=*}], MFA[{MFA=0,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=T,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=T,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=T,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=T,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=T,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=T,UC=*}], MFA[{MFA=1,AT=U,UC=*}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'Test',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'AuthType'     => 'UnitTest',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=A}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=A}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Agent',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=*,AT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => undef,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=0,AT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 0,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=*,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => undef,
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => 'admin'
    },
    {
        Name      => 'Auth: AUTH[{A=A,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'admin',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=C}], PARAM{UC=A}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Agent'
        },
        Expected  => undef
    },
    {
        Name      => 'Auth: AUTH[{A=U,AT=U,UC=*}], MFA[{MFA=1,AT=*,UC=C}], PARAM{UC=C}',
        Config    => [
            {
                'Enabled' => 1,
                'Name'    => 'UnitTest',
                'Module'  => 'scripts::test::system::Auth::UnitTest',
                'Config'  => {
                    'Auth'          => 'unknown',
                    'GetAuthMethod' => {
                        'Type'    => 'UnitTest',
                        'PreAuth' => 0
                    }
                }
            }
        ],
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'UsageContext' => 'Customer',
                'Config'       => {
                    'MFAuth' => 1,
                }
            }
        ],
        Parameter => {
            'UsageContext' => 'Customer'
        },
        Expected  => undef
    },
);
for my $Test ( @AuthTests ) {
    # discard current auth object
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Auth'],
    );

    # set config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'Authentication',
        Value => {
            'UnitTest' => $Test->{Config}
        }
    );
    $Kernel::OM->Get('Config')->Set(
        Key   => 'MultiFactorAuthentication',
        Value => {
            'UnitTest' => $Test->{MFAConfig}
        }
    );

    my $GetAuthMethodsReturn = $Kernel::OM->Get('Auth')->Auth(
        %{ $Test->{Parameter} || {} },
        Silent => defined( $Test->{Expected} ) ? 0 : 1
    );
    $Self->IsDeeply(
        $GetAuthMethodsReturn,
        $Test->{Expected},
        $Test->{Name}
    );
}

# test MFASecretGenerate
my @MFASecretGenerateTests = (
    {
        Name      => 'MFASecretGenerate: MFA[GS=*], PARAM{}',
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => undef,
        Expected  => 0
    },
    {
        Name      => 'MFASecretGenerate: MFA[GS=*], PARAM{MAuth}',
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'MFAuth' => 'Test'
        },
        Expected  => 0
    },
    {
        Name      => 'MFASecretGenerate: MFA[GS=*], PARAM{UserID}',
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'UserID' => 1
        },
        Expected  => 0
    },
    {
        Name      => 'MFASecretGenerate: MFA[GS=*], PARAM{MAuth,UserID}',
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'MFAuth' => 'Test',
            'UserID' => 1
        },
        Expected  => 0
    },
    {
        Name      => 'MFASecretGenerate: MFA[GS=*], PARAM{MAuth,UserID}',
        MFAConfig => [
            {
                'Enabled' => 0,
            }
        ],
        Parameter => {
            'MFAuth' => 'Test',
            'UserID' => 1
        },
        Expected  => 0
    },
    {
        Name      => 'MFASecretGenerate: MFA[GS=U], PARAM{MAuth,UserID}',
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth'         => 1,
                    'GenerateSecret' => undef,
                }
            }
        ],
        Parameter => {
            'MFAuth' => 'Test',
            'UserID' => 1
        },
        Expected  => 0
    },
    {
        Name      => 'MFASecretGenerate: MFA[GS=T], PARAM{MAuth,UserID}',
        MFAConfig => [
            {
                'Enabled'      => 1,
                'Name'         => 'UnitTest',
                'Module'       => 'scripts::test::system::Auth::MFA::UnitTest',
                'Config'       => {
                    'MFAuth'         => 1,
                    'GenerateSecret' => 'Test',
                }
            }
        ],
        Parameter => {
            'MFAuth' => 'Test',
            'UserID' => 1
        },
        Expected  => 1
    },
);
for my $Test ( @MFASecretGenerateTests ) {
    # discard current auth object
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Auth'],
    );

    # set config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'MultiFactorAuthentication',
        Value => {
            'UnitTest' => $Test->{MFAConfig}
        }
    );

    my $GetAuthMethodsReturn = $Kernel::OM->Get('Auth')->MFASecretGenerate(
        %{ $Test->{Parameter} || {} },
        Silent => $Test->{Expected} ? 0 : 1
    );
    $Self->IsDeeply(
        $GetAuthMethodsReturn,
        $Test->{Expected},
        $Test->{Name}
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
