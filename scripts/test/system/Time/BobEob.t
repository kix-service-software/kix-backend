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

use Time::Local;

use vars (qw($Self));

my $HelperObject = $Kernel::OM->Get('UnitTest::Helper');

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

@Tests = (
    # BOB
    {
        Name           => 'Server: UTC (8-16 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00', # saturday => switch to monday
        StopTimeStamp  => '2023-03-27 08:00:00',
        ServerTZ       => 'UTC',
        Type           => 'BOB',
        WorkingTime    => '8/5',
    },
    {
        Name           => 'Server: Europe/Berlin (8-16 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 08:00:00',
        ServerTZ       => 'Europe/Berlin',
        Type           => 'BOB',
        WorkingTime    => '8/5',
    },
    # EOB
    {
        Name           => 'Server: UTC (8-16 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 16:00:00',
        ServerTZ       => 'UTC',
        Type           => 'EOB',
        WorkingTime    => '8/5',
    },
    {
        Name           => 'Server: Europe/Berlin (8-16 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 16:00:00',
        ServerTZ       => 'Europe/Berlin',
        Type           => 'EOB',
        WorkingTime    => '8/5',
    },
    # BOB with calendar
    {
        Name           => 'Server: UTC ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-18 12:00:00',
        StopTimeStamp  => '2023-03-20 09:00:00',                    # 10:00 for calendar, because of DST UTC+1h => 9:00
        ServerTZ       => 'UTC',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
        WorkingTime    => '8/5',
    },
    {
        Name           => 'Server: UTC ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 08:00:00',                    # 10:00 for calendar, because of DST UTC+2h => 8:00
        ServerTZ       => 'UTC',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
        WorkingTime    => '8/5',
    },
    {
        Name           => 'Server: Europe/Berlin ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 10:00:00',
        ServerTZ       => 'Europe/Berlin',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
        WorkingTime    => '8/5',
    },
    {
        Name           => 'Server: America/New_York ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 04:00:00',                    # 10:00 (calendar) => 8:00 (UTC) => 4:00 (UTC-4h (DST))
        ServerTZ       => 'America/New_York',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'BOB',
        WorkingTime    => '8/5',
    },
    # EOB with calendar
    {
        Name           => 'Server: UTC ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 16:00:00',
        ServerTZ       => 'UTC',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'EOB',
        WorkingTime    => '8/5',
    },
    {
        Name           => 'Server: Europe/Berlin ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 18:00:00',
        ServerTZ       => 'Europe/Berlin',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'EOB',
        WorkingTime    => '8/5',
    },
    {
        Name           => 'Server: America/New_York ## Calendar: Europe/Berlin (10-18 Mon-Fri)',
        StartTimeStamp => '2023-03-25 12:00:00',
        StopTimeStamp  => '2023-03-27 12:00:00',
        ServerTZ       => 'America/New_York',
        CalendarTZ     => 'Europe/Berlin',
        Type           => 'EOB',
        WorkingTime    => '8/5',
    },
);
_DoTests();

sub _DoTests {
    for my $Test (@Tests) {

        # set the server time zone
        local $ENV{TZ} = $Test->{ServerTZ} || 'UTC';

        $Kernel::OM->ObjectsDiscard(
            Objects => ['Time'],
        );

        # needed to make config changes work
        $Kernel::OM->Get('Time')->VacationCheck(
            Year     => '2004',
            Month    => '1',
            Day      => '1',
            Calendar => q{},
        );

        if ( defined $Test->{CalendarTZ} ) {
            $Kernel::OM->Get('Config')->Set(
                Key   => 'TimeZone::Calendar1',
                Value => $Test->{CalendarTZ},
            );
        }

        # disable default Vacation days
        $Kernel::OM->Get('Config')->Set(
            Key   => 'TimeVacationDaysModules',
            Value => {},
        );
        $Kernel::OM->Get('Config')->Set(
            Key   => 'TimeVacationDays',
            Value => [],
        );
        $Kernel::OM->Get('Config')->Set(
            Key   => 'TimeVacationDaysOneTime',
            Value => {},
        );
        $Kernel::OM->Get('Config')->Set(
            Key   => 'TimeVacationDaysModules::Calendar1',
            Value => {},
        );
        $Kernel::OM->Get('Config')->Set(
            Key   => 'TimeVacationDays::Calendar1',
            Value => [],
        );
        $Kernel::OM->Get('Config')->Set(
            Key   => 'TimeVacationDaysOneTime::Calendar1',
            Value => {},
        );

        # set time zone to local (use server TZ)
        $Kernel::OM->Get('Config')->Set(
            Key   => 'TimeZone',
            Value => 'local',
        );

        $Test->{WorkingTime} ||= '8/7';
        if ( $Test->{WorkingTime} eq '8/7' ) {
            # server UTC tests (8-16) - 8h per day
            $Kernel::OM->Get('Config')->Set(
                Key   => 'TimeWorkingHours',
                Value => {
                    Mon => '08:00-16:00',
                    Tue => '08:00-16:00',
                    Wed => '08:00-16:00',
                    Thu => '08:00-16:00',
                    Fri => '08:00-16:00',
                    Sat => '08:00-16:00',
                    Sun => '08:00-16:00',
                }
            );
            $Kernel::OM->Get('Config')->Set(
                Key   => 'TimeWorkingHours::Calendar1',
                Value => {
                    Mon => '10:00-18:00',
                    Tue => '10:00-18:00',
                    Wed => '10:00-18:00',
                    Thu => '10:00-18:00',
                    Fri => '10:00-18:00',
                    Sat => '10:00-18:00',
                    Sun => '10:00-18:00',
                }
            );
        }
        elsif ( $Test->{WorkingTime} eq '8/5' ) {
            # server UTC tests (8-16) - 8h per day without weekend
            $Kernel::OM->Get('Config')->Set(
                Key   => 'TimeWorkingHours',
                Value => {
                    Mon => '08:00-16:00',
                    Tue => '08:00-16:00',
                    Wed => '08:00-16:00',
                    Thu => '08:00-16:00',
                    Fri => '08:00-16:00',
                }
            );
            $Kernel::OM->Get('Config')->Set(
                Key   => 'TimeWorkingHours::Calendar1',
                Value => {
                    Mon => '10:00-18:00',
                    Tue => '10:00-18:00',
                    Wed => '10:00-18:00',
                    Thu => '10:00-18:00',
                    Fri => '10:00-18:00',
                }
            );
        }

        # remove cache (TimeWorkingHours preparations: TimeObject->_GetTimeWorking)
        $Kernel::OM->Get('Cache')->CleanUp();

        # Convert timestamp to system time and set it.
        $Test->{StartTimeStamp} =~ m/(\d{4})-(\d{1,2})-(\d{1,2})\s(\d{1,2}):(\d{1,2}):(\d{1,2})/;

        my $FixedTimeStart = Time::Local::timegm(
            $6, $5, $4, $3, ( $2 - 1 ), $1
        );

        $HelperObject->FixedTimeSet(
            $FixedTimeStart,
        );

        my $Result = $Test->{Type} eq 'BOB' ? $Kernel::OM->Get('Time')->BOB(
            String   => $Test->{StartTimeStamp},
            Calendar => $Test->{CalendarTZ} ? 1 : undef,
        ) : $Kernel::OM->Get('Time')->EOB(
            String   => $Test->{StartTimeStamp},
            Calendar => $Test->{CalendarTZ} ? 1 : undef,
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
