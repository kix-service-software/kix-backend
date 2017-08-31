# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get token object
my $TokenObject = $Kernel::OM->Get('Kernel::System::Token');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $Payload = {
    UserID     => 123,
    UserType   => 'Agent',
};

# create valid token
my $ValidToken = $TokenObject->CreateToken(
    Payload => $Payload
);

$Self->True(
    $ValidToken,
    'CreateToken() - valid token',
);

# get all tokens
my $TokenList = $TokenObject->GetAllTokens();

$Self->True(
    scalar(keys %{$TokenList}) == 1,
    'GetAllTokens() returns 1 tokens',
);

# create invalid token
$Kernel::OM->Get('Kernel::Config')->Set(Key => 'TokenMaxTime', Value => -100);
my $InvalidToken = $TokenObject->CreateToken(
    Payload => $Payload
);

$Self->True(
    $InvalidToken,
    'CreateToken() - invalid token',
);

# get all tokens
$TokenList = $TokenObject->GetAllTokens();

$Self->True(
    scalar(keys %{$TokenList}) == 2,
    'GetAllTokens() returns 2 tokens',
);

# validate valid token
my $ValidatedToken = $TokenObject->ValidateToken(
    Token => $ValidToken
);

$Self->True(
    $ValidatedToken,
    'ValidateToken() - using valid token',
);

# check valid token content
$Self->Is(
    $ValidatedToken->{UserID},
    123,
    'ValidateToken() - UserID',
);
$Self->Is(
    $ValidatedToken->{UserType},
    'Agent',
    'ValidateToken() - UserType',
);

# validate invalid token
my $Result = $TokenObject->ValidateToken(
    Token => $InvalidToken
);

$Self->False(
    $Result,
    'ValidateToken() - using invalid token',
);

# extract token payload
my $ExtractedToken = $TokenObject->ExtractToken( Token => $ValidToken );

$Self->Is(
    $ExtractedToken->{UserID},
    123,
    'ExtractToken() - UserID',
);
$Self->Is(
    $ExtractedToken->{UserType},
    'Agent',
    'ExtractToken() - UserType',
);

# check tokenlist again
$TokenList = $TokenObject->GetAllTokens();

$Self->True(
    scalar(keys %{$TokenList}) == 1,
    'GetAllTokens() now returns 1 token',
);

# remove one token
$Result = $TokenObject->RemoveToken( Token => $ValidToken );

$Self->True(
    $Result,
    'RemoveToken()',
);

# check tokenlist again
$TokenList = $TokenObject->GetAllTokens();

$Self->True(
    scalar(keys %{$TokenList}) == 0,
    'GetAllTokens() now returns 0 token',
);

# create some tokens
foreach (1..10) {
    $TokenObject->CreateToken(
        Payload => $Payload
    );
}

# cleanup all tokens
$Result = $TokenObject->CleanUp();

$Self->True(
    $Result,
    'CleanUp()',
);

# check tokenlist again
$TokenList = $TokenObject->GetAllTokens();

$Self->True(
    scalar(keys %{$TokenList}) == 0,
    'GetAllTokens() returns empty list',
);

# cleanup is done by RestoreDatabase.

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
