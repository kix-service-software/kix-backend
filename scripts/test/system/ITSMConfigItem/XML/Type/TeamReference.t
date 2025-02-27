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

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# load backend
my $BackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::TeamReference');
$Self->True(
    ref( $BackendObject ) eq 'Kernel::System::ITSMConfigItem::XML::Type::TeamReference',
    'Backend object was created successfuly'
);

my $RandomString = $Helper->GetRandomID();

my $QueueName = 'Service Desk::Monitoring';
my $QueueID = $Kernel::OM->Get('Queue')->QueueLookup(
    Queue => $QueueName,
);

## sub ValueLookup ##
my @ValueLookupTests = (
    {
        Name  => 'ValueLookup: undef value => empty string',
        Value => undef,
        Check => '',
    },
    {
        Name  => 'ValueLookup: empty string => empty string',
        Value => '',
        Check => '',
    },
    {
        Name  => 'ValueLookup: false value (0) => empty string',
        Value => '0',
        Check => '',
    },
    {
        Name  => 'ValueLookup: negative number => given value',
        Value => '-1',
        Check => '-1',
    },
    {
        Name  => 'ValueLookup: random string => given value',
        Value => $RandomString,
        Check => $RandomString,
    },
    {
        Name  => 'ValueLookup: unknown reference => given value',
        Value => '9999',
        Check => '9999',
    },
    {
        Name  => 'ValueLookup: known reference => name and number of reference',
        Value => $QueueID,
        Check => $QueueName,
    },
);
for my $Test ( @ValueLookupTests ) {
    my $ValueLookupResult = $BackendObject->ValueLookup(
        Value => $Test->{Value},
    );
    $Self->Is(
        $ValueLookupResult,
        $Test->{Check},
        $Test->{Name},
    );
}

## sub ExportSearchValuePrepare ##
my @ExportSearchValuePrepareTests = (
    {
        Name  => 'ExportSearchValuePrepare: undef value => given value',
        Value => undef,
        Check => undef,
    },
    {
        Name  => 'ExportSearchValuePrepare: empty string => given value',
        Value => '',
        Check => '',
    },
    {
        Name  => 'ExportSearchValuePrepare: false value (0) => given value',
        Value => '0',
        Check => '0',
    },
    {
        Name  => 'ExportSearchValuePrepare: negative number => given value',
        Value => '-1',
        Check => '-1',
    },
    {
        Name  => 'ExportSearchValuePrepare: random string => given value',
        Value => $RandomString,
        Check => $RandomString,
    },
    {
        Name  => 'ExportSearchValuePrepare: unknown reference => given value',
        Value => '9999',
        Check => '9999',
    },
    {
        Name  => 'ExportSearchValuePrepare: known reference => given value',
        Value => $QueueID,
        Check => $QueueID,
    },
);
for my $Test ( @ExportSearchValuePrepareTests ) {
    my $ExportSearchValueResult = $BackendObject->ExportSearchValuePrepare(
        Value => $Test->{Value},
    );
    $Self->Is(
        $ExportSearchValueResult,
        $Test->{Check},
        $Test->{Name},
    );
}

## sub ExportValuePrepare ##
my @ExportValuePrepareTests = (
    {
        Name  => 'ExportValuePrepare: undef value  => undef value',
        Value => undef,
        Check => undef,
    },
    {
        Name  => 'ExportValuePrepare: empty string => empty string',
        Value => '',
        Check => '',
    },
    {
        Name  => 'ExportValuePrepare: false value (0) => empty string',
        Value => '0',
        Check => '',
    },
    {
        Name  => 'ExportValuePrepare: negative number => empty string',
        Value => '-1',
        Check => '',
    },
    {
        Name  => 'ExportValuePrepare: random string => empty string',
        Value => $RandomString,
        Check => '',
    },
    {
        Name  => 'ExportValuePrepare: unknown reference => empty string',
        Value => '9999',
        Check => '',
    },
    {
        Name  => 'ExportValuePrepare: known reference => name of reference',
        Value => $QueueID,
        Check => $QueueName,
    },
);
for my $Test ( @ExportValuePrepareTests ) {
    my $ExportValuePrepareResult = $BackendObject->ExportValuePrepare(
        Item  => {
            Key   => 'TestKey',
            Name  => 'TestName',
            Input => {
                Type  => 'TeamReference',
                ReferencedCIClassName                  => $Test->{ReferencedCIClassName},
                ReferencedTeamReferenceAttributeKey => $Test->{ReferencedTeamReferenceAttributeKey},
            },
            CountMax => 1,
        },
        Value => $Test->{Value},
    );
    $Self->Is(
        $ExportValuePrepareResult,
        $Test->{Check},
        $Test->{Name},
    );
}

## sub ImportSearchValuePrepare
my @ImportSearchValuePrepareTests = (
    {
        Name  => 'ImportSearchValuePrepare: undef value => undef value',
        Value => undef,
        Check => undef,
    },
    {
        Name  => 'ImportSearchValuePrepare: empty string => empty string',
        Value => '',
        Check => '',
    },
    {
        Name  => 'ImportSearchValuePrepare: false value (0) => empty string',
        Value => '0',
        Check => '',
    },
    {
        Name  => 'ImportSearchValuePrepare: negative number => empty value',
        Value => '-1',
        Check => '',
    },
    {
        Name  => 'ImportSearchValuePrepare: random string => empty value',
        Value => $RandomString,
        Check => '',
    },
    {
        Name  => 'ImportSearchValuePrepare: unknown reference => empty value',
        Value => '9999',
        Check => '',
    },
    {
        Name  => 'ImportSearchValuePrepare: name of reference => id of reference',
        Value => $QueueName,
        Check => $QueueID,
    },
    {
        Name  => 'ImportSearchValuePrepare: id of reference => id of reference',
        Value => $QueueID,
        Check => $QueueID,
    }
);
for my $Test ( @ImportSearchValuePrepareTests ) {
    my $ImportSearchValuePrepareResult = $BackendObject->ImportSearchValuePrepare(
        Item  => {
            Key   => 'TestKey',
            Name  => 'TestName',
            Input => {
                Type  => 'TeamReference',
                ReferencedCIClassName                  => $Test->{ReferencedCIClassName},
                ReferencedTeamReferenceAttributeKey => $Test->{ReferencedTeamReferenceAttributeKey},
            },
            CountMax => 1,
        },
        Value => $Test->{Value},
    );
    $Self->Is(
        $ImportSearchValuePrepareResult,
        $Test->{Check},
        $Test->{Name},
    );
}

## sub ImportValuePrepare
my @ImportValuePrepareTests = (
    # ReferencedCIClassName: undef / ReferencedTeamReferenceAttributeKey: undef
    {
        Name  => 'ImportValuePrepare: undef value => undef value',
        Value => undef,
        Check => undef,
    },
    {
        Name  => 'ImportValuePrepare: empty string => empty string',
        Value => '',
        Check => '',
    },
    {
        Name  => 'ImportValuePrepare: false value (0) => empty string',
        Value => '0',
        Check => '',
    },
    {
        Name  => 'ImportValuePrepare: negative number => undef value',
        Value => '-1',
        Check => undef,
    },
    {
        Name  => 'ImportValuePrepare: random string => undef value',
        Value => $RandomString,
        Check => undef,
    },
    {
        Name  => 'ImportValuePrepare: unknown reference => undef value',
        Value => '9999',
        Check => undef,
    },
    {
        Name  => 'ImportValuePrepare: name of reference => id of reference',
        Value => $QueueName,
        Check => $QueueID,
    },
    {
        Name  => 'ImportValuePrepare: id of reference => id of reference',
        Value => $QueueID,
        Check => $QueueID,
    }
);
for my $Test ( @ImportValuePrepareTests ) {
    my $ImportValuePrepareResult = $BackendObject->ImportValuePrepare(
        Item  => {
            Key   => 'TestKey',
            Name  => 'TestName',
            Input => {
                Type  => 'TeamReference',
                ReferencedCIClassName                  => $Test->{ReferencedCIClassName},
                ReferencedTeamReferenceAttributeKey => $Test->{ReferencedTeamReferenceAttributeKey},
            },
            CountMax => 1,
        },
        Value => $Test->{Value},
    );
    $Self->Is(
        $ImportValuePrepareResult,
        $Test->{Check},
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
