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

# get PID object
my $PIDObject = $Kernel::OM->Get('PID');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# set fixed time
$Helper->FixedTimeSet();

my $PIDCreate = $PIDObject->PIDCreate( Name => 'Test' );
$Self->True(
    $PIDCreate,
    'PIDCreate()',
);

my $PIDCreate2 = $PIDObject->PIDCreate( Name => 'Test' );
$Self->False(
    $PIDCreate2,
    'PIDCreate2()',
);

my %PIDGet = $PIDObject->PIDGet( Name => 'Test' );
$Self->True(
    $PIDGet{PID},
    'PIDGet()',
);

my $PIDCreateForce = $PIDObject->PIDCreate(
    Name  => 'Test',
    Force => 1,
);
$Self->True(
    $PIDCreateForce,
    'PIDCreate() - Force',
);

my $UpdateSuccess = $PIDObject->PIDUpdate(
    Silent => 1,
);

$Self->False(
    $UpdateSuccess,
    'PIDUpdate() with no name',
);

$UpdateSuccess = $PIDObject->PIDUpdate(
    Name   => 'NonExistentProcess' . $Helper->GetRandomID(),
    Silent => 1,
);

$Self->False(
    $UpdateSuccess,
    'PIDUpdate() with wrong name',
);

# wait 2 seconds to update the PID change time
$Helper->FixedTimeAddSeconds(2);

$UpdateSuccess = $PIDObject->PIDUpdate(
    Name => 'Test',
);

$Self->True(
    $UpdateSuccess,
    'PIDUpdate()',
);

my %UpdatedPIDGet = $PIDObject->PIDGet( Name => 'Test' );
$Self->True(
    $UpdatedPIDGet{PID},
    'PIDGet() updated',
);

$Self->IsNotDeeply(
    \%PIDGet,
    \%UpdatedPIDGet,
    'PIDGet() updated is different than the original one',
);

my $PIDDelete = $PIDObject->PIDDelete( Name => 'Test' );
$Self->True(
    $PIDDelete,
    'PIDDelete()',
);

# test Force delete
# 1 create a new PID
my $PIDCreate3 = $PIDObject->PIDCreate( Name => 'Test' );
$Self->True(
    $PIDCreate3,
    'PIDCreate3() for Force delete',
);

# 2 manually modify the PID host
my $RandomID = $Helper->GetRandomID();
$UpdateSuccess = $Kernel::OM->Get('DB')->Do(
    SQL => '
        UPDATE process_id
        SET process_host = ?
        WHERE process_name = ?',
    Bind => [ \$RandomID, \'Test' ],
);
$Self->True(
    $UpdateSuccess,
    'Updated Host for Force delete',
);
%UpdatedPIDGet = $PIDObject->PIDGet( Name => 'Test' );
$Self->Is(
    $UpdatedPIDGet{Host},
    $RandomID,
    'PIDGet() for Force delete (Host)',
);

# 3 delete without force should keep the process
my $CurrentPID = $UpdatedPIDGet{PID};
$PIDDelete = $PIDObject->PIDDelete( Name => 'Test' );
$Self->True(
    $PIDDelete,
    'PIDDelete() Force delete (without Force)',
);
%UpdatedPIDGet = $PIDObject->PIDGet( Name => 'Test' );
$Self->Is(
    $UpdatedPIDGet{PID},
    $CurrentPID,
    'PIDGet() for Force delete (PID should still alive)',
);

# 4 force delete should delete the process even from a different host
$PIDDelete = $PIDObject->PIDDelete(
    Name  => 'Test',
    Force => 1,
);
$Self->True(
    $PIDDelete,
    'PIDDelete() Force delete (with Force)',
);
%UpdatedPIDGet = $PIDObject->PIDGet( Name => 'Test' );
$Self->False(
    $UpdatedPIDGet{PID},
    'PIDGet() for forced delete (PID should be deleted now)',
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
