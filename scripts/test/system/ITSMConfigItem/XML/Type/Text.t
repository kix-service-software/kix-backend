# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --
# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH,https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details,see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file,see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create user for tests
my $TestUserID = $Helper->TestUserCreate(
    Result => 'ID',
    Roles  => ['Asset Reader'],
);

# get asset class list
my $ClassNamesDataRef = $Kernel::OM->Get('GeneralCatalog')->ItemList(
    Class => 'ITSM::ConfigItem::Class',
    Valid => 1,
);

# set module
my $BackendAlias  = 'ITSMConfigItem::XML::Type::Text';
my $BackendModule = 'Kernel::System::ITSMConfigItem::XML::Type::Text';

# get backend instance
my $BackendObject = $Kernel::OM->Get( $BackendAlias );
$Self->Is(
    ref( $BackendObject ),
    $BackendModule,
    'Backend object has correct module ref'
);
return if ( ref( $BackendObject ) ne $BackendModule );

# check supported methods
for my $Method (
    qw(
        ValueLookup ValidateValue
        InternalValuePrepare ImportSearchValuePrepare ImportValuePrepare
        ExternalValuePrepare ExportSearchValuePrepare ExportValuePrepare
    )
) {
    $Self->True(
        $BackendObject->can( $Method ),
        'Backend object can "' . $Method . '"'
    );
}

## sub ValueLookup ##
my @ValueLookupTests = (
    {
        Name      => 'ValueLookup: Undefined value',
        Parameter => {},
        Expected  => undef,
    },
    {
        Name      => 'ValueLookup: String value',
        Parameter => {
            Value => 'UnitTest'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ValueLookup: Hash value',
        Parameter => {
            Value => {
                'UnitTest' => 1
            }
        },
        Expected  => {
            'UnitTest' => 1
        },
    },
    {
        Name      => 'ValueLookup: Array value',
        Parameter => {
            Value => [ 'UnitTest' ]
        },
        Expected  => [ 'UnitTest' ],
    }
);
for my $Test ( @ValueLookupTests ) {
    my $ValueLookupResult = $BackendObject->ValueLookup(
        %{ $Test->{Parameter} },
    );
    $Self->IsDeeply(
        $ValueLookupResult,
        $Test->{Expected},
        $Test->{Name},
    );
}

## sub ValidateValue ##
my @ValidateValueTests = (
    {
        Name      => 'ValidateValue: Undefined value',
        Parameter => {},
        Expected  => 1,
    },
    {
        Name      => 'ValidateValue: Defined value,undefined MaxLength',
        Parameter => {
            Value => 'UnitTest'
        },
        Expected  => 1,
    },
    {
        Name      => 'ValidateValue: Defined value,defined MaxLength,length(Value) < MaxLength',
        Parameter => {
            Value => 'UnitTest',
            Input => {
                MaxLength => 10
            }
        },
        Expected  => 1,
    },
    {
        Name      => 'ValidateValue: Defined value,defined MaxLength,length(Value) < MaxLength',
        Parameter => {
            Value => 'UnitTest',
            Input => {
                MaxLength => 10
            }
        },
        Expected  => 1,
    },
    {
        Name      => 'ValidateValue: Defined value,defined MaxLength,length(Value) = MaxLength',
        Parameter => {
            Value => 'UnitTest',
            Input => {
                MaxLength => 8
            }
        },
        Expected  => 1,
    },
    {
        Name      => 'ValidateValue: Defined value with umlauts,defined MaxLength,length(Value) = MaxLength',
        Parameter => {
            Value => 'ÄÖÜäöü',
            Input => {
                MaxLength => 6
            }
        },
        Expected  => 1,
    },
    {
        Name      => 'ValidateValue: Defined value,defined MaxLength,length(Value) > MaxLength',
        Parameter => {
            Value => 'UnitTest',
            Input => {
                MaxLength => 5
            }
        },
        Expected  => 'exceeds maximum length',
    }
);
for my $Test ( @ValidateValueTests ) {
    my $ValidateValueResult = $BackendObject->ValidateValue(
        %{ $Test->{Parameter} },
    );
    $Self->IsDeeply(
        $ValidateValueResult,
        $Test->{Expected},
        $Test->{Name},
    );
}

## sub InternalValuePrepare ##
my @InternalValuePrepareTests = (
    {
        Name      => 'InternalValuePrepare: Undefined value,undefined check parameter,undefined config',
        Parameter => {},
        Config    => undef,
        Expected  => undef,
    },
    {
        Name      => 'InternalValuePrepare: Defined value,undefined check parameter,undefined config',
        Parameter => {
            Value => 'UnitTest'
        },
        Config    => undef,
        Expected  => 'UnitTest',
    },
    {
        Name      => 'InternalValuePrepare: Undefined value,defined check parameter,undefined config',
        Parameter => {
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => undef,
        Expected  => undef,
    },
    {
        Name      => 'InternalValuePrepare: Defined value,defined check parameter,undefined config',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => undef,
        Expected  => 'UnitTest',
    },
    {
        Name      => 'InternalValuePrepare: Undefined value,defined check parameter,defined config,authority given',
        Parameter => {
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'InternalValuePrepare: Defined value,defined check parameter,defined config,authority given',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'aa1969b8baa9c8b8',
    },
    {
        Name      => 'InternalValuePrepare: Undefined value,defined check parameter,defined config,mismatching class',
        Parameter => {
            ClassID      => 5,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'InternalValuePrepare: Defined value,defined check parameter,defined config,mismatching class',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 5,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'InternalValuePrepare: Undefined value,defined check parameter,defined config,mismatching definition key',
        Parameter => {
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest1'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'InternalValuePrepare: Defined value,defined check parameter,defined config,mismatching definition key',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest1'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'InternalValuePrepare: Undefined value,defined check parameter,defined config,UserID 1',
        Parameter => {
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => 1,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'InternalValuePrepare: Defined value,defined check parameter,defined config,UserID 1',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => 1,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'aa1969b8baa9c8b8',
    },
    {
        Name      => 'InternalValuePrepare: Undefined value,defined check parameter,defined config,no authority,wrong role',
        Parameter => {
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Maintainer'
        },
        Expected  => { RestorePreviousValue => 1 },
    },
    {
        Name      => 'InternalValuePrepare: Defined value,defined check parameter,defined config,no authority,wrong role',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Maintainer'
        },
        Expected  => { RestorePreviousValue => 1 },
    },
    {
        Name      => 'InternalValuePrepare: Undefined value,defined check parameter,defined config,no authority,wrong usage context',
        Parameter => {
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Customer'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => { RestorePreviousValue => 1 },
    },
    {
        Name      => 'InternalValuePrepare: Defined value,defined check parameter,defined config,no authority,wrong usage context',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Definition   => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Customer'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => { RestorePreviousValue => 1 },
    },
);
for my $Test ( @InternalValuePrepareTests ) {
    # change config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'ITSM::ConfigItem::XML::Type::Text###EncryptedText',
        Value => $Test->{Config},
    );
    # force backend to use current config
    delete( $BackendObject->{EncryptedText} );
    delete( $BackendObject->{EncryptedTextAuthority} );

    # run test
    my $InternalValuePrepareResult = $BackendObject->InternalValuePrepare(
        %{ $Test->{Parameter} },
    );
    $Self->IsDeeply(
        $InternalValuePrepareResult,
        $Test->{Expected},
        $Test->{Name},
    );
}

## sub ImportSearchValuePrepare ##
my @ImportSearchValuePrepareTests = (
    {
        Name      => 'ImportSearchValuePrepare: Undefined value',
        Parameter => {},
        Expected  => undef,
    },
    {
        Name      => 'ImportSearchValuePrepare: String value',
        Parameter => {
            Value => 'UnitTest'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ImportSearchValuePrepare: Hash value',
        Parameter => {
            Value => {
                'UnitTest' => 1
            }
        },
        Expected  => {
            'UnitTest' => 1
        },
    },
    {
        Name      => 'ImportSearchValuePrepare: Array value',
        Parameter => {
            Value => [ 'UnitTest' ]
        },
        Expected  => [ 'UnitTest' ],
    }
);
for my $Test ( @ImportSearchValuePrepareTests ) {
    my $ImportSearchValuePrepareResult = $BackendObject->ImportSearchValuePrepare(
        %{ $Test->{Parameter} },
    );
    $Self->IsDeeply(
        $ImportSearchValuePrepareResult,
        $Test->{Expected},
        $Test->{Name},
    );
}

## sub ImportValuePrepare ##
my @ImportValuePrepareTests = (
    {
        Name      => 'ImportValuePrepare: Undefined value,undefined check parameter,undefined config',
        Parameter => {},
        Config    => undef,
        Expected  => undef,
    },
    {
        Name      => 'ImportValuePrepare: Defined value,undefined check parameter,undefined config',
        Parameter => {
            Value => 'UnitTest'
        },
        Config    => undef,
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ImportValuePrepare: Undefined value,defined check parameter,undefined config',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => undef,
        Expected  => undef,
    },
    {
        Name      => 'ImportValuePrepare: Defined value,defined check parameter,undefined config',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => undef,
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ImportValuePrepare: Undefined value,defined check parameter,defined config,authority given',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ImportValuePrepare: Defined value,defined check parameter,defined config,authority given',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'aa1969b8baa9c8b8',
    },
    {
        Name      => 'ImportValuePrepare: Undefined value,defined check parameter,defined config,mismatching class',
        Parameter => {
            ClassID      => 5,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ImportValuePrepare: Defined value,defined check parameter,defined config,mismatching class',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 5,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ImportValuePrepare: Undefined value,defined check parameter,defined config,mismatching definition key',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest1'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ImportValuePrepare: Defined value,defined check parameter,defined config,mismatching definition key',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest1'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ImportValuePrepare: Undefined value,defined check parameter,defined config,UserID 1',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => 1,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ImportValuePrepare: Defined value,defined check parameter,defined config,UserID 1',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => 1,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'aa1969b8baa9c8b8',
    },
    {
        Name      => 'ImportValuePrepare: Undefined value,defined check parameter,defined config,no authority,wrong role',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Maintainer'
        },
        Expected  => undef,
    },
    {
        Name      => 'ImportValuePrepare: Defined value,defined check parameter,defined config,no authority,wrong role',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Maintainer'
        },
        Expected  => { RestorePreviousValue => 1 },
    },
    {
        Name      => 'ImportValuePrepare: Undefined value,defined check parameter,defined config,no authority,wrong usage context',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Customer'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ImportValuePrepare: Defined value,defined check parameter,defined config,no authority,wrong usage context',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Customer'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => { RestorePreviousValue => 1 },
    },
);
for my $Test ( @ImportValuePrepareTests ) {
    # change config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'ITSM::ConfigItem::XML::Type::Text###EncryptedText',
        Value => $Test->{Config},
    );
    # force backend to use current config
    delete( $BackendObject->{EncryptedText} );
    delete( $BackendObject->{EncryptedTextAuthority} );

    # run test
    my $ImportValuePrepareResult = $BackendObject->ImportValuePrepare(
        %{ $Test->{Parameter} },
    );
    $Self->IsDeeply(
        $ImportValuePrepareResult,
        $Test->{Expected},
        $Test->{Name},
    );
}

## sub ExternalValuePrepare ##
my @ExternalValuePrepareTests = (
    {
        Name      => 'ExternalValuePrepare: Undefined value,undefined check parameter,undefined config',
        Parameter => {},
        Config    => undef,
        Expected  => undef,
    },
    {
        Name      => 'ExternalValuePrepare: Defined value,undefined check parameter,undefined config',
        Parameter => {
            Value => 'UnitTest'
        },
        Config    => undef,
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExternalValuePrepare: Undefined value,defined check parameter,undefined config',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => undef,
        Expected  => undef,
    },
    {
        Name      => 'ExternalValuePrepare: Defined value,defined check parameter,undefined config',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => undef,
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExternalValuePrepare: Undefined value,defined check parameter,defined config,authority given',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExternalValuePrepare: Encrypted value,defined check parameter,defined config,authority given',
        Parameter => {
            Value        => 'aa1969b8baa9c8b8',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExternalValuePrepare: Not encrypted value,defined check parameter,defined config,authority given',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExternalValuePrepare: Undefined value,defined check parameter,defined config,mismatching class',
        Parameter => {
            ClassID      => 5,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExternalValuePrepare: Defined value,defined check parameter,defined config,mismatching class',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 5,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExternalValuePrepare: Undefined value,defined check parameter,defined config,mismatching definition key',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest1'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExternalValuePrepare: Defined value,defined check parameter,defined config,mismatching definition key',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest1'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExternalValuePrepare: Undefined value,defined check parameter,defined config,UserID 1',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => 1,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExternalValuePrepare: Encrypted value,defined check parameter,defined config,UserID 1',
        Parameter => {
            Value        => 'aa1969b8baa9c8b8',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => 1,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExternalValuePrepare: Not encrypted value,defined check parameter,defined config,UserID 1',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => 1,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExternalValuePrepare: Undefined value,defined check parameter,defined config,no authority,wrong role',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Maintainer'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExternalValuePrepare: Defined value,defined check parameter,defined config,no authority,wrong role',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Maintainer'
        },
        Expected  => '******',
    },
    {
        Name      => 'ExternalValuePrepare: Undefined value,defined check parameter,defined config,no authority,wrong usage context',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Customer'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExternalValuePrepare: Defined value,defined check parameter,defined config,no authority,wrong usage context',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Customer'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => '******',
    },
);
for my $Test ( @ExternalValuePrepareTests ) {
    # change config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'ITSM::ConfigItem::XML::Type::Text###EncryptedText',
        Value => $Test->{Config},
    );
    # force backend to use current config
    delete( $BackendObject->{EncryptedText} );
    delete( $BackendObject->{EncryptedTextAuthority} );

    # run test
    my $ExternalValuePrepareResult = $BackendObject->ExternalValuePrepare(
        %{ $Test->{Parameter} },
    );
    $Self->IsDeeply(
        $ExternalValuePrepareResult,
        $Test->{Expected},
        $Test->{Name},
    );
}

## sub ExportSearchValuePrepare ##
my @ExportSearchValuePrepareTests = (
    {
        Name      => 'ExportSearchValuePrepare: Undefined value',
        Parameter => {},
        Expected  => undef,
    },
    {
        Name      => 'ExportSearchValuePrepare: String value',
        Parameter => {
            Value => 'UnitTest'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExportSearchValuePrepare: Hash value',
        Parameter => {
            Value => {
                'UnitTest' => 1
            }
        },
        Expected  => {
            'UnitTest' => 1
        },
    },
    {
        Name      => 'ExportSearchValuePrepare: Array value',
        Parameter => {
            Value => [ 'UnitTest' ]
        },
        Expected  => [ 'UnitTest' ],
    }
);
for my $Test ( @ExportSearchValuePrepareTests ) {
    my $ExportSearchValuePrepareResult = $BackendObject->ExportSearchValuePrepare(
        %{ $Test->{Parameter} },
    );
    $Self->IsDeeply(
        $ExportSearchValuePrepareResult,
        $Test->{Expected},
        $Test->{Name},
    );
}

## sub ExportValuePrepare ##
my @ExportValuePrepareTests = (
    {
        Name      => 'ExportValuePrepare: Undefined value,undefined check parameter,undefined config',
        Parameter => {},
        Config    => undef,
        Expected  => undef,
    },
    {
        Name      => 'ExportValuePrepare: Defined value,undefined check parameter,undefined config',
        Parameter => {
            Value => 'UnitTest'
        },
        Config    => undef,
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExportValuePrepare: Undefined value,defined check parameter,undefined config',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => undef,
        Expected  => undef,
    },
    {
        Name      => 'ExportValuePrepare: Defined value,defined check parameter,undefined config',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => undef,
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExportValuePrepare: Undefined value,defined check parameter,defined config,authority given',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExportValuePrepare: Encrypted value,defined check parameter,defined config,authority given',
        Parameter => {
            Value        => 'aa1969b8baa9c8b8',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExportValuePrepare: Not encrypted value,defined check parameter,defined config,authority given',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExportValuePrepare: Undefined value,defined check parameter,defined config,mismatching class',
        Parameter => {
            ClassID      => 5,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExportValuePrepare: Defined value,defined check parameter,defined config,mismatching class',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 5,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExportValuePrepare: Undefined value,defined check parameter,defined config,mismatching definition key',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest1'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExportValuePrepare: Defined value,defined check parameter,defined config,mismatching definition key',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest1'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExportValuePrepare: Undefined value,defined check parameter,defined config,UserID 1',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => 1,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExportValuePrepare: Encrypted value,defined check parameter,defined config,UserID 1',
        Parameter => {
            Value        => 'aa1969b8baa9c8b8',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => 1,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExportValuePrepare: Not encrypted value,defined check parameter,defined config,UserID 1',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => 1,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => 'UnitTest',
    },
    {
        Name      => 'ExportValuePrepare: Undefined value,defined check parameter,defined config,no authority,wrong role',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Maintainer'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExportValuePrepare: Defined value,defined check parameter,defined config,no authority,wrong role',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Agent'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Maintainer'
        },
        Expected  => '******',
    },
    {
        Name      => 'ExportValuePrepare: Undefined value,defined check parameter,defined config,no authority,wrong usage context',
        Parameter => {
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Customer'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => undef,
    },
    {
        Name      => 'ExportValuePrepare: Defined value,defined check parameter,defined config,no authority,wrong usage context',
        Parameter => {
            Value        => 'UnitTest',
            ClassID      => 4,
            Item         => {
                Key => 'UnitTest'
            },
            UserID       => $TestUserID,
            UsageContext => 'Customer'
        },
        Config    => {
            $ClassNamesDataRef->{4} . ':::UnitTest' => 'Asset Reader'
        },
        Expected  => '******',
    },
);
for my $Test ( @ExportValuePrepareTests ) {
    # change config for test
    $Kernel::OM->Get('Config')->Set(
        Key   => 'ITSM::ConfigItem::XML::Type::Text###EncryptedText',
        Value => $Test->{Config},
    );
    # force backend to use current config
    delete( $BackendObject->{EncryptedText} );
    delete( $BackendObject->{EncryptedTextAuthority} );

    # run test
    my $ExportValuePrepareResult = $BackendObject->ExportValuePrepare(
        %{ $Test->{Parameter} },
    );
    $Self->IsDeeply(
        $ExportValuePrepareResult,
        $Test->{Expected},
        $Test->{Name},
    );
}

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details,see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file,see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
