# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Validator::HistoryTypeValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::HistoryTypeValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ValidData = {
    HistoryType => 'NewTicket'
};

my $InvalidData = {
    HistoryType => 'NewTicket123-test'
};

my $ValidData_ID = {
    HistoryTypeID => '1'
};

my $InvalidData_ID = {
    HistoryTypeID => '9999'
};

# validate valid HistoryType
my $Result = $ValidatorObject->Validate(
    Attribute => 'HistoryType',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid HistoryType',
);

# validate invalid HistoryType
$Result = $ValidatorObject->Validate(
    Attribute => 'HistoryType',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid HistoryType',
);

# validate valid HistoryTypeID
$Result = $ValidatorObject->Validate(
    Attribute => 'HistoryTypeID',
    Data      => $ValidData_ID,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid HistoryTypeID',
);

# validate invalid HistoryTypeID
$Result = $ValidatorObject->Validate(
    Attribute => 'HistoryTypeID',
    Data      => $InvalidData_ID,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid HistoryTypeID',
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

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
