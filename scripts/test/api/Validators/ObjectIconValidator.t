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

use MIME::Base64;

use vars (qw($Self));

use Kernel::API::Validator::ObjectIconValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::ObjectIconValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $MaxAllowedSize = 10;
$Helper->ConfigSettingChange(
    Key   => 'ObjectIcon::MaxAllowedSize',
    Value => $MaxAllowedSize
);

my $ValidData = {
    Content => MIME::Base64::encode_base64('1234567890')
};

my $InvalidData = {
    Content => MIME::Base64::encode_base64('12345678901')
};

my $EmptyData = {
    Content => ''
};

# validate valid ObjectIcon
my $Result = $ValidatorObject->Validate(
    Attribute => 'Content',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid ObjectIcon',
);

# validate invalid ObjectIcon
$Result = $ValidatorObject->Validate(
    Attribute => 'Content',
    Data      => $InvalidData,
);
$Self->False(
    $Result->{Success},
    'Validate() - invalid ObjectIcon (max size 10 bytes)',
);
my $LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
    Type => 'error',
    What => 'Message',
);
$Self->Is(
    "Size exceeds maximum allowed size ($MaxAllowedSize bytes)!",
    $LogMessage,
    'Validate() - Error Message for invalid ObjectIcon (max size 10 bytes)',
);

$Helper->ConfigSettingChange(
    Key   => 'ObjectIcon::MaxAllowedSize',
    Value => '100'
);

# validate invalid ObjectIcon
$Result = $ValidatorObject->Validate(
    Attribute => 'Content',
    Data      => $InvalidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - invalid ObjectIcon is valid (max size 100 bytes)',
);

# validate empty ObjectIcon
$Result = $ValidatorObject->Validate(
    Attribute => 'Content',
    Data      => $EmptyData,
);

$Self->False(
    $Result->{Success},
    'Validate() - empty ObjectIcon',
);
$LogMessage = $Kernel::OM->Get('Log')->GetLogEntry(
    Type => 'error',
    What => 'Message',
);
$Self->Is(
    'Content is empty!',
    $LogMessage,
    'Validate() - Error Message for empty ObjectIcon',
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
