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

use vars (qw($Self %Param));

my @Tests = (
    {
        Name           => 'Default format',
        DateFormatName => 'DateFormatLong',
        DateFormat     => '%T - %D.%M.%Y',
        Short          => 0,
        Time           => '2014-01-10 11:12:13',
        Result         => '11:12:13 - 10.01.2014',
    },
    {
        Name           => 'Default format, short',
        DateFormatName => 'DateFormatLong',
        DateFormat     => '%T - %D.%M.%Y',
        Short          => 1,
        Time           => '2014-01-10 11:12:13',
        Result         => '11:12 - 10.01.2014',
    },
    {
        Name           => 'Default format, only date passed',
        DateFormatName => 'DateFormatLong',
        DateFormat     => '%T - %D.%M.%Y',
        Short          => 0,
        Time           => '2014-01-10',
        Result         => '2014-01-10',
    },
    {
        Name           => 'Time zone on day border',
        UserTimeZone   => -1,
        DateFormatName => 'DateFormatLong',
        DateFormat     => '%T - %D.%M.%Y',
        Short          => 0,
        Time           => '2014-01-10 00:00:00',
        Result         => '23:00:00 - 09.01.2014 (-1)',
    },
    {
        Name           => 'Time zone on day border for DateFormatShort (TimeZone not applied)',
        UserTimeZone   => -1,
        DateFormatName => 'DateFormatShort',
        DateFormat     => '%T - %D.%M.%Y',
        Short          => 0,
        Time           => '2014-01-10 00:00:00',
        Result         => '00:00:00 - 10.01.2014',
    },
    {
        Name           => 'All tags test',
        DateFormatName => 'DateFormatLong',
        DateFormat     => '%A %B %T - %D.%M.%Y',
        Short          => 0,
        Time           => '2014-01-10 11:12:13',
        Result         => 'Fr Jan 11:12:13 - 10.01.2014',
    },
    {
        Name           => 'All tags test, with timezone',
        UserTimeZone   => -1,
        DateFormatName => 'DateFormatLong',
        DateFormat     => '%A %B %T - %D.%M.%Y',
        Short          => 0,
        Time           => '2014-01-10 11:12:13',
        Result         => 'Fr Jan 10:12:13 - 10.01.2014 (-1)',
    },
);

for my $Test (@Tests) {

    # discard language object
    $Kernel::OM->ObjectsDiscard(
        Objects => ['Language'],
    );

    # get language object
    $Kernel::OM->ObjectParamAdd(
        'Language' => {
            UserTimeZone => $Test->{UserTimeZone},
            UserLanguage => 'de',
        },
    );
    my $LanguageObject = $Kernel::OM->Get('Language');

    $LanguageObject->{ $Test->{DateFormatName} } = $Test->{DateFormat};

    my $Result = $LanguageObject->FormatTimeString(
        $Test->{Time},
        $Test->{DateFormatName},
        $Test->{Short}
    );

    $Self->Is(
        $Result,
        $Test->{Result},
        "$Test->{Name} - return",
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
