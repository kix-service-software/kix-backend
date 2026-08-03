# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com
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

my $DynamicFieldModule = 'Kernel::System::DynamicField::Driver::ITSMConfigItemReference';

# require module
return if ( !$Kernel::OM->Get('Main')->Require( $DynamicFieldModule ) );

# create backend object
my $DynamicFieldObject = $DynamicFieldModule->new( %{ $Self } );
$Self->Is(
    ref( $DynamicFieldObject ),
    $DynamicFieldModule,
    'DynamicField object has correct module ref'
);

# check supported methods
for my $Method ( qw(
        ValueGet ValueIsDifferent ValueSet ValueValidate
        DisplayValueRender ShortDisplayValueRender HTMLDisplayValueRender
        ReadableValueRender HistoricalValuesGet ValueLookup
        ExportConfigPrepare ImportConfigPrepare
    )
) {
    $Self->True(
        $DynamicFieldObject->can($Method),
        'DynamicField object can "' . $Method . q{"}
    );
}

# begin transaction on database
$Helper->BeginWork();

# ToDo: need a check handling for the following functions:
# ValueGet ValueIsDifferent ValueSet ValueValidate
# DisplayValueRender ShortDisplayValueRender HTMLDisplayValueRender
# ReadableValueRender HistoricalValuesGet ValueLookup

# prepare depl state mapping
my $DeplStateRef1 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Production',
);

$Self->True(
    $DeplStateRef1,
    'Get deployment state Production'
);

my $DeplStateRef2 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::DeploymentState',
    Name  => 'Planned',
);

$Self->True(
    $DeplStateRef2,
    'Get deployment state Planned'
);

my $ClassRef1 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::Class',
    Name  => 'Hardware',
);

$Self->True(
    $DeplStateRef2,
    'Get class Hardware'
);

my $ClassRef2 = $Kernel::OM->Get('GeneralCatalog')->ItemGet(
    Class => 'ITSM::ConfigItem::Class',
    Name  => 'Computer',
);

$Self->True(
    $DeplStateRef2,
    'Get class Computer'
);

# ExportConfigPrepare Tests
my $Config = {
    CountDefault  => 1,
    CountMax      => 1,
    CountMin      => 1,
    ItemSeparator => q{}
};

my @ExportConfigTests = (
    {
        Name         => 'ExportConfigPrepare | Default Config ',
        Config       => {
            %{$Config},
        },
        ResultAs => 'Deeply',
        Expected => {
            CountDefault             => 1,
            CountMax                 => 1,
            CountMin                 => 1,
            ItemSeparator            => q{},
            DeploymentStateNames     => [],
            ITSMConfigItemClassNames => []
        }
    },
    {
        Name         => 'ExportConfigPrepare | DeploymentStates: [ undef ] | undefined DeploymentStates',
        Config       => {
            %{$Config},
            DeploymentStates => [ undef ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ExportConfigPrepare | DeploymentStates: [ \'Test\' ] | invalid DeploymentStates',
        Config       => {
            %{$Config},
            DeploymentStates => [ 'Test' ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ExportConfigPrepare | DeploymentStates: [ 99999 ] | invalid DeploymentStates (Numeric)',
        Config       => {
            %{$Config},
            DeploymentStates => [ 99_999 ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => "ExportConfigPrepare | DeploymentStates: [$DeplStateRef1->{ItemID}]",
        Config       => {
            %{$Config},
            DeploymentStates => [ $DeplStateRef1->{ItemID} ]
        },
        ResultAs => 'Deeply',
        Expected => {
            CountDefault             => 1,
            CountMax                 => 1,
            CountMin                 => 1,
            ItemSeparator            => q{},
            DeploymentStateNames     => [ $DeplStateRef1->{Name} ],
            ITSMConfigItemClassNames => []
        }
    },
    {
        Name         => 'ExportConfigPrepare | ITSMConfigItemClasses: [ undef ] | undefined ITSMConfigItemClasses',
        Config       => {
            %{$Config},
            ITSMConfigItemClasses => [ undef ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ExportConfigPrepare | ITSMConfigItemClasses: [ \'Test\' ] | invalid ITSMConfigItemClasses',
        Config       => {
            %{$Config},
            ITSMConfigItemClasses => [ 'Test' ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ExportConfigPrepare | ITSMConfigItemClasses: [ 99999 ] | invalid ITSMConfigItemClasses (Numeric)',
        Config       => {
            %{$Config},
            ITSMConfigItemClasses => [ 99_999 ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => "ExportConfigPrepare | ITSMConfigItemClasses: [$ClassRef1->{ItemID}]",
        Config       => {
            %{$Config},
            ITSMConfigItemClasses => [ $ClassRef1->{ItemID} ]
        },
        ResultAs => 'Deeply',
        Expected => {
            CountDefault             => 1,
            CountMax                 => 1,
            CountMin                 => 1,
            ItemSeparator            => q{},
            DeploymentStateNames     => [],
            ITSMConfigItemClassNames => [ $ClassRef1->{Name} ]
        }
    }
);
for my $Test ( @ExportConfigTests ) {
    my $Result = $DynamicFieldObject->ExportConfigPrepare(
        Config => $Test->{Config},
        Silent => $Test->{Silent}
    );

    if ( $Test->{ResultAs} eq 'Deeply' ) {
        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            $Test->{Name}
        );
    }
    else {
        $Self->False(
            $Result,,
            $Test->{Name}
        )
    }
}

# ImportConfigPrepare Tests
my @ImportConfigTests = (
    {
        Name         => 'ImportConfigPrepare | Default Config',
        Config       => {
            %{$Config},
        },
        ResultAs => 'Deeply',
        Expected => {
            CountDefault          => 1,
            CountMax              => 1,
            CountMin              => 1,
            ItemSeparator         => q{},
            ITSMConfigItemClasses => [],
            DeploymentStates      => [],
        }
    },
    {
        Name         => 'ImportConfigPrepare | DeploymentStates: [ undef ] | undefined DeploymentStates (old Parameter)',
        Config       => {
            %{$Config},
            DeploymentStates => [ undef ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ImportConfigPrepare | DeploymentStates: [ \'Test\' ] | invalid DeploymentStates (old Parameter)',
        Config       => {
            %{$Config},
            DeploymentStates => [ 'Test' ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ImportConfigPrepare | DeploymentStates: [ 99999 ] | invalid DeploymentStates (old Parameter) (Numeric)',
        Config       => {
            %{$Config},
            DeploymentStates => [ 99_999 ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => "ImportConfigPrepare | DeploymentStates: [$DeplStateRef1->{Name}] (old parameter)",
        Config       => {
            %{$Config},
            DeploymentStates => [ $DeplStateRef1->{Name} ]
        },
        ResultAs => 'Deeply',
        Expected => {
            CountDefault          => 1,
            CountMax              => 1,
            CountMin              => 1,
            ItemSeparator         => q{},
            DeploymentStates      => [ $DeplStateRef1->{ItemID} ],
            ITSMConfigItemClasses => [],
        }
    },
    {
        Name         => 'ImportConfigPrepare | ITSMConfigItemClasses: [ undef ] | undefined ITSMConfigItemClasses (old Parameter)',
        Config       => {
            %{$Config},
            ITSMConfigItemClasses => [ undef ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ImportConfigPrepare | ITSMConfigItemClasses: [ \'Test\' ] | invalid ITSMConfigItemClasses (old Parameter)',
        Config       => {
            %{$Config},
            ITSMConfigItemClasses => [ 'Test' ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ImportConfigPrepare | ITSMConfigItemClasses: [ 99999 ] | invalid ITSMConfigItemClasses (old Parameter) (Numeric)',
        Config       => {
            %{$Config},
            ITSMConfigItemClasses => [ 99_999 ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => "ImportConfigPrepare | ITSMConfigItemClasses: [$ClassRef1->{Name}] (old parameter)",
        Config       => {
            %{$Config},
            ITSMConfigItemClasses => [ $ClassRef1->{Name} ]
        },
        ResultAs => 'Deeply',
        Expected => {
            CountDefault  => 1,
            CountMax      => 1,
            CountMin      => 1,
            ItemSeparator => q{},
            ITSMConfigItemClasses  => [ $ClassRef1->{ItemID} ],
            DeploymentStates => [],
        }
    },
    {
        Name         => 'ImportConfigPrepare | DeploymentStateNames: [ undef ] | undefined DeploymentStateNames',
        Config       => {
            %{$Config},
            DeploymentStateNames => [ undef ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ImportConfigPrepare | DeploymentStateNames: [ \'Test\' ] | invalid DeploymentStateNames',
        Config       => {
            %{$Config},
            DeploymentStateNames => [ 'Test' ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ImportConfigPrepare | DeploymentStateNames: [ 99999 ] | invalid DeploymentStateNames (Numeric)',
        Config       => {
            %{$Config},
            DeploymentStateNames => [ 99_999 ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => "ImportConfigPrepare | DeploymentStateNames: [$DeplStateRef1->{Name}]",
        Config       => {
            %{$Config},
            DeploymentStateNames => [ $DeplStateRef1->{Name} ]
        },
        ResultAs => 'Deeply',
        Expected => {
            CountDefault          => 1,
            CountMax              => 1,
            CountMin              => 1,
            ItemSeparator         => q{},
            DeploymentStates      => [ $DeplStateRef1->{ItemID} ],
            ITSMConfigItemClasses => [],
        }
    },
    {
        Name         => 'ImportConfigPrepare | ITSMConfigItemClassNames: [ undef ] | undefined ITSMConfigItemClassNames',
        Config       => {
            %{$Config},
            ITSMConfigItemClassNames => [ undef ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ImportConfigPrepare | ITSMConfigItemClassNames: [ \'Test\' ] | invalid ITSMConfigItemClasses',
        Config       => {
            %{$Config},
            ITSMConfigItemClassNames => [ 'Test' ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => 'ImportConfigPrepare | ITSMConfigItemClassNames: [ 99999 ] | invalid ITSMConfigItemClassNames (Numeric)',
        Config       => {
            %{$Config},
            ITSMConfigItemClassNames => [ 99_999 ]
        },
        Silent   => 1,
        ResultAs => 'False',
        Expected => undef
    },
    {
        Name         => "ImportConfigPrepare | ITSMConfigItemClassNames: [$ClassRef1->{Name}]",
        Config       => {
            %{$Config},
            ITSMConfigItemClassNames => [ $ClassRef1->{Name} ]
        },
        ResultAs => 'Deeply',
        Expected => {
            CountDefault          => 1,
            CountMax              => 1,
            CountMin              => 1,
            ItemSeparator         => q{},
            ITSMConfigItemClasses => [ $ClassRef1->{ItemID} ],
            DeploymentStates      => []
        }
    },
    {
        Name         => 'ImportConfigPrepare | Combination of DeploymentStates and DeploymentStateNames | only DeploymentStateNames will prepared' ,
        Config       => {
            %{$Config},
            DeploymentStates     => [ 'MY_ORGA' ],
            DeploymentStateNames => [ $DeplStateRef1->{Name}, $DeplStateRef2->{Name} ]
        },
        ResultAs => 'Deeply',
        Expected => {
            CountDefault          => 1,
            CountMax              => 1,
            CountMin              => 1,
            ItemSeparator         => q{},
            ITSMConfigItemClasses => [],
            DeploymentStates      => [$DeplStateRef1->{ItemID}, $DeplStateRef2->{ItemID}],
        }
    },
    {
        Name         => 'ImportConfigPrepare | Combination of ITSMConfigItemClasses and ITSMConfigItemClassNames | only ITSMConfigItemClassNames will prepared' ,
        Config       => {
            %{$Config},
            ITSMConfigItemClasses     => [ 'MY_ORGA' ],
            ITSMConfigItemClassNames => [ $ClassRef1->{Name}, $ClassRef2->{Name} ]
        },
        ResultAs => 'Deeply',
        Expected => {
            CountDefault          => 1,
            CountMax              => 1,
            CountMin              => 1,
            ItemSeparator         => q{},
            ITSMConfigItemClasses => [$ClassRef1->{ItemID}, $ClassRef2->{ItemID}],
            DeploymentStates      => [],
        }
    }
);
for my $Test ( @ImportConfigTests ) {
    my $Result = $DynamicFieldObject->ImportConfigPrepare(
        Config => $Test->{Config},
        Silent => $Test->{Silent}
    );

    if ( $Test->{ResultAs} eq 'Deeply' ) {
        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            $Test->{Name}
        );
    }
    else {
        $Self->False(
            $Result,,
            $Test->{Name}
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
