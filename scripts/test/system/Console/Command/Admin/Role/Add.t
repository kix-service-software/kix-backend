# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::Role::Add');

my ( $Result, $ExitCode );

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper   = $Kernel::OM->Get('UnitTest::Helper');
my $RoleName = "role" . $Helper->GetRandomID();

# try to execute command without any options
$ExitCode = $CommandObject->Execute();
$Self->Is(
    $ExitCode,
    1,
    "No options",
);

# provide minimum options
$ExitCode = $CommandObject->Execute( '--name', $RoleName );
$Self->Is(
    $ExitCode,
    0,
    "Minimum options",
);

# provide name which already exists
$ExitCode = $CommandObject->Execute( '--name', $RoleName );
$Self->Is(
    $ExitCode,
    1,
    "Role with the name $RoleName already exists",
);

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
