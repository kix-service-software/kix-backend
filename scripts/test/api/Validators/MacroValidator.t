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

use Kernel::API::Validator::MacroValidator;

# get Macro object
my $AutomationObject = $Kernel::OM->Get('Automation');

# get validator object
my $ValidatorObject = Kernel::API::Validator::MacroValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $NameRandom  = $Helper->GetRandomID();

# add macro
my $MacroID = $AutomationObject->MacroAdd(
    Name    => 'macro-'.$NameRandom,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroID,
    'MacroAdd() for new macro',
);

my $ValidData = {
    MacroID => $MacroID
};

my $InvalidData = {
    MacroID => 9999
};

# validate valid MacroID
my $Result = $ValidatorObject->Validate(
    Attribute => 'MacroID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid MacroID',
);

# validate invalid MacroID
$Result = $ValidatorObject->Validate(
    Attribute => 'MacroID',
    Data      => $InvalidData,
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid MacroID',
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
