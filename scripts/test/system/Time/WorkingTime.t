# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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
        Name              => 'UTC',
        TimeStampUTCStart => '2015-02-17 12:00:00',
        TimeStampUTCStop  => '2015-05-18 12:00:00',
        ServerTZ          => 'UTC',
        Result            => '7776000',               # 90 days
        ResultTime        => '90 days',
    },
    {
        Name              => 'Europe/Berlin ( Daylight Saving Time UTC+1 => UTC+2 )',
        TimeStampUTCStart => '2015-02-17 12:00:00',
        TimeStampUTCStop  => '2015-05-18 12:00:00',
        ServerTZ          => 'Europe/Berlin',
        Result            => '7779600',                                                 # 90 days and 1h
        ResultTime        => '90 days and 1h',
    },
    {
        Name              => 'UTC',
        TimeStampUTCStart => '2015-02-21 22:00:00',
        TimeStampUTCStop  => '2015-02-22 04:00:00',
        ServerTZ          => 'UTC',
        Result            => '21600',                                                   # 6h
        ResultTime        => '6h',
    },
    {
        Name              => 'America/Sao_Paulo - end DST from 00 to 23  ( UTC-2 => UTC-3 )',
        TimeStampUTCStart => '2015-02-21 22:00:00',
        TimeStampUTCStop  => '2015-02-22 04:00:00',
        ServerTZ          => 'America/Sao_Paulo',
        Result            => '18000',                                                           # 5h
        ResultTime        => '5h',
    },
    {
        Name              => 'UTC with min and sec',
        TimeStampUTCStart => '2015-02-20 22:10:05',
        TimeStampUTCStop  => '2015-02-25 04:30:20',
        ServerTZ          => 'UTC',
        Result            => '368415',                                                          # 4 days 06:20:15
        ResultTime        => '4 days 06:20:15',
    },
    {
        Name              => 'America/Sao_Paulo - end DST from 00 to 23 - with min and sec',
        TimeStampUTCStart => '2015-02-20 22:10:05',
        TimeStampUTCStop  => '2015-02-25 04:30:20',
        ServerTZ          => 'America/Sao_Paulo',
        Result            => '364815',                                                          # 4 days 05:20:15
        ResultTime        => '4 days 05:20:15',
    },
    {
        Name              => 'UTC',
        TimeStampUTCStart => '2015-10-17 22:00:00',
        TimeStampUTCStop  => '2015-10-18 04:00:00',
        ServerTZ          => 'UTC',
        Result            => '21600',                                                           # 6h
        ResultTime        => '6h',
    },
    {
        Name              => 'America/Sao_Paulo - start DST from 00 to 01 ( UTC-3 => UTC-2 )',
        TimeStampUTCStart => '2015-10-17 22:00:00',
        TimeStampUTCStop  => '2015-10-18 04:00:00',
        ServerTZ          => 'America/Sao_Paulo',
        Result            => '25200',                                                            # 7h
        ResultTime        => '7h',
    },
    {
        Name              => 'UTC',
        TimeStampUTCStart => '2015-03-21 12:00:00',
        TimeStampUTCStop  => '2015-03-22 12:00:00',
        ServerTZ          => 'UTC',
        Result            => '86400',                                                            # 24h
        ResultTime        => '24h',
    },
    {
        Name              => 'UTC',
        TimeStampUTCStart => '2015-09-21 12:00:00',
        TimeStampUTCStop  => '2015-09-22 04:00:00',
        ServerTZ          => 'UTC',
        Result            => '57600',                                                            # 16h
        ResultTime        => '16h',
    },
    {
        Name              => 'Asia/Tehran - end DST from 00 to 23  ( UTC+3:30 => UTC+4:30 )',
        TimeStampUTCStart => '2015-09-21 12:00:00',
        TimeStampUTCStop  => '2015-09-22 04:00:00',
        ServerTZ          => 'Asia/Tehran',
        Result            => '54000',                                                            # 15h
        ResultTime        => '15h',
    },
    {
        Name              => 'UTC',
        TimeStampUTCStart => '2015-03-21 12:00:00',
        TimeStampUTCStop  => '2015-03-22 04:00:00',
        ServerTZ          => 'UTC',
        Result            => '57600',                                                            # 16h
        ResultTime        => '16h',
    },
    {
        Name              => 'Asia/Tehran - end DST from 00 to 01  ( UTC+4:30 => UTC+3:30 )',
        TimeStampUTCStart => '2015-03-21 12:00:00',
        TimeStampUTCStop  => '2015-03-22 04:00:00',
        ServerTZ          => 'Asia/Tehran',
        Result            => '61200',                                                            # 17h
        ResultTime        => '17h',
    },
    {
        Name              => 'UTC',
        TimeStampUTCStart => '2015-01-21 12:00:00',
        TimeStampUTCStop  => '2015-04-22 04:00:00',
        ServerTZ          => 'UTC',
        Result            => '7833600',                                                          # 90 days and 16h
        ResultTime        => '90 days and 16h',
    },
    {
        Name              => 'Australia/Sydney - end DST from 00 to 01  ( UTC+11 => UTC+10 )',
        TimeStampUTCStart => '2015-01-21 12:00:00',
        TimeStampUTCStop  => '2015-04-22 04:00:00',
        ServerTZ          => 'Asia/Tehran',
        Result            => '7837200',                                                          # 90 days and 17h
        ResultTime        => '90 days and 17h',
    },
);
##############################
# TODO: wieder aktivieren
# _DoTests();
##############################

@Tests = (
    {
        Name              => 'Server: UTC ## Calendar: UTC (24/7)',
        TimeStampUTCStart => '2023-03-06 12:00:00',
        TimeStampUTCStop  => '2023-03-07 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'UTC',
        Result            => 60 * 60 * 24,              # 1 day
        ResultTime        => '24 hours',
    },
    {
        Name              => 'Server: UTC ## no calendar (24/7)',
        TimeStampUTCStart => '2023-03-06 12:00:00',
        TimeStampUTCStop  => '2023-03-07 12:00:00',
        ServerTZ          => 'UTC',
        NoCalendar        => 1,
        Result            => 60 * 60 * 24,              # 1 day
        ResultTime        => '24 hours',
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (24/7)',
        TimeStampUTCStart => '2023-03-06 12:00:00',
        TimeStampUTCStop  => '2023-03-07 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 24,              # 1 day
        ResultTime        => '24 hours',
    },
    {
        Name              => 'Server: UTC ## Calendar: America/New_York (24/7)',
        TimeStampUTCStart => '2023-03-06 12:00:00',
        TimeStampUTCStop  => '2023-03-07 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'America/New_York',
        Result            => 60 * 60 * 24,              # 1 day
        ResultTime        => '24 hours',
    },
    # DST: 1h => 2h
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampUTCStart => '2023-03-25 12:00:00',
        TimeStampUTCStop  => '2023-03-26 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 24,              # 1 day
        ResultTime        => '24 hours',                # 13:00 to 24:00 (11h) => 0:00 to 14:00 (14h - 1h DST = 13h) => 24h
    },
    # DST: -5h => -4h
    {
        Name              => 'Server: UTC ## Calendar: America/New_York (24/7 - DST)',
        TimeStampUTCStart => '2023-03-11 12:00:00',
        TimeStampUTCStop  => '2023-03-12 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'America/New_York',
        Result            => 60 * 60 * 24,              # 1 day
        ResultTime        => '24 hours',
    },
    # DST: 2h => 1h
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampUTCStart => '2023-10-28 12:00:00',
        TimeStampUTCStop  => '2023-10-29 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 24,              # 1 day
        ResultTime        => '24 hours',
    },
    # DST: -4h => -5h
    {
        Name              => 'Server: UTC ## Calendar: America/New_York (24/7 - DST)',
        TimeStampUTCStart => '2023-11-04 12:00:00',
        TimeStampUTCStop  => '2023-11-05 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'America/New_York',
        Result            => 60 * 60 * 24,              # 1 day
        ResultTime        => '24 hours',
    },
    # DST: 1h => 2h => 1h
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampUTCStart => '2023-03-25 12:00:00',
        TimeStampUTCStop  => '2023-10-29 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 24 * 218,              # 218 days
        ResultTime        => '218 days',
    },
    # DST: -5 => -4h => -5h
    {
        Name              => 'Server: UTC ## Calendar: America/New_York (24/7 - DST)',
        TimeStampUTCStart => '2023-03-11 12:00:00',
        TimeStampUTCStop  => '2023-11-05 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'America/New_York',
        Result            => 60 * 60 * 24 * 239,              # 239 days
        ResultTime        => '239 days',
    },
    # DST: 1h => 2h => 1h => 2h
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampUTCStart => '2023-03-25 12:00:00',
        TimeStampUTCStop  => '2024-03-31 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 24 * 372,              # 372 days
        ResultTime        => '372 days',                      # 12:00 + 1h offset = 13:00 to 24:00 = 11h => 371*24 => 0:00 to 14:00 (12:00 + 2h offset) = 14h - 1h DST = 13h => 11+371*24+13 = 8928h (/24 = 372d)
    },
    # DST: 1h => 2h - check when calculation is around switch
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampUTCStart => '2023-03-26 01:00:00',
        TimeStampUTCStop  => '2023-03-26 03:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 2,
        ResultTime        => '2 hours',                     # 1:00 + 1h offset = 2:00 => but now is DST => 3:00 to 5:00 (3:00 + 2h offset) = 2h
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampUTCStart => '2023-03-26 00:30:00',
        TimeStampUTCStop  => '2023-03-26 03:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 2 + 60 * 30,
        ResultTime        => '2 hours 30 minutes',          # 0:30 + 1h offset = 1:30 to 5:00 = 3:30 - 1h DST = 2h 30m
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampUTCStart => '2023-03-26 02:00:00',
        TimeStampUTCStop  => '2023-03-26 03:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60,
        ResultTime        => '1 hour',                      # 2:00 (DST is now) + 2h offset = 4:00 to 5:00 = 1h
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (24/7 - DST)',
        TimeStampUTCStart => '2023-03-26 02:30:00',
        TimeStampUTCStop  => '2023-03-26 03:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 30,
        ResultTime        => '30 minutes',                  # 2:30 + 2h offset = 4:30 to 5:00 = 30m
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
        Mon => '06:00-18:00',
        Tue => '06:00-18:00',
        Wed => '06:00-18:00',
        Thu => '06:00-18:00',
        Fri => '06:00-18:00',
        Sat => '06:00-18:00',
        Sun => '06:00-18:00'
    }
);
$CacheObject->CleanUp();

@Tests = (
    {
        Name              => 'Server: UTC ## Calendar: UTC (8-16)',
        TimeStampUTCStart => '2023-03-06 12:00:00',
        TimeStampUTCStop  => '2023-03-07 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'UTC',
        Result            => 60 * 60 * 8,
        ResultTime        => '8 hours',              # 12:00 (start) to 16:00 (end of day) = 4h => 8:00 (next day) to 12:00 (stop) = 4h => used time: 8h (4+4)
    },
    {
        Name              => 'Server: UTC ## no calendar (8-16)',
        TimeStampUTCStart => '2023-03-06 12:00:00',
        TimeStampUTCStop  => '2023-03-07 12:00:00',
        ServerTZ          => 'UTC',
        NoCalendar        => 1,
        Result            => 60 * 60 * 12,
        ResultTime        => '12 hours',              # 12:00 (start) to 18:00 (end of day) = 6h => 6:00 (next day) to 12:00 (stop) = 6h => used time: 12h (6+6)
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (8-16)',
        TimeStampUTCStart => '2023-03-06 12:00:00',
        TimeStampUTCStop  => '2023-03-07 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 8,
        ResultTime        => '8 hours',             # 12:00 + 1h (calendar offset) => 13:00 to 16:00 = 3h => 8:00 to 13:00 (12:00 + 1h calendar offset) = 5h => 8h (3+5)
    },
    {
        Name              => 'Server: UTC ## Calendar: America/New_York (8-16)',
        TimeStampUTCStart => '2023-03-06 12:00:00',
        TimeStampUTCStop  => '2023-03-07 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'America/New_York',
        Result            => 60 * 60 * 8,
        ResultTime        => '8 hours',            # 12:00 - 5h => 7:00 (out of working time) => 8:00 to 16:00 = 8h => 12:00 (stop) - 5h => 7:00 (out of working time) => 8h
    },
    {
        Name              => 'Server: UTC ## Calendar: America/New_York (8-16)',
        TimeStampUTCStart => '2023-03-06 12:00:00',
        TimeStampUTCStop  => '2023-03-07 14:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'America/New_York',
        Result            => 60 * 60 * 9,
        ResultTime        => '9 hours',            # 12:00 - 5h => 7:00 (out of working time) => 8:00 to 16:00 = 8h => 14:00 (stop) - 5h => 9:00 => 8:00 to 9:00 = 1h => 9h (8+1)
    },
    # DST: 1h => 2h
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (8-16 - DST)',
        TimeStampUTCStart => '2023-03-25 12:00:00',
        TimeStampUTCStop  => '2023-03-26 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 9,
        ResultTime        => '9 hours',            # 12:00 + 1h (calendar offset) => 13:00 to 16:00 = 3h => 8:00 to 14:00 (12:00 +1h offset + 1h DST) = 6h => 9h (3+6)
    },
    # DST: -5h => -4h
    {
        Name              => 'Server: UTC ## Calendar: America/New_York (8-16 - DST)',
        TimeStampUTCStart => '2023-03-11 12:00:00',
        TimeStampUTCStop  => '2023-03-12 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'America/New_York',
        Result            => 60 * 60 * 8,
        ResultTime        => '8 hours',            # 12:00 - 5h => 7:00 (out of working time) => 8:00 to 16:00 = 8h => 12:00 (stop) - 4h => 8:00 (also beginn, so no time span) => 8h
    },
    {
        Name              => 'Server: UTC ## Calendar: America/New_York (8-16)',
        TimeStampUTCStart => '2023-03-06 12:00:00',
        TimeStampUTCStop  => '2023-03-07 14:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'America/New_York',
        Result            => 60 * 60 * 9,
        ResultTime        => '9 hours',            # 12:00 - 5h => 7:00 (out of working time) => 8:00 to 16:00 = 8h => 14:00 (stop) - 4h => 10:00 => 8:00 to 10:00 = 2h - 1h DST = 1h => 9h (8+1)
    },
    # DST: 2h => 1h
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (8-16 - DST)',
        TimeStampUTCStart => '2023-10-28 12:00:00',
        TimeStampUTCStop  => '2023-10-29 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 7,
        ResultTime        => '7 hours',           # 12:00 + 2h => 14:00 to 16:00 = 2h => 8:00 to 13:00 (12:00 + 2h offset - 1h DST) = 5h => 7h
    },
    # DST: -4h => -5h
    {
        Name              => 'Server: UTC ## Calendar: America/New_York (8-16 - DST)',
        TimeStampUTCStart => '2023-11-04 12:00:00',
        TimeStampUTCStop  => '2023-11-05 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'America/New_York',
        Result            => 60 * 60 * 8,
        ResultTime        => '8 hours',          # 12:00 - 4h => 8:00 to 16:00 = 8h => 12:00 (stop) - 4h - 1h DST = 7:00 (out of working day) = 0h => 8h
    },
    # DST: 1h => 2h => 1h
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (8-16 - DST)',
        TimeStampUTCStart => '2023-03-25 12:00:00',
        TimeStampUTCStop  => '2023-10-29 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 8 * 218,              # 218 days with 8h working time each
        ResultTime        => '218 days with 8h',             # 12:00 + 1h = 13:00 to 16:00 = 3h => 217 * 8h => 8:00 to 13:00 (12:00 + 1h) = 5h => 3+217*8+5 = 1736h
    },
    # DST: -5 => -4h => -5h
    {
        Name              => 'Server: UTC ## Calendar: America/New_York (8-16 - DST)',
        TimeStampUTCStart => '2023-03-11 12:00:00',
        TimeStampUTCStop  => '2023-11-05 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'America/New_York',
        Result            => 60 * 60 * 8 * 239,              # 239 days with 8h working time each
        ResultTime        => '239 days with 8h',
    },
    # DST: 1h => 2h => 1h => 2h
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (8-16 - DST)',
        TimeStampUTCStart => '2023-03-25 12:00:00',
        TimeStampUTCStop  => '2024-03-31 12:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60*60*8*371 + 60*60*9,        # 371*8h + 9h (see test "DST: 1h => 2h")
        ResultTime        => '371 days with 8h and 9h',    # 12:00 + 1h = 13:00 to 16:00 = 3h => 371 * 8h => 8:00 to 14:00 (12:00 + 2h offset) = 6h => 3+371*8+6 = 2977h
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
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampUTCStart => '2023-03-25 22:00:00',
        TimeStampUTCStop  => '2023-03-26 04:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 6,
        ResultTime        => '6 hours',              # 22:00 => 23:00 to 24:00 = 1h => 0:00 to 6:00 (4:00 + 2h offset) = 6h - 1h DST = 5h => 1+5 = 6h
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampUTCStart => '2023-03-26 01:00:00',
        TimeStampUTCStop  => '2023-03-26 04:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 3,
        ResultTime        => '3 hours',              # 01:00 +1h offset = 02:00 => 03:00 to 6:00 (4:00 + 2h offset) = 3h (no DST because 2:00 (3:00) and 6:00 have same offset)
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampUTCStart => '2023-03-26 01:30:00',
        TimeStampUTCStop  => '2023-03-26 04:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 2 + 60 * 30,
        ResultTime        => '2 hours 30 minutes',   # 01:00 +1h offset = 02:30 => 03:30 to 6:00 (4:00 + 2h offset) = 2h 30m
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampUTCStart => '2023-03-26 02:00:00',
        TimeStampUTCStop  => '2023-03-26 04:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 2,
        ResultTime        => '2 hours',              # 02:00 +2h offset = 04:00 to 6:00 (4:00 + 2h offset) = 2h
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampUTCStart => '2023-03-26 02:30:00',
        TimeStampUTCStop  => '2023-03-26 04:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 + 60 * 30,
        ResultTime        => '1 hour 30 minutes',    # 02:30 +2h offset = 04:30 to 6:00 (4:00 + 2h offset) = 1h 30m
    },
    # 2h => 1h
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampUTCStart => '2023-10-28 23:00:00',
        TimeStampUTCStop  => '2023-10-29 04:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 5,
        ResultTime        => '5 hours',    # 23:00 +2h offset = 01:00 to 5:00 (4:00 + 1h offset) = 4h + 1h DST = 5h
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampUTCStart => '2023-10-28 23:59:59',
        TimeStampUTCStop  => '2023-10-29 04:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 4 + 1,
        ResultTime        => '4 hours 1 second',    # 23:59:59 +2h offset = 01:59:59 to 5:00 (4:00 + 1h offset) = 3h 1s + 1h DST = 4h 1s
    },
    {
        Name              => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
        TimeStampUTCStart => '2023-10-29 00:01:00',
        TimeStampUTCStop  => '2023-10-29 04:00:00',
        ServerTZ          => 'UTC',
        CalendarTZ        => 'Europe/Berlin',
        Result            => 60 * 60 * 2 + 60 * 59,
        ResultTime        => '2 hours 59 minutes',    # 00:01 +2h offset = 02:01 to 5:00 (4:00 + 1h offset) = 2h 59m
    },
    # {
    #     Name              => 'Server: UTC ## Calendar: Europe/Berlin (explicit DST)',
    #     TimeStampUTCStart => '2023-10-29 00:00:00',
    #     TimeStampUTCStop  => '2023-10-29 04:00:00',
    #     ServerTZ          => 'UTC',
    #     CalendarTZ        => 'Europe/Berlin',
    #     Result            => 60 * 60 * 4,
    #     ResultTime        => '4 hours',    # 0:00 +2h offset = 02:00 to 5:00 (4:00 + 1h offset) = 3h + 1h DST = 4h
    # },
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

        # Convert UTC timestamp to system time and set it.
        $Test->{TimeStampUTCStart} =~ m/(\d{4})-(\d{1,2})-(\d{1,2})\s(\d{1,2}):(\d{1,2}):(\d{1,2})/;

        my $FixedTimeStart = Time::Local::timegm(
            $6, $5, $4, $3, ( $2 - 1 ), $1
        );

        $HelperObject->FixedTimeSet(
            $FixedTimeStart,
        );

        # Convert UTC timestamp to system time and set it.
        $Test->{TimeStampUTCStop} =~ m/(\d{4})-(\d{1,2})-(\d{1,2})\s(\d{1,2}):(\d{1,2}):(\d{1,2})/;

        my $FixedTimeStop = Time::Local::timegm(
            $6, $5, $4, $3, ( $2 - 1 ), $1
        );

        my $StopTime = $TimeObject->SystemTime();
        my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WDay ) = localtime $FixedTimeStop;
        $Year  += 1900;
        $Month += 1;
        my $Stop = sprintf("%04i-%02i-%02i %02i:%02i:%02i", $Year, $Month, $Day, $Hour, $Min, $Sec);
        ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WDay ) = localtime $FixedTimeStart;
        $Year  += 1900;
        $Month += 1;
        my $Start = sprintf("%04i-%02i-%02i %02i:%02i:%02i", $Year, $Month, $Day, $Hour, $Min, $Sec);

        my $WorkingTime = $TimeObject->WorkingTime(
            StartTime => $FixedTimeStart,
            StopTime  => $FixedTimeStop,
            Calendar  => $Test->{NoCalendar} ? undef : 1,
            Debug     => 1
        );

        $Self->Is(
            $WorkingTime,
            $Test->{Result},
            "$Test->{Name} :: working time from $Start to $Stop ($Test->{ResultTime} >> ".($Test->{Result})."s)",
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
