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

use Kernel::System::WebUserAgent;

use Kernel::System::VariableCheck qw(:all);

my $TestNumber = 1;
my $TimeOut    = $Kernel::OM->Get('Config')->Get('WebUserAgent::Timeout');
my $Proxy      = $Kernel::OM->Get('Config')->Get('WebUserAgent::Proxy');

my @Tests = (
    {
        Name        => 'GET - empty url - Test ' . $TestNumber++,
        URL         => "",
        Timeout     => $TimeOut,
        Proxy       => $Proxy,
        Success     => 0,
        ErrorNumber => 400,
        Silent      => 1,
    },
    {
        Name        => 'GET - wrong url - Test ' . $TestNumber++,
        URL         => "wrongurl",
        Timeout     => $TimeOut,
        Proxy       => $Proxy,
        Success     => 0,
        ErrorNumber => 400,
        Silent      => 1,
    },
    {
        Name        => 'GET - invalid url - Test ' . $TestNumber++,
        URL         => "http://novalidurl",
        Timeout     => $TimeOut,
        Proxy       => $Proxy,
        Success     => 0,
        ErrorNumber => $Proxy ? 503 : 500,
        Silent      => 1,
    },
    {
        Name        => 'GET - http - invalid proxy - Test ' . $TestNumber++,
        URL         => "http://packages.kixdesk.com/repository/debian/PublicKey",
        Timeout     => $TimeOut,
        Proxy       => 'http://NoProxy',
        Success     => 0,
        ErrorNumber => 500,
        Silent      => 1,
    },
    {
        Name        => 'GET - http - ftp proxy - Test ' . $TestNumber++,
        URL         => "http://packages.kixdesk.com/repository/debian/PublicKey",
        Timeout     => $TimeOut,
        Proxy       => 'ftp://NoProxy',
        Success     => 0,
        ErrorNumber => 400,
        Silent      => 1,
    },
    {
        Name    => 'GET - http - long timeout - Test ' . $TestNumber++,
        URL     => "http://packages.kixdesk.com/repository/debian/PublicKey",
        Timeout => 60,
        Proxy   => $Proxy,
        Success => 1,
    },
    {
        Name    => 'GET - http - Test ' . $TestNumber++,
        URL     => "http://packages.kixdesk.com/repository/debian/PublicKey",
        Timeout => $TimeOut,
        Proxy   => $Proxy,
        Success => 1,
    },
    {
        Name    => 'GET - https - Test ' . $TestNumber++,
        URL     => "https://packages.kixdesk.com/repository/debian/PublicKey",
        Timeout => $TimeOut,
        Proxy   => $Proxy,
        Success => 1,
    },
    {
        Name    => 'GET - http - Header ' . $TestNumber++,
        URL     => "http://packages.kixdesk.com/repository/debian/PublicKey",
        Timeout => $TimeOut,
        Proxy   => $Proxy,
        Success => 1,
        Header  => {
            Content_Type => 'text/json',
        },
        Return  => 'REQUEST',
        Matches => qr!Content-Type:\s+text/json!,
    },
    {
        Name        => 'GET - http - Credentials ' . $TestNumber++,
        URL         => "https://testit.kixdesk.com/unittest/HTTPBasicAuth/",
        Timeout     => $TimeOut,
        Proxy       => $Proxy,
        Success     => 1,
        Credentials => {
            User     => 'unittest',
            Password => 'unittest',
            Realm    => 'KIX UnitTest',
            Location => 'testit.kixdesk.com:443',
        },
    },
    {
        Name        => 'GET - http - MissingCredentials ' . $TestNumber++,
        URL         => "https://testit.kixdesk.com/unittest/HTTPBasicAuth/",
        Timeout     => $TimeOut,
        Proxy       => $Proxy,
        Success     => 0,
        ErrorNumber => 401,
        Silent      => 1,
    },
    {
        Name        => 'GET - http - IncompleteCredentials ' . $TestNumber++,
        URL         => "https://testit.kixdesk.com/unittest/HTTPBasicAuth/",
        Timeout     => $TimeOut,
        Proxy       => $Proxy,
        Credentials => {
            User     => 'unittest',
            Password => 'unittest',
        },
        Success     => 0,
        ErrorNumber => 401,
        Silent      => 1,
    },
);

TEST:
for my $Test (@Tests) {

    TRY:
    for my $Try ( 1 .. 5 ) {
        my $WebUserAgentObject = Kernel::System::WebUserAgent->new(
            Timeout => $Test->{Timeout},
            Proxy   => $Test->{Proxy},
        );

        $Self->Is(
            ref $WebUserAgentObject,
            'Kernel::System::WebUserAgent',
            "$Test->{Name} - WebUserAgent object creation",
        );

        my %Response = $WebUserAgentObject->Request(
            %{$Test},
        );

        $Self->True(
            IsHashRefWithData( \%Response ),
            "$Test->{Name} - WebUserAgent check structure from request",
        );

        my $Status = substr $Response{Status}, 0, 3;

        $Self->True(
            $Status == $Response{HTTPCode},
            "$Test->{Name} - First three digits of status matching http code",
        );

        if ( !$Test->{Success} ) {

            if ( $Try < 5 && $Status eq 500 && $Test->{ErrorNumber} ne 500 ) {
                sleep 3;

                next TRY;
            }

            $Self->False(
                $Response{Content},
                "$Test->{Name} - WebUserAgent fail test for URL: $Test->{URL}",
            );

            $Self->Is(
                $Status,
                $Test->{ErrorNumber},
                "$Test->{Name} - WebUserAgent - Check error number",
            );

            next TEST;
        }
        else {

            if ( $Try < 5 && ( !$Response{Content} || !$Status || $Status ne 200 ) ) {
                sleep 3;

                next TRY;
            }

            $Self->True(
                $Response{Content},
                "$Test->{Name} - WebUserAgent - Success test for URL: $Test->{URL}",
            );

            $Self->Is(
                $Status,
                200,
                "$Test->{Name} - WebUserAgent - Check request status",
            );

            if ( $Test->{Matches} ) {
                $Self->True(
                    ( ref( $Response{Content} ) eq 'SCALAR' ) ? ( ${ $Response{Content} } =~ $Test->{Matches} ) : undef,
                    "$Test->{Name} - Matches",
                );
            }
        }

        if ( $Test->{Content} ) {

            $Self->Is(
                ${ $Response{Content} },
                $Test->{Content},
                "$Test->{Name} - WebUserAgent - Check request content",
            );
        }
    }
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
