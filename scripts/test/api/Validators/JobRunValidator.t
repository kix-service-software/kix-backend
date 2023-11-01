# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Validator::JobRunValidator;

# get Job object
my $AutomationObject = $Kernel::OM->Get('Automation');

# get validator object
my $ValidatorObject = Kernel::API::Validator::JobRunValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $NameRandom  = $Helper->GetRandomID();

# add job
my $JobID = $AutomationObject->JobAdd(
    Name    => 'job-'.$NameRandom,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $JobID,
    'JobAdd() for new job',
);

# execute job
my $Success = $AutomationObject->JobExecute(
    ID        => $JobID,
    Data      => {},
    Async     => 0,
    UserID    => 1
);
$Self->True(
    $Success,
    'JobExecute() for job',
);

# get job run list
my %JobRunIDs = $AutomationObject->JobRunList(
    JobID => $JobID
);
$Self->True(
    keys( %JobRunIDs ),
    'JobRunList() has keys',
);

# get first job run id
my @JobRunIDs = ( keys( %JobRunIDs ) );
my $JobRunID  = $JobRunIDs[0];

my $ValidData = {
    RunID => $JobRunID
};

my $InvalidData = {
    RunID => 0
};

# validate valid RunID
my $Result = $ValidatorObject->Validate(
    Attribute => 'RunID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid RunID',
);

# validate invalid RunID
$Result = $ValidatorObject->Validate(
    Attribute => 'RunID',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid RunID',
);

# validate invalid attribute
$Result = $ValidatorObject->Validate(
    Attribute => 'InvalidAttribute',
    Data      => {},
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid attribute',
);

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
