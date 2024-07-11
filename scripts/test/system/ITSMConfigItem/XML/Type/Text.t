# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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
        Name      => 'ValidateValue: Defined value, undefined MaxLength',
        Parameter => {
            Value => 'UnitTest'
        },
        Expected  => 1, 
    },
    {
        Name      => 'ValidateValue: Defined value, defined MaxLength, length(Value) < MaxLength',
        Parameter => {
            Value => 'UnitTest',
            Input => {
                MaxLength => 10
            }
        },
        Expected  => 1, 
    },
    {
        Name      => 'ValidateValue: Defined value, defined MaxLength, length(Value) < MaxLength',
        Parameter => {
            Value => 'UnitTest',
            Input => {
                MaxLength => 10
            }
        },
        Expected  => 1, 
    },
    {
        Name      => 'ValidateValue: Defined value, defined MaxLength, length(Value) = MaxLength',
        Parameter => {
            Value => 'UnitTest',
            Input => {
                MaxLength => 8
            }
        },
        Expected  => 1, 
    },
    {
        Name      => 'ValidateValue: Defined value with umlauts, defined MaxLength, length(Value) = MaxLength',
        Parameter => {
            Value => 'ÄÖÜäöü',
            Input => {
                MaxLength => 6
            }
        },
        Expected  => 1, 
    },
    {
        Name      => 'ValidateValue: Defined value, defined MaxLength, length(Value) > MaxLength',
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
