# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

# get needed objects
my $ConfigObject    = $Kernel::OM->Get('Config');
my $CheckItemObject = $Kernel::OM->Get('CheckItem');

# disable dns lookups
$ConfigObject->Set(
    Key   => 'CheckMXRecord',
    Value => 0,
);
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 1,
);

# email address checks
my @Tests = (

    # Invalid
    {
        Email => 'somebody',
        Valid => 0,
    },
    {
        Email => 'somebod y@somehost.com',
        Valid => 0,
    },
    {
        Email => 'ä@somehost.com',
        Valid => 0,
    },
    {
        Email => 'a@sömehöst.cöm',
        Valid => 0,
    },
    {
        Email => 'a%40someh%C3%B6st.com', # URL encoded
        Valid => 0,
    },
    {
        Email => '.somebody@somehost.com',
        Valid => 0,
    },
    {
        Email => 'somebody.@somehost.com',
        Valid => 0,
    },
    {
        Email => 'some..body@somehost.com',
        Valid => 0,
    },
    {
        Email => 'some@body@somehost.com',
        Valid => 0,
    },
    {
        Email  => '',
        Valid  => 0,
        Silent => 1,
    },
    {
        Email => 'foo=bar@[192.1233.22.2]',
        Valid => 0,
    },
    {
        Email => 'foo=bar@[192.22.2]',
        Valid => 0,
    },

    # Valid
    {
        Email => 'somebody@somehost.com',
        Valid => 1,
    },
    {
        Email => 'some.body@somehost.com',
        Valid => 1,
    },
    {
        Email => 'some+body@somehost.com',
        Valid => 1,
    },
    {
        Email => 'some-body@somehost.com',
        Valid => 1,
    },
    {
        Email => 'some_b_o_d_y@somehost.com',
        Valid => 1,
    },
    {
        Email => 'Some.Bo_dY.test.TesT@somehost.com',
        Valid => 1,
    },
    {
        Email => '_some.name@somehost.com',
        Valid => 1,
    },
    {
        Email => '-some.name-@somehost.com',
        Valid => 1,
    },
    {
        Email => 'name.surname@sometext.sometext.sometext',
        Valid => 1,
    },
    {
        Email => 'user/department@somehost.com',
        Valid => 1,
    },
    {
        Email => '#helpdesk@foo.com',
        Valid => 1,
    },
    {
        Email => 'foo=bar@domain.de',
        Valid => 1,
    },
    {
        Email => 'foo=bar@[192.123.22.2]',
        Valid => 1,
    },

    # Unicode domains
    {
        Email => 'mail@xn--f1aefnbl.xn--p1ai',
        Valid => 1,
    },
    {
        Email => 'mail@кц.рф',    # must be converted to IDN
        Valid => 0,
    },

    # Local part of email address is too long according to RFC.
    # See http://isemail.info/modperl-uc.1384763750.ffhelkebjhfdihihkbce-michiel.beijen%3Dkixdesk.com%40perl.apache.org
    {
        Email =>
            'modperl-uc.1384763750.ffhelkebjhfdihihkbce-michiel.beijen=kixdesk.com@perl.apache.org',
        Valid => 0,
    },

);

for my $Test (@Tests) {

    # check address
    my $Valid = $CheckItemObject->CheckEmail(
        Address => $Test->{Email},
        Silent  => $Test->{Silent},
    );

    # execute unit test
    if ( $Test->{Valid} ) {
        $Self->True(
            $Valid,
            "CheckEmail() - $Test->{Email}",
        );
    }
    else {
        $Self->False(
            $Valid,
            "CheckEmail() - $Test->{Email}",
        );
    }
}

my $TextContent = $Kernel::OM->Get('Main')->FileRead(
    Location => $Kernel::OM->Get('Config')->Get('Home') . '/scripts/test/system/sample/CheckItem/test.txt',
    Mode     => 'binmode'
);

# string clean tests
@Tests = (
    {
        String => ' ',
        Params => {},
        Result => '',
    },
    {
        String => undef,
        Params => {},
        Result => undef,
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {},
        Result => "Test\n\r\t test\n\r\t Test",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft  => 1,
            TrimRight => 0,
        },
        Result => "Test\n\r\t test\n\r\t Test\n\r\t ",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft  => 0,
            TrimRight => 1,
        },
        Result => "\n\r\t Test\n\r\t test\n\r\t Test",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft  => 0,
            TrimRight => 0,
        },
        Result => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft          => 1,
            TrimRight         => 1,
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 0,
            RemoveAllSpaces   => 0,
        },
        Result => "Test\t test\t Test",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft          => 1,
            TrimRight         => 1,
            RemoveAllNewlines => 0,
            RemoveAllTabs     => 1,
            RemoveAllSpaces   => 0,
        },
        Result => "Test\n\r test\n\r Test",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft          => 1,
            TrimRight         => 1,
            RemoveAllNewlines => 0,
            RemoveAllTabs     => 0,
            RemoveAllSpaces   => 1,
        },
        Result => "Test\n\r\ttest\n\r\tTest",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft          => 0,
            TrimRight         => 0,
            RemoveAllNewlines => 0,
            RemoveAllTabs     => 0,
            RemoveAllSpaces   => 0,
        },
        Result => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft          => 0,
            TrimRight         => 0,
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 0,
            RemoveAllSpaces   => 0,
        },
        Result => "\t Test\t test\t Test\t ",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft          => 0,
            TrimRight         => 0,
            RemoveAllNewlines => 0,
            RemoveAllTabs     => 1,
            RemoveAllSpaces   => 0,
        },
        Result => "\n\r Test\n\r test\n\r Test\n\r ",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft          => 0,
            TrimRight         => 0,
            RemoveAllNewlines => 0,
            RemoveAllTabs     => 0,
            RemoveAllSpaces   => 1,
        },
        Result => "\n\r\tTest\n\r\ttest\n\r\tTest\n\r\t",
    },
    {
        String => "\n\r\t Test\n\r\t test\n\r\t Test\n\r\t ",
        Params => {
            TrimLeft          => 0,
            TrimRight         => 0,
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
            RemoveAllSpaces   => 1,
        },
        Result => "TesttestTest",
    },

    # strip invalid utf8 characters
    {
        String => 'aäöüß€z',
        Params => {},
        Result => 'aäöüß€z',
    },
    {
        String => eval { Encode::encode('ISO-8859-1', ${$TextContent}) },    # iso-8859 string
        Params => {},
        Result => eval { Encode::encode('ISO-8859-1', ${$TextContent}) },
    },
    {
        String => eval {'aúz'},    # utf-8 string
        Params => {},
        Result => 'aúz',
    },
);

for my $Test (@Tests) {

    # copy string to leave the original untouched
    my $String = $Test->{String};

    # start string preparation
    my $StringRef = $CheckItemObject->StringClean(
        StringRef => \$String,
        %{ $Test->{Params} },
    );

    # check result
    $Self->Is(
        ${$StringRef},
        $Test->{Result},
        'TrimTest',
    );
}

# credit card tests
@Tests = (
    {
        String => '4111 1111 1111 1111',
        Found  => 1,
        Result => '4111 XXXX XXXX 1111',
    },
    {
        String => '4111+1111+1111+1111',
        Found  => 1,
        Result => '4111+XXXX+XXXX+1111',
    },
    {
        String => '-4111+1111+1111+1111-',
        Found  => 1,
        Result => '-4111+XXXX+XXXX+1111-',
    },
    {
        String => '-4111+1111+1111+11-',
        Found  => 0,
        Result => '-4111+1111+1111+11-',
    },
    {
        String => '6011.0000/0000.0004',
        Found  => 1,
        Result => '6011.XXXX/XXXX.0004',
    },
    {
        String => '3400/0000/0000/009',
        Found  => 1,
        Result => '3400/XXXX/XXXX/009',
    },
    {
        String => '#5500.00000000.0004',
        Found  => 1,
        Result => '#5500.XXXXXXXX.0004',
    },
    {
        String => '#5500.00000000.0004.',
        Found  => 1,
        Result => '#5500.XXXXXXXX.0004.',
    },
    {
        String => "#5500.00000000.0004\n",
        Found  => 1,
        Result => "#5500.XXXXXXXX.0004\n",
    },
    {
        String => ":5500.00000000.0004\n",
        Found  => 1,
        Result => ":5500.XXXXXXXX.0004\n",
    },
    {
        String => "(5500.00000000.0004)\n",
        Found  => 1,
        Result => "(5500.XXXXXXXX.0004)\n",
    },
    {
        String => '#5500.00000000.00045.',
        Found  => 0,
        Result => '#5500.00000000.00045.',
    },
    {
        String => 'A5500.00000000.00045.',
        Found  => 0,
        Result => 'A5500.00000000.00045.',
    },
);
for my $Test (@Tests) {

    # copy string to leave the original untouched
    my $String = $Test->{String};

    # start string preparation
    my ( $StringRef, $Found ) = $CheckItemObject->CreditCardClean( StringRef => \$String );

    # check result
    $Self->Is(
        $Found,
        $Test->{Found},
        'CreditCardClean - Found',
    );
    $Self->Is(
        ${$StringRef},
        $Test->{Result},
        'CreditCardClean - String',
    );
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
