# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Debugger;
use Kernel::API::Mapping;

my $DebuggerObject = Kernel::API::Debugger->new(
    DebuggerConfig => {
        DebugThreshold => 'debug',
        TestMode       => 1,
    },
    WebserviceID      => 1,            # hard coded because it is not used
    CommunicationType => 'Provider',
);

# create object with false options
my $MappingObject;

$MappingObject = Kernel::API::Mapping->new();
$Self->IsNot(
    ref $MappingObject,
    'Kernel::API::Mapping',
    'Mapping::new() constructor failure - no arguments',
);

$MappingObject = Kernel::API::Mapping->new(
    DebuggerObject => $DebuggerObject,
    MappingConfig  => {},
);
$Self->IsNot(
    ref $MappingObject,
    'Kernel::API::Mapping',
    'Mapping::new() constructor failure - no MappingType',
);

$MappingObject = Kernel::API::Mapping->new(
    DebuggerObject => $DebuggerObject,
    MappingConfig  => {
        Type => 'ThisIsCertainlyNotBeingUsed',
    },
);
$Self->IsNot(
    ref $MappingObject,
    'Kernel::API::Mapping',
    'Mapping::new() constructor failure - wrong MappingType',
);

# call with empty config
$MappingObject = Kernel::API::Mapping->new(
    DebuggerObject => $DebuggerObject,
    MappingConfig  => {
        Type   => 'Test',
        Config => {},
    },
);
$Self->IsNot(
    ref $MappingObject,
    'Kernel::API::Mapping',
    'Mapping::new() constructor failure - empty config',
);

# call with invalid config
$MappingObject = Kernel::API::Mapping->new(
    DebuggerObject => $DebuggerObject,
    MappingConfig  => {
        Type   => 'Test',
        Config => 'invalid',
    },
);
$Self->IsNot(
    ref $MappingObject,
    'Kernel::API::Mapping',
    'Mapping::new() constructor failure - invalid config, string',
);

# call with invalid config
$MappingObject = Kernel::API::Mapping->new(
    DebuggerObject => $DebuggerObject,
    MappingConfig  => {
        Type   => 'Test',
        Config => [],
    },
);
$Self->IsNot(
    ref $MappingObject,
    'Kernel::API::Mapping',
    'Mapping::new() constructor failure - invalid config, array',
);

# call with invalid config
$MappingObject = Kernel::API::Mapping->new(
    DebuggerObject => $DebuggerObject,
    MappingConfig  => {
        Type   => 'Test',
        Config => '',
    },
);
$Self->IsNot(
    ref $MappingObject,
    'Kernel::API::Mapping',
    'Mapping::new() constructor failure - invalid config, empty string',
);

# call without config
$MappingObject = Kernel::API::Mapping->new(
    DebuggerObject => $DebuggerObject,
    MappingConfig  => {
        Type => 'Test',
    },
);
$Self->Is(
    ref $MappingObject,
    'Kernel::API::Mapping',
    'MappingObject creation check without config',
);

# map without data
my $ReturnData = $MappingObject->Map();
$Self->Is(
    ref $ReturnData,
    'HASH',
    'MappingObject call response type',
);
$Self->True(
    $ReturnData->{Success},
    'MappingObject call no data provided',
);

# map with empty data
$ReturnData = $MappingObject->Map(
    Data => {},
);
$Self->Is(
    ref $ReturnData,
    'HASH',
    'MappingObject call response type',
);
$Self->True(
    $ReturnData->{Success},
    'MappingObject call empty data provided',
);

# map with invalid data
$ReturnData = $MappingObject->Map(
    Data => [],
);
$Self->Is(
    ref $ReturnData,
    'HASH',
    'MappingObject call response type',
);
$Self->False(
    $ReturnData->{Success},
    'MappingObject call invalid data provided',
);

# map with some data
$ReturnData = $MappingObject->Map(
    Data => {
        'from' => 'to',
    },
);
$Self->True(
    $ReturnData->{Success},
    'MappingObject call data provided',
);

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
