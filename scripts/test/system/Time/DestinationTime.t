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

# set time zone to arbitrary value to make sure it is ignored
$ConfigObject->Set(
    Key   => 'TimeZone',
    Value => '',
);

# set full working hours
$ConfigObject->Set(
    Key   => 'TimeWorkingHours::Calendar1',
    Value => {
        Mon => '00:00-24:00',
        Tue => '00:00-24:00',
        Wed => '00:00-24:00',
        Thu => '00:00-24:00',
        Fri => '00:00-24:00',
        Sat => '00:00-24:00',
        Sun => '00:00-24:00'
    }
);
$ConfigObject->Set(
    Key   => 'TimeWorkingHours',
    Value => {
        Mon => '00:00-24:00',
        Tue => '00:00-24:00',
        Wed => '00:00-24:00',
        Thu => '00:00-24:00',
        Fri => '00:00-24:00',
        Sat => '00:00-24:00',
        Sun => '00:00-24:00'
    }
);
# remove cache (TimeWorkingHours preparations: TimeObject->_GetTimeWorking)
$CacheObject->CleanUp();
my @Tests = (
    {
        Name            => 'UTC',
        TimeStampStart  => '2015-02-17 12:00:00',
        ServerTZ        => 'UTC',
        Time            => 60 * 60 * 24 * 90,                                                 # 90 days
        TimeDate        => '90 days',
        DestinationTime => '2015-05-18 12:00:00',
    },
    {
        Name            => 'Europe/Berlin ( Daylight Saving Time UTC+1 => UTC+2 )',
        TimeStampStart  => '2015-02-17 12:00:00',
        ServerTZ        => 'Europe/Berlin',
        Time            => 60 * 60 * 24 * 90,
        TimeDate        => '90 days',                                                          # 90 days
        DestinationTime => '2015-05-18 13:00:00',                                              # 90 days like, but also 1h because of DST
    },
    {
        Name            => 'Europe/Berlin ( Daylight Saving Time UTC+1 => UTC+2 )',
        TimeStampStart  => '2023-03-25 12:00:00',
        ServerTZ        => 'Europe/Berlin',
        NoCalendar      => 1,
        Time            => 60 * 60 * 24,
        TimeDate        => '1 day',
        DestinationTime => '2023-03-26 13:00:00',
    },
    {
        Name            => 'UTC',
        TimeStampStart  => '2015-02-21 22:00:00',
        ServerTZ        => 'UTC',
        Time            => 60 * 60 * 6,                                                       # 6h
        TimeDate        => '6h',
        DestinationTime => '2015-02-22 04:00:00',
    },
    {
        Name            => 'America/Sao_Paulo - end DST from 00 to 23  ( UTC-2 => UTC-3 )',
        TimeStampStart  => '2015-02-21 22:00:00',
        ServerTZ        => 'America/Sao_Paulo',
        Time            => 60 * 60 * 5,                                                       # 5h
        TimeDate        => '5h',
        DestinationTime => '2015-02-22 02:00:00',
    },
    {
        Name            => 'UTC with min and sec',
        TimeStampStart  => '2015-02-20 22:10:05',
        ServerTZ        => 'UTC',
        Time            => 60 * 60 * 24 * 4 + 60 * 60 * 6 + 60 * 20 + 15,                     # 4 days 06:20:15
        TimeDate        => '4 days 06:20:15',
        DestinationTime => '2015-02-25 04:30:20',
    },
    {
        Name           => 'America/Sao_Paulo - end DST from 00 to 23 - with min and sec ( UTC-2 => UTC-3 )',
        TimeStampStart => '2015-02-21 22:10:05',
        ServerTZ       => 'America/Sao_Paulo',
        Time            => 60 * 60 * 24 * 4 + 60 * 60 * 5 + 60 * 20 + 15,                     # 4 days 05:20:15
        TimeDate        => '4 days 05:20:15',
        DestinationTime => '2015-02-26 02:30:20',
    },
    {
        Name            => 'UTC',
        TimeStampStart  => '2015-10-17 22:00:00',
        ServerTZ        => 'UTC',
        Time            => 60 * 60 * 6,                                                       # 6h
        TimeDate        => '6h',
        DestinationTime => '2015-10-18 04:00:00',
    },


    # {
    #     Name            => 'America/Sao_Paulo - start DST from 00 to 01 ( UTC-3 => UTC-2 )',
    #     TimeStampStart  => '2015-10-17 22:00:00',
    #     ServerTZ        => 'America/Sao_Paulo',
    #     Time            => 60 * 60 * 7,                                                        # 7h
    #     TimeDate        => '7h',
    #     DestinationTime => '2015-10-18 06:00:00',
    # },


    {
        Name            => 'UTC',
        TimeStampStart  => '2015-03-21 12:00:00',
        ServerTZ        => 'UTC',
        Time            => 60 * 60 * 24,                                                       # 24h
        TimeDate        => '24h',
        DestinationTime => '2015-03-22 12:00:00',
    },
    {
        Name            => 'UTC',
        TimeStampStart  => '2015-09-21 12:00:00',
        ServerTZ        => 'UTC',
        Time            => 60 * 60 * 16,                                                       # 16h
        TimeDate        => '16h',
        DestinationTime => '2015-09-22 04:00:00',
    },
    {
        Name            => 'Asia/Tehran - end DST from 00 to 23  ( UTC+3:30 => UTC+4:30 )',
        TimeStampStart  => '2015-09-21 12:00:00',
        ServerTZ        => 'Asia/Tehran',
        Time            => 60 * 60 * 15,                                                       # 15h
        TimeDate        => '15h',
        DestinationTime => '2015-09-22 02:00:00',
    },
    {
        Name            => 'UTC',
        TimeStampStart  => '2015-03-21 12:00:00',
        ServerTZ        => 'UTC',
        Time            => 60 * 60 * 16,                                                       # 16h
        TimeDate        => '16h',
        DestinationTime => '2015-03-22 04:00:00',
    },


    # {
    #     Name            => 'Asia/Tehran - end DST from 00 to 01  ( UTC+4:30 => UTC+3:30 )',
    #     TimeStampStart  => '2015-03-21 12:00:00',
    #     ServerTZ        => 'Asia/Tehran',
    #     Time            => 60 * 60 * 17,                                                       # 17h
    #     TimeDate        => '17h',
    #     DestinationTime => '2015-03-22 06:00:00',
    # },


    {
        Name            => 'UTC',
        TimeStampStart  => '2015-01-21 12:00:00',
        ServerTZ        => 'UTC',
        Time            => 60 * 60 * 24 * 90 + 60 * 60 * 16,                                   # 90 days and 16h
        TimeDate        => '90 days and 16h',
        DestinationTime => '2015-04-22 04:00:00',
    },
    {
        Name            => 'Australia/Sydney - end DST from 00 to 01  ( UTC+11 => UTC+10 )',
        TimeStampStart  => '2015-01-21 12:00:00',
        ServerTZ        => 'Australia/Sydney',
        Time            => 60 * 60 * 24 * 90 + 60 * 60 * 17,                                   # 90 days and 17h
        TimeDate        => '90 days and 17h',
        DestinationTime => '2015-04-22 04:00:00',
    },
);
_DoTests();

# new server UTC tests 24/7
@Tests = (
    {
        Name            => 'Server: UTC ## Calendar: UTC (24/7)',
        TimeStampStart  => '2023-02-22 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'UTC',
        Time            => 60 * 60 * 24 * 2,
        TimeDate        => '48 hours',            # 2 full days
        DestinationTime => '2023-02-24 12:00:00'
    },
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (24/7)',
        TimeStampStart  => '2023-02-22 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 60 * 60 * 24 * 2,
        TimeDate        => '48 hours',            # 2 full days
        DestinationTime => '2023-02-24 12:00:00'
    },
    {
        Name            => 'Server: UTC ## Calendar: America/New_York (24/7)',
        TimeStampStart  => '2023-02-22 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'America/New_York',    # -5h
        Time            => 60 * 60 * 24 * 2,
        TimeDate        => '48 hours',            # 2 full days
        DestinationTime => '2023-02-24 12:00:00'
    },
    # DST tests: 1h => 2h (2:00 to 3:00)
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampStart  => '2023-03-25 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 48,
        TimeDate        => '48 hours',            # one full day
        DestinationTime => '2023-03-27 12:00:00'
    },
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampStart  => '2023-03-25 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 24,
        TimeDate        => '24 hours',            # one full day
        DestinationTime => '2023-03-26 12:00:00'
    },
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampStart  => '2023-03-25 22:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 6,
        TimeDate        => '6 hours',
        DestinationTime => '2023-03-26 04:00:00' # 22:00 + 1h calendar offset => 23:00 + 6h + 1h DST => 6:00 - 2h calendar offset => 4:00
    },
    # 2h => 1h (3:00 to 2:00)
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampStart  => '2023-10-28 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 24,
        TimeDate        => '24 hours',           # one full day
        DestinationTime => '2023-10-29 12:00:00' # 12:00 + 2h calendar offset => 14:00 + 10h => 0:00 + 14h - 1DST => 13:00 - 1h offset => 12:00
    },
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampStart  => '2023-10-28 22:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 6,
        TimeDate        => '6 hours',
        DestinationTime => '2023-10-29 04:00:00' # 22:00 + 2h calendar offset => 0:00 + 6h - 1h DST => 5:00 - 1h calendar offset => 4:00
    },
    # -5h => -4h (2:00 to 3:00)
    {
        Name            => 'Server: UTC ## Calendar: America/New_York (24/7 - DST)',
        TimeStampStart  => '2023-03-25 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'America/New_York',
        Time            => 60 * 60 * 24,
        TimeDate        => '24 hours',            # one full day
        DestinationTime => '2023-03-26 12:00:00'  # 12:00 - 5h offset = 7:00 + 17h => 0:00 + 7h => 7:00 + 1h DST => 8:00 + 4h offset => 12:00
    },
    # -4h => -5h (3:00 to 2:00)
    {
        Name            => 'Server: UTC ## Calendar: America/New_York (24/7 - DST)',
        TimeStampStart  => '2023-11-04 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'America/New_York',
        Time            => 60 * 60 * 24,
        TimeDate        => '24 hours',            # one full day
        DestinationTime => '2023-11-05 12:00:00'  # 12:00 - 4h offset = 8:00 + 16h => 0:00 + 8h => 8:00 - 1h DST => 7:00 + 5h offset => 12:00
    },
    # 1h => 2h and 2h => 1h
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampStart  => '2023-03-25 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 24 * 218,
        TimeDate        => '218 days',
        DestinationTime => '2023-10-29 12:00:00'  # 12:00 + 1h offset => 13:00 to 0:00 (11h) + 24h * 216 (without start/end day) => 0:00 + 13h (24-11) + 1h DST (26.3.) -1h DST (29.10.) => 13:00 - 1h offset => 12:00
    },
    # 1h => 2h and without 2h => 1h (one day less than above)
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampStart  => '2023-03-25 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 24 * 217,
        TimeDate        => '217 days',
        DestinationTime => '2023-10-28 12:00:00'  # 12:00 + 1h offset => 13:00 to 0:00 (11h) + 24h * 215 (without start/end day) => 0:00 + 13h (24-11) + 1h DST => 14:00 - 2h offset => 12:00
    },
    # no calendar test (TZ should be UTC)
    {
        Name            => 'Server: UTC ## no calendar TZ',
        TimeStampStart  => '2023-03-25 22:00:00',
        ServerTZ        => 'UTC',
        NoCalendar      => 1,
        Time            => 60 * 60 * 6,
        TimeDate        => '6 hours',
        DestinationTime => '2023-03-26 04:00:00'  # 22:00 to 24:00 (2h) => 0:00 + 4h => 04:00
    },
);
_DoTests();

# server UTC tests (8-16) - 8h per day
$ConfigObject->Set(
    Key   => 'TimeWorkingHours::Calendar1',
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
$CacheObject->CleanUp();
@Tests = (
    {
        Name            => 'Server: UTC ## Calendar: UTC (8-16)',
        TimeStampStart  => '2023-02-22 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'UTC',
        Time            => 60 * 60 * 24 * 2,
        TimeDate        => '48 hours',
        DestinationTime => '2023-02-28 12:00:00'  # 48h = 12:00 to 16:00 (4h on first day) + 5 * 8h (40h) + 8:00 to 12:00 (4h on last day)
    },
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (8-16)',
        TimeStampStart  => '2023-02-22 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 60 * 60 * 24 * 2,
        TimeDate        => '48 hours',
        DestinationTime => '2023-02-28 12:00:00'  # 48h = 13:00 to 16:00 (3h on first day) + 5 * 8h (40h) + 8:00 to 13:00 (5h on last day)
    },
    {
        Name            => 'Server: UTC ## Calendar: America/New_York (8-16)',
        TimeStampStart  => '2023-02-22 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'America/New_York',   # -7h
        Time            => 60 * 60 * 24 * 2,
        TimeDate        => '48 hours',
        DestinationTime => '2023-02-27 21:00:00' # 48h = 7:00 => 8:00 to 16:00 (8h) + 5 * 8h (40h; 16:00 on last day)
    },
    # DST tests: 1h => 2h (2:00 to 3:00)
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (8-16 - DST)',
        TimeStampStart  => '2023-03-25 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 60 * 60 * 16,
        TimeDate        => '16 hours',
        DestinationTime => '2023-03-27 11:00:00'  # 12:00 + 1h offset => 13:00 to 16:00 (3h) => 8:00 to 16:00 (8h) => 8:00 +5h => 13:00 - 2h offset => 11:00
    },
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (8-16 - DST)',
        TimeStampStart  => '2023-03-25 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 60 * 60 * 8,
        TimeDate        => '8 hours',
        DestinationTime => '2023-03-26 11:00:00'  # 12:00 + 1h offset => 13:00 to 16:00 (3h) => 8:00 +5h => 13:00 - 2h offset => 11:00
    },
    # 2h => 1h (3:00 to 2:00)
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (8-16 - DST)',
        TimeStampStart  => '2023-10-28 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +2h (DST)
        Time            => 60 * 60 * 8,
        TimeDate        => '8 hours',
        DestinationTime => '2023-10-29 13:00:00'  # 12:00 + 2h offset => 14:00 to 16:00 (2h) => 8:00 + 6h => 14:00 - 1h offset => 13:00
    },
    # -5h => -4h (2:00 to 3:00)
    {
        Name            => 'Server: UTC ## Calendar: America/New_York (8-16 - DST)',
        TimeStampStart  => '2023-03-11 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'America/New_York',
        Time            => 60 * 60 * 8,
        TimeDate        => '10 hours',
        DestinationTime => '2023-03-11 21:00:00'  # 12:00 - 5h offset = 7:00 => 8:00 (begin) to 16:00 (8h) + 5h offset => 21:00 => NO DST change
    },
    {
        Name            => 'Server: UTC ## Calendar: America/New_York (8-16 - DST)',
        TimeStampStart  => '2023-03-11 14:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'America/New_York',
        Time            => 60 * 60 * 8,
        TimeDate        => '10 hours',
        DestinationTime => '2023-03-12 13:00:00'  # 14:00 - 5h offset = 9:00 to 16:00 (7h) => 8:00 + 1h => 9:00 + 4h offset => 13:00
    },
    # -4h => -5h (3:00 to 2:00)
    {
        Name            => 'Server: UTC ## Calendar: America/New_York (8-16 - DST)',
        TimeStampStart  => '2023-11-04 14:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'America/New_York',
        Time            => 60 * 60 * 8,
        TimeDate        => '8 hours',
        DestinationTime => '2023-11-05 15:00:00'  # 14:00 - 4h offset = 10:00 to 16:00 (6h) => 8:00 + 2h => 10:00 + 5h offset => 15:00
    },
    # 1h => 2h and 2h => 1h
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (8-16 - DST)',
        TimeStampStart  => '2023-03-25 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 8 * 218,
        TimeDate        => '218 days with 8h',
        DestinationTime => '2023-10-29 12:00:00'  # 12:00 + 1h offset => 13:00 to 16:00 (3h) => 8h * 216 (without start/end day) => 8:00 (end day) + 5h => 13:00 - 1h offset => 12:00
    },
    # 1h => 2h and without 2h => 1h (one day less than above)
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (8-16 - DST)',
        TimeStampStart  => '2023-03-25 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 8 * 217,
        TimeDate        => '217 days with 8h',
        DestinationTime => '2023-10-28 11:00:00'  # 12:00 + 1h offset => 13:00 to 16:00 (3h) => 8h * 215 (without start/end day) => 8:00 (end day) + 5h => 13:00 - 2h offset => 11:00
    },
    # no calendar test (TZ should be UTC)
    {
        Name            => 'Server: UTC ## no calendar TZ',
        TimeStampStart  => '2023-03-01 12:00:00',
        ServerTZ        => 'UTC',
        NoCalendar      => 1,
        Time            => 60 * 60 * 6,
        TimeDate        => '6 hours',
        DestinationTime => '2023-03-02 10:00:00'  # 12:00 to 16:00 (4h) => 8:00 + 2h => 10:00
    },
);
_DoTests();

# explicit DST test (server UTC)
$ConfigObject->Set(
    Key   => 'TimeWorkingHours::Calendar1',
    Value => {
        Sat => '00:00-24:00',
        Sun => '00:00-24:00'
    }
);
$CacheObject->CleanUp();
@Tests = (
    # 1h => 2h
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampStart  => '2023-03-25 23:01:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 60 * 60 * 2,
        TimeDate        => '2 hours',
        DestinationTime => '2023-03-26 01:01:00'  # 23:01 + 1h offset => 0:01 + 2h => 2:00 + 1h DST => 3:00 - 2h offset (DST) => 1:00
    },
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampStart  => '2023-03-25 23:59:59',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 20,
        TimeDate        => '20 seconds',
        DestinationTime => '2023-03-26 00:00:19'  # 23:59:59 + 1h offset => 00:59:59 + 20s => 01:00:19 - 1h offset => 00:00:19
    },
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampStart  => '2023-03-26 00:59:59',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 20,
        TimeDate        => '20 seconds',
        DestinationTime => '2023-03-26 01:00:19'  # 00:59:59 + 1h offset => 01:59:59 + 20s => 02:00:19 + 1h DST => 03:00:19 - 2h offset (DST) => 01:00:19
    },
    # 2h => 1h
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampStart  => '2023-10-28 23:59:59',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +2h (DST)
        Time            => 20,
        TimeDate        => '20 seconds',
        DestinationTime => '2023-10-29 00:00:19'  # 23:59:59 + 2h offset => 01:59:59 + 20s => 02:00:19 - 2h offset => 00:00:19
    },
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampStart  => '2023-10-29 01:59:59',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +2h (DST)
        Time            => 20,
        TimeDate        => '20 seconds',
        DestinationTime => '2023-10-29 02:00:19'  # 01:59:59 + 2h offset => 03:59:59 - 1h DST => 02:59:59 + 20s => 03:00:19 - 1h offset => 02:00:19
    },
);
_DoTests();

$ConfigObject->Set(
    Key   => 'TimeWorkingHours::Calendar1',
    Value => {
        Sat => '00:00-24:00',
        Sun => '01:45-24:00'
    }
);
$CacheObject->CleanUp();
@Tests = (
    # 1h => 2h
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampStart  => '2023-03-25 22:45:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 60 * 30,
        TimeDate        => '30 minutes',
        DestinationTime => '2023-03-26 01:00:00'  # 22:45 + 1h offset => 23:45 + 15m = 0:00 => 01:45 (begin) + 15m => 02:00 + 1h DST => 03:00 - 2h offset (DST) => 01:00
    },
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampStart  => '2023-03-26 00:30:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 60 * 30,
        TimeDate        => '30 minutes',
        DestinationTime => '2023-03-26 01:15:00'  # 00:30 + 1h offset => 01:30 => 01:45 (begin) + 30m => 02:15 + 1h DST => 03:15 - 2h offset (DST) => 01:15
    },
    # 2h => 1h
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampStart  => '2023-10-29 00:45:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 60 * 30,
        TimeDate        => '30 minutes',
        DestinationTime => '2023-10-29 01:15:00'  # 0:45 + 2h offset => 2:45 + 30m => 03:15 - 1h DST => 2:15 - 1h offset (DST) => 01:15
    },
);
_DoTests();

$ConfigObject->Set(
    Key   => 'TimeWorkingHours::Calendar1',
    Value => {
        Sat => '00:00-24:00',
        # Sun => '00:00-24:00', # no working time on DST switch day
        Mon => '00:00-24:00'
    }
);
$CacheObject->CleanUp();
@Tests = (
    # 1h => 2h
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampStart  => '2023-03-25 22:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 60 * 60 * 4,
        TimeDate        => '4 hours',
        DestinationTime => '2023-03-26 01:00:00'  # 22:00 + 1h offset => 23:00 to 24:00 (1h) => 0:00 + 3h => 3:00 - 2h offset => 01:00
    },
);
_DoTests();

# server TZ test with (8-16) - 8h per day
$ConfigObject->Set(
    Key   => 'TimeWorkingHours::Calendar1',
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
    Key   => 'TimeZone',
    Value => 'local'
);
$CacheObject->CleanUp();
@Tests = (
    # TODO: add some test without DST
    {
        Name            => 'Server: Europe/Berlin ## Calendar: UTC - WorkingTime',
        TimeStampStart  => '2023-03-01 14:00:00',
        ServerTZ        => 'Europe/Berlin',
        CalendarTZ      => 'UTC',
        Time            => 60 * 60 * 4,
        TimeDate        => '4 hours',
        DestinationTime => '2023-03-02 10:00:00' # 14:00 (13:00 UTC) to 16:00 (3h) => 8:00 + 1h = 09:00 (UTC) => 10:00
    },
    {
        Name            => 'Server: Europe/Berlin ## Calendar: local - WorkingTime',
        TimeStampStart  => '2023-03-01 14:00:00',
        ServerTZ        => 'Europe/Berlin',
        CalendarTZ      => 'local',
        Time            => 60 * 60 * 4,
        TimeDate        => '4 hours',
        DestinationTime => '2023-03-02 10:00:00' # 14:00 => 13:00 (UTC) + 1h calendar offset => 14:00 to 16:00 (2h) => 8:00 + 2h => 10:00 - 1h calendar offset => 9:00 (UTC) => 10:00
    },
    {
        Name            => 'Server: Europe/Berlin ## Calendar: Europe/Berlin - WorkingTime',
        TimeStampStart  => '2023-03-01 14:00:00',
        ServerTZ        => 'Europe/Berlin',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 4,
        TimeDate        => '4 hours',
        DestinationTime => '2023-03-02 10:00:00' # like above
    },
    {
        Name            => 'Server: Europe/Berlin ## Calendar: America/New_York - WorkingTime',
        TimeStampStart  => '2023-03-01 16:00:00',
        ServerTZ        => 'Europe/Berlin',
        CalendarTZ      => 'America/New_York',
        Time            => 60 * 60 * 4,
        TimeDate        => '4 hours',
        DestinationTime => '2023-03-01 20:00:00' # 16:00 => 15:00 (UTC) -5h calendar offset => 10:00 + 4h => 14:00 + 5h offset => 19:00 (UTC) => 20:00
    },
    {
        Name            => 'Server: America/New_York ## Calendar: Europe/Berlin - WorkingTime',
        TimeStampStart  => '2023-03-01 18:00:00',
        ServerTZ        => 'America/New_York',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 4,
        TimeDate        => '4 hours',
        DestinationTime => '2023-03-02 06:00:00' # 18:00 (23:00 UTC) + 1h calendar offset => 24:00 => 8:00 + 4h => 12:00 - 1h calendar offset => 11:00 (UTC) => 6:00
    },
    {
        Name            => 'Server: America/New_York ## Calendar: Europe/Berlin - WorkingTime',
        TimeStampStart  => '2023-03-01 09:00:00',
        ServerTZ        => 'America/New_York',
        CalendarTZ      => 'Europe/Berlin',
        Time            => 60 * 60 * 4,
        TimeDate        => '4 hours',
        DestinationTime => '2023-03-02 05:00:00' # 9:00 (14:00 UTC) + 1h calendar offset => 15:00 to 16:00 (1h) => 8:00 + 3h => 11:00 - 1h calendar offset => 10:00 (UTC) => 5:00
    },
    {
        Name            => 'Server: Europe/Berlin ## no calendar (should be local) - WorkingTime',
        TimeStampStart  => '2023-03-01 14:00:00',
        ServerTZ        => 'Europe/Berlin',
        NoCalendar      => 1,
        Time            => 60 * 60 * 4,
        TimeDate        => '4 hours',
        DestinationTime => '2023-03-02 10:00:00' # 14:00 => 13:00 (UTC) + 1h calendar offset => 14:00 to 16:00 (2h) => 8:00 + 2h => 10:00 - 1h calendar offset => 9:00 (UTC) => 10:00
    },
    # DST: 1h => 2h
    {
        Name            => 'Server: Europe/Berlin ## Calendar: UTC - WorkingTime - DST',
        TimeStampStart  => '2023-03-25 15:00:00',
        ServerTZ        => 'Europe/Berlin',
        CalendarTZ      => 'UTC',
        Time            => 60 * 60 * 4,
        TimeDate        => '4 hours',
        DestinationTime => '2023-03-26 12:00:00' # 15:00 (14:00 UTC) to 16:00 (2h) => 8:00 + 2h = 10:00 (UTC) => 12:00 (2h because of DST)
    },
    {
        Name            => 'Server: Europe/Berlin ## Calendar: local - WorkingTime - DST',
        TimeStampStart  => '2023-03-25 15:00:00',
        ServerTZ        => 'Europe/Berlin',
        CalendarTZ      => 'local',
        Time            => 60 * 60 * 4,
        TimeDate        => '4 hours',
        DestinationTime => '2023-03-26 11:00:00' # 15:00 (14:00 UTC) + 1h calendar offset = 15:00 to 16:00 (1h) => 8:00 + 3h = 11:00 - 2h calendar offset (DST) = 09:00 (UTC) => 11:00 (2h because of DST)
    },
);
_DoTests();

# check if (free) weekend and vacation day is considered
$ConfigObject->Set(
    Key   => 'TimeWorkingHours::Calendar1',
    Value => {
        Mon => '00:00-24:00',
        Tue => '00:00-24:00',
        Wed => '00:00-24:00',
        Thu => '00:00-24:00',
        Fri => '00:00-24:00',
    }
);
$ConfigObject->Set(
    Key   => 'TimeVacationDays::Calendar1',
    Value => [
        {
          Month   => 3,
          Day     => 1,
          content => 'test vacation day'
        }
    ]
);
$CacheObject->CleanUp();
@Tests = (
    {
        Name            => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampStart  => '2023-02-27 12:00:00',
        ServerTZ        => 'UTC',
        CalendarTZ      => 'Europe/Berlin',       # +1h
        Time            => 60 * 60 * 24 * 7,
        TimeDate        => '1 week',              # 168h
        DestinationTime => '2023-03-09 12:00:00'  # 12:00 + 1h offset => 13:00 to 24:00 (11h) => 24h * 6 (28th,2nd,3rd,6th,7th,8th = 144h) => 0:00 + 13h = 13:00 - 1h offset => 12:00
    },
);
_DoTests();

sub _DoTests {
    for my $Test (@Tests) {

        $Test->{CalendarTZ} ||= 'local';
        $ConfigObject->Set(
            Key   => 'TimeZone::Calendar1',
            Value => $Test->{CalendarTZ},
        );

        # set the server time zone
        local $ENV{TZ} = $Test->{ServerTZ} || 'UTC';

        $Kernel::OM->ObjectsDiscard(
            Objects => ['Time'],
        );

        # get time object
        my $TimeObject = $Kernel::OM->Get('Time');

        # convert UTC timestamp to system time and set it
        $Test->{TimeStampStart} =~ m/(\d{4})-(\d{1,2})-(\d{1,2})\s(\d{1,2}):(\d{1,2}):(\d{1,2})/;

        my $TimeStart = Time::Local::timegm(
            $6, $5, $4, $3, ( $2 - 1 ), $1
        );

        $HelperObject->FixedTimeSet(
            $TimeStart,
        );

        my $StartTime = $TimeObject->TimeStamp2SystemTime(
            String => $Test->{TimeStampStart},
        );

        my $DestinationTime = $TimeObject->DestinationTime(
            StartTime => $StartTime,
            Time      => $Test->{Time},
            Calendar  => $Test->{NoCalendar} ? undef : 1,
            Debug     => 1    # show debug output

        );

        my $DestinationTimeStamp = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $DestinationTime,
        );

        $Self->Is(
            $DestinationTimeStamp,
            $Test->{DestinationTime},
            "$Test->{Name} :: $Test->{TimeStampStart} + $Test->{TimeDate}",
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
