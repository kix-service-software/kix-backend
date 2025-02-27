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

my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::SystemAddress::Add');

my ( $Result, $ExitCode );

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $SystemAddressName = 'SystemAddress' . $Helper->GetRandomID();
my $SystemAddress     = $SystemAddressName . '@example.com',
    my $QueueName     = 'queue' . $Helper->GetRandomID();

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

# try to execute command without any options
$ExitCode = $CommandObject->Execute();
$Self->Is(
    $ExitCode,
    1,
    "No options",
);

# missing options
$ExitCode = $CommandObject->Execute( '--name', $SystemAddressName );
$Self->Is(
    $ExitCode,
    1,
    "Missing options",
);

# invalid queue
$ExitCode = $CommandObject->Execute(
    '--name', $SystemAddressName, '--email-address', $SystemAddress, '--queue-name',
    $QueueName
);
$Self->Is(
    $ExitCode,
    1,
    "Invalid queue",
);

my $QueueID = $Kernel::OM->Get('Queue')->QueueAdd(
    Name            => $QueueName,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    Signature       => '',
    Comment         => 'Some comment',
    UserID          => 1,
);

$Self->True(
    $QueueID,
    "Test queue is created - $QueueID",
);

# valid options
$ExitCode = $CommandObject->Execute(
    '--name', $SystemAddressName, '--email-address', $SystemAddress, '--queue-name',
    $QueueName
);
$Self->Is(
    $ExitCode,
    0,
    "Valid options",
);

# valid options (same again, should already exist)
$ExitCode = $CommandObject->Execute(
    '--name', $SystemAddressName, '--email-address', $SystemAddress, '--queue-name',
    $QueueName
);
$Self->Is(
    $ExitCode,
    1,
    "Valid options (but already exists)",
);

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
