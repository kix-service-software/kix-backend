# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
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

use Time::Local;

use vars (qw($Self));

# init contact object for config changes
my $ContactObject = $Kernel::OM->Get('Contact');

my $CacheObject = $Kernel::OM->Get('Cache');

my $HelperObject = $Kernel::OM->Get('UnitTest::Helper');

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

# disable default Vacation days
$ConfigObject->Set(
    Key   => 'TimeVacationDays',
    Value => {},
);
$ConfigObject->Set(
    Key   => 'TimeVacationDays::Calendar1',
    Value => {},
);

# set time zone to local (use server TZ)
$ConfigObject->Set(
    Key   => 'TimeZone',
    Value => 'local',
);
$ConfigObject->Set(
    Key   => 'TimeWorkingHours',
    Value => {
        Mon => '08:00-16:00',
        Tue => '08:00-16:00',
        Wed => '08:00-16:00',
        Thu => '08:00-16:00',
        Fri => '08:00-16:00',
        Sat => '08:00-16:00',
        Sun => '08:00-16:00'
    }
);
$ConfigObject->Set(
    Key   => 'TimeWorkingHours::Calendar1',
    Value => {
        Mon => '10:00-18:00',
        Tue => '10:00-18:00',
        Wed => '10:00-18:00',
        Thu => '10:00-18:00',
        Fri => '10:00-18:00',
        Sat => '10:00-18:00',
        Sun => '10:00-18:00'
    }
);
$CacheObject->CleanUp();
my @Tests = (
    # BOB
    {
        Name           => 'Server: UTC (8-16)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 08:00:00',
        ServerTZ       => 'UTC',
        Type           => 'BOB',
    },
    {
        Name           => 'Server: Europe/Berlin (8-16)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 08:00:00',
        ServerTZ       => 'Europe/Berlin',
        Type           => 'BOB',
    },
    {
        Name           => 'Server: America/New_York (8-16)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 08:00:00',
        ServerTZ       => 'America/New_York',
        Type           => 'BOB',
    },
    # EOB
    {
        Name           => 'Server: UTC (8-16)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 16:00:00',
        ServerTZ       => 'UTC',
        Type           => 'EOB',
    },
    {
        Name           => 'Server: Europe/Berlin (8-16)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 16:00:00',
        ServerTZ       => 'Europe/Berlin',
        Type           => 'EOB',
    },
    {
        Name           => 'Server: America/New_York (8-16)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 16:00:00',
        ServerTZ       => 'America/New_York',
        Type           => 'EOB',
    },
    # BOB with calendar
    {
        Name           => 'Server: UTC ## Calendar: Europe/Berlin (10-18)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 09:00:00',                 # working starts at 10:00 in calendar (UTC+1h) => UTC = 9:00
        ServerTZ       => 'UTC',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
    },
    {
        Name           => 'Server: Europe/Berlin ## Calendar: Europe/Berlin (10-18)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 10:00:00',                 # working starts at 10:00 in calendar (UTC+1h) => server is same TZ = 10:00
        ServerTZ       => 'Europe/Berlin',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
    },
    {
        Name           => 'Server: America/New_York ## Calendar: Europe/Berlin (10-18)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 05:00:00',                 # working starts at 10:00 in calendar (UTC+1h) => 9:00 UTC => server UTC-4h (-5, but DST) = 5:00
        ServerTZ       => 'America/New_York',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
    },
    # EOB with calendar
    {
        Name           => 'Server: UTC ## Calendar: Europe/Berlin (10-18)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 17:00:00',
        ServerTZ       => 'UTC',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'EOB',
    },
    {
        Name           => 'Server: Europe/Berlin ## Calendar: Europe/Berlin (10-18)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 18:00:00',
        ServerTZ       => 'Europe/Berlin',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'EOB',
    },
    {
        Name           => 'Server: America/New_York ## Calendar: Europe/Berlin (10-18)',
        StartTimeStamp => '2023-03-23 12:00:00',
        StopTimeStamp  => '2023-03-23 13:00:00',                 # working starts at 18:00 in calendar (UTC+1h) => 17:00 UTC => server UTC-4h (-5, but DST) = 13:00
        ServerTZ       => 'America/New_York',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'EOB',
    },
);
_DoTests();

# without weekend
$ConfigObject->Set(
    Key   => 'TimeWorkingHours',
    Value => {
        Mon => '08:00-16:00',
        Tue => '08:00-16:00',
        Wed => '08:00-16:00',
        Thu => '08:00-16:00',
        Fri => '08:00-16:00',
    }
);
$ConfigObject->Set(
    Key   => 'TimeWorkingHours::Calendar1',
    Value => {
        Mon => '10:00-18:00',
        Tue => '10:00-18:00',
        Wed => '10:00-18:00',
        Thu => '10:00-18:00',
        Fri => '10:00-18:00',
    }
);
$CacheObject->CleanUp();
@Tests = (
    # BOB
    {
        Name           => 'Server: UTC (8-16 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00', # saturday => switch to monday
        StopTimeStamp  => '2023-03-27 08:00:00',
        ServerTZ       => 'UTC',
        Type           => 'BOB',
    },
    {
        Name           => 'Server: Europe/Berlin (8-16 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 08:00:00',
        ServerTZ       => 'Europe/Berlin',
        Type           => 'BOB',
    },
    # EOB
    {
        Name           => 'Server: UTC (8-16 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 16:00:00',
        ServerTZ       => 'UTC',
        Type           => 'EOB',
    },
    {
        Name           => 'Server: Europe/Berlin (8-16 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 16:00:00',
        ServerTZ       => 'Europe/Berlin',
        Type           => 'EOB',
    },
    # BOB with calendar
    {
        Name           => 'Server: UTC ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-18 12:00:00',
        StopTimeStamp  => '2023-03-20 09:00:00',                    # 10:00 for calendar, because of DST UTC+1h => 9:00
        ServerTZ       => 'UTC',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
    },
    {
        Name           => 'Server: UTC ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 08:00:00',                    # 10:00 for calendar, because of DST UTC+2h => 8:00
        ServerTZ       => 'UTC',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
    },
    {
        Name           => 'Server: Europe/Berlin ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 10:00:00',
        ServerTZ       => 'Europe/Berlin',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
    },
    {
        Name           => 'Server: America/New_York ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 04:00:00',                    # 10:00 (calendar) => 8:00 (UTC) => 4:00 (UTC-4h (DST))
        ServerTZ       => 'America/New_York',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
    },
    # EOB with calendar
    {
        Name           => 'Server: UTC ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 16:00:00',
        ServerTZ       => 'UTC',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'EOB',
    },
    {
        Name           => 'Server: Europe/Berlin ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 18:00:00',
        ServerTZ       => 'Europe/Berlin',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'EOB',
    },
    {
        Name           => 'Server: America/New_York ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 12:00:00',
        ServerTZ       => 'America/New_York',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'EOB',
    },
);
_DoTests();

sub _DoTests {
    for my $Test (@Tests) {

        # set the server time zone
        local $ENV{TZ} = $Test->{ServerTZ} || 'UTC';

        $ConfigObject->Set(
            Key   => 'TimeZone::Calendar1',
            Value => $Test->{CalendarTZ} || 'local',
        );

        $Kernel::OM->ObjectsDiscard(
            Objects => ['Time'],
        );

        # get time object
        my $TimeObject = $Kernel::OM->Get('Time');

        # Convert timestamp to system time and set it.
        $Test->{StartTimeStamp} =~ m/(\d{4})-(\d{1,2})-(\d{1,2})\s(\d{1,2}):(\d{1,2}):(\d{1,2})/;

        my $FixedTimeStart = Time::Local::timegm(
            $6, $5, $4, $3, ( $2 - 1 ), $1
        );

        $HelperObject->FixedTimeSet(
            $FixedTimeStart,
        );

        my $Result = $Test->{Type} eq 'BOB' ? $TimeObject->BOB(
            String   => $Test->{StartTimeStamp},
            Calendar => $Test->{CalendarTZ} ? 1 : undef,
            Debug    => 1
        ) : $TimeObject->EOB(
            String   => $Test->{StartTimeStamp},
            Calendar => $Test->{CalendarTZ} ? 1 : undef,
            Debug    => 1
        );

        $Self->Is(
            $Result,
            $Test->{StopTimeStamp},
            "$Test->{Name} :: $Test->{Type} of $Test->{StartTimeStamp}",
        );

        $HelperObject->FixedTimeUnset();
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
