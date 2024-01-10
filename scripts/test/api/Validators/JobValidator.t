# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Validator::JobValidator;

# get Job object
my $AutomationObject = $Kernel::OM->Get('Automation');

# get validator object
my $ValidatorObject = Kernel::API::Validator::JobValidator->new();

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

my $ValidData = {
    JobID => $JobID
};

my $InvalidData = {
    JobID => 9999
};

# validate valid JobID
my $Result = $ValidatorObject->Validate(
    Attribute => 'JobID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid JobID',
);

# validate invalid JobID
$Result = $ValidatorObject->Validate(
    Attribute => 'JobID',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid JobID',
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
