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

# get token object
my $TokenObject = $Kernel::OM->Get('Token');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $Payload = {
    UserID     => 123,
    UserType   => 'Agent',
    TokenType  => 'TestToken'
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
my $TokenList = _getAllRelevantTokensNumber();
$Self->True(
    $TokenList == 1,
    'GetAllTokens() returns 1 token',
);

# create invalid token
$Helper->ConfigSettingChange(Key => 'TokenMaxTime', Value => -100);
my $InvalidToken = $TokenObject->CreateToken(
    Payload => $Payload
);

$Self->True(
    $InvalidToken,
    'CreateToken() - invalid token',
);

# get all tokens
$TokenList = _getAllRelevantTokensNumber();
$Self->True(
    $TokenList == 2,
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
$TokenList = _getAllRelevantTokensNumber();
$Self->True(
    $TokenList == 1,
    'GetAllTokens() now returns 1 token',
);

# remove one token
$Result = $TokenObject->RemoveToken( Token => $ValidToken );

$Self->True(
    $Result,
    'RemoveToken()',
);

# check tokenlist again
$TokenList = _getAllRelevantTokensNumber();
$Self->True(
    $TokenList == 0,
    'GetAllTokens() now returns 0 token',
);

# create some tokens
foreach (1..10) {
    $TokenObject->CreateToken(
        Payload => $Payload
    );
}

# cleanup all tokens
$Result = $TokenObject->CleanUp( TokenType  => 'TestToken' );

$Self->True(
    $Result,
    'CleanUp()',
);

# check tokenlist again
$TokenList = _getAllRelevantTokensNumber();
$Self->True(
    $TokenList == 0,
    'GetAllTokens() returns empty list',
);

# check expired token deletion
# -----------------------------------------------
my @Payloads = (
    {
        UserID     => 123,
        UserType   => 'Agent',
        TokenType  => 'TestToken',
        ValidUntil => '2022-01-01 12:00:00' # date in past
    },
    {
        UserID     => 1234,
        UserType   => 'Agent',
        TokenType  => 'TestToken',
        ValidUntil => '9999-01-01 12:00:00' # date in future
    },
    {
        UserID     => 12345,
        UserType   => 'Agent',
        TokenType  => 'TestToken',
        ValidUntil => '9999-01-01 12:00:00', # date in future,
        IgnoreMaxIdleTime => 1               # ignore idle time
    }
);

# create tokens
for my $Payload (@Payloads) {
    $TokenObject->CreateToken(
        Payload => $Payload
    );
}

# get all new created tokens
$TokenList = _getAllRelevantTokensNumber();
$Self->True(
    $TokenList == 3,
    'GetAllTokens() returns 3 tokens',
);

# make sure idle check time is in future (100 seconds) - should not be reached now
$Helper->ConfigSettingChange(Key => 'TokenMaxIdleTime', Value => 100);

# cleanup all expired token
$Result = $TokenObject->CleanUpExpired();
$Self->True(
    $Result,
    'CleanUpExpired()',
);

# check tokenlist again - only the two not expired (ValidUntil)
$TokenList = _getAllRelevantTokensNumber();
$Self->True(
    $TokenList == 2,
    'GetAllTokens() after CleanUpExpired returns 2 token',
);

# change idle check time (100 seconnds in past) => should be reached now
$Helper->ConfigSettingChange(Key => 'TokenMaxIdleTime', Value => -100);

# cleanup all expired token again
$Result = $TokenObject->CleanUpExpired();
$Self->True(
    $Result,
    'CleanUpExpired()',
);

# check tokenlist again - only the not one with ignore idle should remain
$TokenList = _getAllRelevantTokensNumber();
$Self->True(
    $TokenList == 1,
    'GetAllTokens() after CleanUpExpired (idle) returns 1 token',
);

# final cleanup - remove all test tokesn
$TokenObject->CleanUp( TokenType  => 'TestToken' );

# rollback transaction on database
$Helper->Rollback();

1;

sub _getAllRelevantTokensNumber {
    my $TokenList = $TokenObject->GetAllTokens();
    my $RelevantTokenNumber = 0;
    for my $Token (keys %{$TokenList}) {
        my $ExtractedToken = $TokenObject->ExtractToken( Token => $Token );
        $RelevantTokenNumber++ if ($ExtractedToken && $ExtractedToken->{TokenType} eq 'TestToken');
    }
    return $RelevantTokenNumber;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
