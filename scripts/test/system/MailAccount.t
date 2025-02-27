# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get mail account object
my $MailAccountObject = $Kernel::OM->Get('MailAccount');

my $MailAccountAdd = $MailAccountObject->MailAccountAdd(
    Login         => 'mail',
    Password      => 'SomePassword',
    Host          => 'pop3.example.com',
    Type          => 'POP3',
    ValidID       => 1,
    Trusted       => 0,
    IMAPFolder    => 'Foo',
    DispatchingBy => 'PostmasterDefaultQueue',              # PostmasterDefaultQueue|From|Queue
    UserID        => 1,
);

$Self->True(
    $MailAccountAdd,
    'MailAccountAdd()',
);

my %MailAccount = $MailAccountObject->MailAccountGet(
    ID => $MailAccountAdd,
);

$Self->True(
    $MailAccount{Login} eq 'mail',
    'MailAccountGet() - Login',
);
$Self->True(
    $MailAccount{Password} eq 'SomePassword',
    'MailAccountGet() - Password',
);
$Self->True(
    $MailAccount{Host} eq 'pop3.example.com',
    'MailAccountGet() - Host',
);
$Self->True(
    $MailAccount{Type} eq 'POP3',
    'MailAccountGet() - Type',
);
$Self->True(
    $MailAccount{IMAPFolder} eq '',
    'MailAccountGet() - IMAPFolder',
);
$Self->True(
    $MailAccount{DispatchingBy} eq 'PostmasterDefaultQueue',
    'MailAccountGet() - DispatchingBy',
);
$Self->True(
    !defined( $MailAccount{QueueID} ),
    'MailAccountGet() - QueueID',
);
$Self->True(
    !defined($MailAccount{OAuth2_ProfileID}),
    'MailAccountGet() - OAuth2_ProfileID',
);

my $MailAccountUpdate = $MailAccountObject->MailAccountUpdate(
    ID            => $MailAccountAdd,
    Login         => 'mail2',
    Password      => 'SomePassword2',
    Host          => 'imap.example.com',
    Type          => 'IMAP',
    ValidID       => 1,
    IMAPFolder    => 'Bar',
    Trusted       => 0,
    DispatchingBy => 'From',              # PostmasterDefaultQueue|From|Queue
    UserID        => 1,
);

$Self->True(
    $MailAccountUpdate,
    'MailAccountUpdate()',
);

%MailAccount = $MailAccountObject->MailAccountGet(
    ID => $MailAccountAdd,
);

$Self->True(
    $MailAccount{Login} eq 'mail2',
    'MailAccountGet() - Login',
);
$Self->True(
    $MailAccount{Password} eq 'SomePassword2',
    'MailAccountGet() - Password',
);
$Self->True(
    $MailAccount{Host} eq 'imap.example.com',
    'MailAccountGet() - Host',
);
$Self->True(
    $MailAccount{Type} eq 'IMAP',
    'MailAccountGet() - Type',
);
$Self->True(
    $MailAccount{IMAPFolder} eq 'Bar',
    'MailAccountGet() - IMAPFolder',
);
$Self->True(
    $MailAccount{DispatchingBy} eq 'From',
    'MailAccountGet() - DispatchingBy',
);
$Self->True(
    !defined( $MailAccount{QueueID} ),
    'MailAccountGet() - QueueID',
);
$Self->True(
    !defined($MailAccount{OAuth2_ProfileID}),
    'MailAccountGet() - OAuth2_ProfileID',
);

my %List = $MailAccountObject->MailAccountList(
    Valid => 0,    # just valid/all accounts
);

$Self->True(
    $List{$MailAccountAdd},
    'MailAccountList()',
);

my $MailAccountDelete = $MailAccountObject->MailAccountDelete(
    ID => $MailAccountAdd,
);

$Self->True(
    $MailAccountDelete,
    'MailAccountDelete()',
);

my $MailAccountAddIMAP = $MailAccountObject->MailAccountAdd(
    Login         => 'mail',
    Password      => 'SomePassword',
    Host          => 'imap.example.com',
    Type          => 'IMAPS',
    ValidID       => 1,
    Trusted       => 0,
    IMAPFolder    => 'Foo',
    DispatchingBy => 'Queue',              # PostmasterDefaultQueue|From|Queue
    QueueID       => 1,
    UserID        => 1,
);

$Self->True(
    $MailAccountAddIMAP,
    'MailAccountAdd()',
);

%MailAccount = $MailAccountObject->MailAccountGet(
    ID => $MailAccountAddIMAP,
);

$Self->True(
    $MailAccount{Login} eq 'mail',
    'MailAccountGet() - Login',
);
$Self->True(
    $MailAccount{Password} eq 'SomePassword',
    'MailAccountGet() - Password',
);
$Self->True(
    $MailAccount{Host} eq 'imap.example.com',
    'MailAccountGet() - Host',
);
$Self->True(
    $MailAccount{Type} eq 'IMAPS',
    'MailAccountGet() - Type',
);
$Self->True(
    $MailAccount{IMAPFolder} eq 'Foo',
    'MailAccountGet() - IMAPFolder',
);
$Self->True(
    $MailAccount{DispatchingBy} eq 'Queue',
    'MailAccountGet() - DispatchingBy',
);
$Self->True(
    $MailAccount{QueueID} eq '1',
    'MailAccountGet() - QueueID',
);
$Self->True(
    !defined($MailAccount{OAuth2_ProfileID}),
    'MailAccountGet() - OAuth2_ProfileID',
);

my $MailAccountUpdateIMAP = $MailAccountObject->MailAccountUpdate(
    ID            => $MailAccountAddIMAP,
    Login         => 'mail2',
    Password      => 'SomePassword2',
    Host          => 'imaps.example.com',
    Type          => 'IMAPS',
    ValidID       => 1,
    Trusted       => 0,
    DispatchingBy => 'Queue',               # PostmasterDefaultQueue|From|Queue
    QueueID       => 1,
    UserID        => 1,
);

$Self->True(
    $MailAccountUpdateIMAP,
    'MailAccountUpdate()',
);

%MailAccount = $MailAccountObject->MailAccountGet(
    ID => $MailAccountAddIMAP,
);

$Self->True(
    $MailAccount{Login} eq 'mail2',
    'MailAccountGet() - Login',
);
$Self->True(
    $MailAccount{Password} eq 'SomePassword2',
    'MailAccountGet() - Password',
);
$Self->True(
    $MailAccount{Host} eq 'imaps.example.com',
    'MailAccountGet() - Host',
);
$Self->True(
    $MailAccount{Type} eq 'IMAPS',
    'MailAccountGet() - Type',
);
$Self->True(
    $MailAccount{IMAPFolder} eq 'INBOX',
    'MailAccountGet() - IMAPFolder fallback',
);
$Self->True(
    $MailAccount{DispatchingBy} eq 'Queue',
    'MailAccountGet() - DispatchingBy',
);
$Self->True(
    $MailAccount{QueueID} eq '1',
    'MailAccountGet() - QueueID',
);
$Self->True(
    !defined($MailAccount{OAuth2_ProfileID}),
    'MailAccountGet() - OAuth2_ProfileID',
);

my $MailAccountDeleteIMAP = $MailAccountObject->MailAccountDelete(
    ID => $MailAccountAddIMAP,
);

$Self->True(
    $MailAccountDeleteIMAP,
    'MailAccountDelete() IMAP account',
);

my $OAuth2ProfileID1 = $Kernel::OM->Get('OAuth2')->ProfileAdd(
    Name         => 'Profile1',
    URLAuth      => 'URL Auth',
    URLToken     => 'URL Token',
    URLRedirect  => 'URL Redirect',
    ClientID     => "ClientID",
    ClientSecret => "ClientSecret",
    Scope        => "Scope",
    ValidID      => 1,
    UserID       => 1,
);

$Self->True(
    $OAuth2ProfileID1,
    'ProfileAdd() for OAuth2 test profile 1',
);

my $OAuth2ProfileID2 = $Kernel::OM->Get('OAuth2')->ProfileAdd(
    Name         => 'Profile2',
    URLAuth      => 'URL Auth',
    URLToken     => 'URL Token',
    URLRedirect  => 'URL Redirect',
    ClientID     => "ClientID",
    ClientSecret => "ClientSecret",
    Scope        => "Scope",
    ValidID      => 1,
    UserID       => 1,
);

$Self->True(
    $OAuth2ProfileID2,
    'ProfileAdd() for OAuth2 test profile 2',
);

my $MailAccountAddOAuth2 = $MailAccountObject->MailAccountAdd(
    Login            => 'mail',
    OAuth2_ProfileID => $OAuth2ProfileID1,
    Host             => 'imap.example.com',
    Type             => 'IMAPTLS_OAuth2',
    ValidID          => 1,
    Trusted          => 0,
    IMAPFolder       => 'Foo',
    DispatchingBy    => 'Queue',              # PostmasterDefaultQueue|From|Queue
    QueueID          => 2,
    UserID           => 1,
);

$Self->True(
    $MailAccountAddOAuth2,
    'MailAccountAdd()',
);

%MailAccount = $MailAccountObject->MailAccountGet(
    ID => $MailAccountAddOAuth2,
);

$Self->True(
    $MailAccount{Login} eq 'mail',
    'MailAccountGet() - Login',
);
$Self->True(
    $MailAccount{Password} eq '-',
    'MailAccountGet() - Password fallback/replacement for OAuth2',
);
$Self->True(
    $MailAccount{Host} eq 'imap.example.com',
    'MailAccountGet() - Host',
);
$Self->True(
    $MailAccount{Type} eq 'IMAPTLS_OAuth2',
    'MailAccountGet() - Type',
);
$Self->True(
    $MailAccount{IMAPFolder} eq 'Foo',
    'MailAccountGet() - IMAPFolder',
);
$Self->True(
    $MailAccount{DispatchingBy} eq 'Queue',
    'MailAccountGet() - DispatchingBy',
);
$Self->True(
    $MailAccount{QueueID} = 2,
    'MailAccountGet() - QueueID',
);
$Self->True(
    $MailAccount{OAuth2_ProfileID} eq $OAuth2ProfileID1,
    'MailAccountGet() - OAuth2_ProfileID',
);

my $MailAccountUpdateOAuth2 = $MailAccountObject->MailAccountUpdate(
    ID               => $MailAccountAddOAuth2,
    Login            => 'mail2',
    OAuth2_ProfileID => $OAuth2ProfileID2,
    Password         => 'SomePassword2',
    Host             => 'imaps.example.com',
    Type             => 'IMAPS_OAuth2',
    ValidID          => 1,
    Trusted          => 0,
    DispatchingBy    => 'Queue',               # PostmasterDefaultQueue|From|Queue
    QueueID          => 1,
    UserID           => 1,
);

$Self->True(
    $MailAccountUpdateOAuth2,
    'MailAccountUpdate()',
);

%MailAccount = $MailAccountObject->MailAccountGet(
    ID => $MailAccountAddOAuth2,
);

$Self->True(
    $MailAccount{Login} eq 'mail2',
    'MailAccountGet() - Login',
);
$Self->True(
    $MailAccount{Password} eq '-',
    'MailAccountGet() - Password fallback/replacement for OAuth2',
);
$Self->True(
    $MailAccount{Host} eq 'imaps.example.com',
    'MailAccountGet() - Host',
);
$Self->True(
    $MailAccount{Type} eq 'IMAPS_OAuth2',
    'MailAccountGet() - Type',
);
$Self->True(
    $MailAccount{IMAPFolder} eq 'INBOX',
    'MailAccountGet() - IMAPFolder fallback',
);
$Self->True(
    $MailAccount{DispatchingBy} eq 'Queue',
    'MailAccountGet() - DispatchingBy',
);
$Self->True(
    $MailAccount{QueueID} eq '1',
    'MailAccountGet() - QueueID',
);
$Self->True(
    $MailAccount{OAuth2_ProfileID} eq $OAuth2ProfileID2,
    'MailAccountGet() - OAuth2_ProfileID',
);

my $MailAccountDeleteOAuth2 = $MailAccountObject->MailAccountDelete(
    ID => $MailAccountAddOAuth2,
);

$Self->True(
    $MailAccountDeleteOAuth2,
    'MailAccountDelete() OAuth2 account',
);

my $OAuth2ProfileDelete1 = $Kernel::OM->Get('OAuth2')->ProfileDelete(
    ID => $OAuth2ProfileID1
);

$Self->True(
    $OAuth2ProfileDelete1,
    'ProfileDelete() for OAuth2 test profile 1',
);

my $OAuth2ProfileDelete2 = $Kernel::OM->Get('OAuth2')->ProfileDelete(
    ID => $OAuth2ProfileID2
);

$Self->True(
    $OAuth2ProfileDelete2,
    'ProfileDelete() for OAuth2 test profile 2',
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
