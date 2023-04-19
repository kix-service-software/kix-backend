# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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
use DateTime;
use DateTime::TimeZone;

use vars (qw($Self));

# get needed objects
## IMPORTANT - First get time object,
## or it will not use the same config object as the test somehow
my $TimeObject   = $Kernel::OM->Get('Time');
my $ConfigObject = $Kernel::OM->Get('Config');

my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# set time zone to get correct references
$ENV{TZ} = 'Europe/Berlin';

$ConfigObject->Set(
    Key   => 'TimeZone::Calendar9',
    Value => 'Atlantic/Azores',
);

# get DaylightSaving
my $TimeZoneObject = DateTime::TimeZone->new(
    name => $ConfigObject->Get( 'TimeZone::Calendar9' )
);
my $Calendar9_DST = $TimeZoneObject->is_dst_for_datetime(DateTime->now);

$ConfigObject->Set(
    Key   => 'TimeZone::Calendar8',
    Value => 'Europe/Berlin',
);

$TimeZoneObject = DateTime::TimeZone->new(
    name => $ConfigObject->Get( 'TimeZone::Calendar8' )
);
my $Calendar8_DST = $TimeZoneObject->is_dst_for_datetime(DateTime->now);

my $SystemTime = $TimeObject->TimeStamp2SystemTime( String => '2005-10-20T10:00:00Z' );
$Self->Is(
    $SystemTime,
    1129795200,
    'TimeStamp2SystemTime()',
);

$SystemTime = $TimeObject->TimeStamp2SystemTime( String => '2005-10-20T10:00:00+00:00' );
$Self->Is(
    $SystemTime,
    1129795200,
    'TimeStamp2SystemTime()',
);

$SystemTime = $TimeObject->TimeStamp2SystemTime( String => '20-10-2005 10:00:00' );
$Self->Is(
    $SystemTime,
    1129795200,
    'TimeStamp2SystemTime()',
);

$SystemTime = $TimeObject->TimeStamp2SystemTime( String => '2005-10-20 10:00:00' );
$Self->Is(
    $SystemTime,
    1129795200,
    'TimeStamp2SystemTime()',
);

my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) =
    $TimeObject->SystemTime2Date( SystemTime => $SystemTime );
$Self->Is(
    "$Year-$Month-$Day $Hour:$Min:$Sec",
    '2005-10-20 10:00:00',
    'SystemTime2Date()',
);

my $SystemTimeUnix = $TimeObject->Date2SystemTime(
    Year   => 2005,
    Month  => 10,
    Day    => 20,
    Hour   => 10,
    Minute => 0,
    Second => 0,
);
$Self->Is(
    $SystemTime,
    $SystemTimeUnix,
    'Date2SystemTime()',
);

my $SystemTime2  = $TimeObject->TimeStamp2SystemTime( String => '2005-10-21 10:00:00' );
my $SystemTime3  = $TimeObject->TimeStamp2SystemTime( String => '2005-10-24 10:00:00' );
my $SystemTime4  = $TimeObject->TimeStamp2SystemTime( String => '2005-10-27 10:00:00' );
my $SystemTime5  = $TimeObject->TimeStamp2SystemTime( String => '2005-11-03 10:00:00' );
my $SystemTime6  = $TimeObject->TimeStamp2SystemTime( String => '2005-12-21 10:00:00' );
my $SystemTime7  = $TimeObject->TimeStamp2SystemTime( String => '2005-12-31 10:00:00' );
my $SystemTime8  = $TimeObject->TimeStamp2SystemTime( String => '2003-12-21 10:00:00' );
my $SystemTime9  = $TimeObject->TimeStamp2SystemTime( String => '2003-12-31 10:00:00' );
my $SystemTime10 = $TimeObject->TimeStamp2SystemTime( String => '2005-10-23 10:00:00' );
my $SystemTime11 = $TimeObject->TimeStamp2SystemTime( String => '2005-10-24 10:00:00' );
my $SystemTime12 = $TimeObject->TimeStamp2SystemTime( String => '2005-10-23 10:00:00' );
my $SystemTime13 = $TimeObject->TimeStamp2SystemTime( String => '2005-10-25 13:00:00' );
my $SystemTime14 = $TimeObject->TimeStamp2SystemTime( String => '2005-10-23 10:00:00' );
my $SystemTime15 = $TimeObject->TimeStamp2SystemTime( String => '2005-10-30 13:00:00' );
my $SystemTime16 = $TimeObject->TimeStamp2SystemTime( String => '2005-10-24 11:44:12' );
my $SystemTime17 = $TimeObject->TimeStamp2SystemTime( String => '2005-10-24 16:13:31' );
my $SystemTime18 = $TimeObject->TimeStamp2SystemTime( String => '2006-12-05 22:57:34' );
my $SystemTime19 = $TimeObject->TimeStamp2SystemTime( String => '2006-12-06 10:25:34' );
my $SystemTime20 = $TimeObject->TimeStamp2SystemTime( String => '2006-12-06 07:50:00' );
my $SystemTime21 = $TimeObject->TimeStamp2SystemTime( String => '2006-12-07 08:54:00' );
my $SystemTime22 = $TimeObject->TimeStamp2SystemTime( String => '2007-03-12 11:56:01' );
my $SystemTime23 = $TimeObject->TimeStamp2SystemTime( String => '2007-03-12 13:56:01' );
my $SystemTime24 = $TimeObject->TimeStamp2SystemTime( String => '2010-01-28 22:00:02' );
my $SystemTime25 = $TimeObject->TimeStamp2SystemTime( String => '2010-01-28 22:01:02' );
my $WorkingTime  = $TimeObject->WorkingTime(
    StartTime => $SystemTime,
    StopTime  => $SystemTime2,
);
my $WorkingTime2 = $TimeObject->WorkingTime(
    StartTime => $SystemTime,
    StopTime  => $SystemTime3,
);
my $WorkingTime3 = $TimeObject->WorkingTime(
    StartTime => $SystemTime,
    StopTime  => $SystemTime4,
);
my $WorkingTime4 = $TimeObject->WorkingTime(
    StartTime => $SystemTime,
    StopTime  => $SystemTime5,
);
my $WorkingTime5 = $TimeObject->WorkingTime(
    StartTime => $SystemTime6,
    StopTime  => $SystemTime7,
);
my $WorkingTime6 = $TimeObject->WorkingTime(
    StartTime => $SystemTime8,
    StopTime  => $SystemTime9,
);
my $WorkingTime7 = $TimeObject->WorkingTime(
    StartTime => $SystemTime10,
    StopTime  => $SystemTime11,
);
my $WorkingTime8 = $TimeObject->WorkingTime(
    StartTime => $SystemTime12,
    StopTime  => $SystemTime13,
);
my $WorkingTime9 = $TimeObject->WorkingTime(
    StartTime => $SystemTime14,
    StopTime  => $SystemTime15,
);
my $WorkingTime10 = $TimeObject->WorkingTime(
    StartTime => $SystemTime16,
    StopTime  => $SystemTime17,
);
my $WorkingTime11 = $TimeObject->WorkingTime(
    StartTime => $SystemTime18,
    StopTime  => $SystemTime19,
);
my $WorkingTime12 = $TimeObject->WorkingTime(
    StartTime => $SystemTime20,
    StopTime  => $SystemTime21,
);
my $WorkingTime13 = $TimeObject->WorkingTime(
    StartTime => $SystemTime22,
    StopTime  => $SystemTime23,
);
my $WorkingTime14 = $TimeObject->WorkingTime(
    StartTime => $SystemTime24,
    StopTime  => $SystemTime25,
);

$Self->Is(
    $WorkingTime / 60 / 60,
    13,
    'WorkingHours - Thu-Fri',
);

$Self->Is(
    $WorkingTime2 / 60 / 60,
    26,
    'WorkingHours - Thu-Mon',
);

$Self->Is(
    $WorkingTime3 / 60 / 60,
    65,
    'WorkingHours - Thu-Thu',
);

$Self->Is(
    $WorkingTime4 / 60 / 60,
    130,
    'WorkingHours - Thu-Thu-Thu',
);

$Self->Is(
    $WorkingTime5 / 60 / 60,
    89,
    'WorkingHours - Fri-Fri-Mon',
);

$Self->Is(
    $WorkingTime6 / 60 / 60,
    52,
    'WorkingHours - The-The-Fr',
);

$Self->Is(
    $WorkingTime7 / 60 / 60,
    2,
    'WorkingHours - Sun-Mon',
);

$Self->Is(
    $WorkingTime8 / 60 / 60,
    18,
    'WorkingHours - Son-The',
);

$Self->Is(
    $WorkingTime9 / 60 / 60,
    65,
    'WorkingHours - Son-Son',
);

$Self->Is(
    $WorkingTime10 / 60 / 60,
    4.48861111111111,    # 16:13:31 - 11:44:12 => 4:29:19 = 4.4886...
    'WorkingHours - Mon-Mon',
);
$Self->Is(
    $WorkingTime11 / 60 / 60,
    2.42611111111111,    # 1 10:25:23 - 22:57:35 => 2:25:34 = 2,426...
    'WorkingHours - Thu-Wed',
);
$Self->Is(
    $WorkingTime12 / 60 / 60,
    13.9,
    'WorkingHours - Thu-Wed',
);
$Self->Is(
    $WorkingTime13 / 60 / 60,
    2,
    'WorkingHours - Mon-Mon',
);
$Self->Is(
    $WorkingTime14,
    0,
    'WorkingHours - Mon-Mon',
);

# DestinationTime tests
my @DestinationTime = (
    {
        Name            => 'Test 1',
        StartTime       => '2006-11-12 10:15:00',
        StartTimeSystem => '',
        Diff            => 60 * 60 * 4,
        EndTime         => '2006-11-13 12:00:00',
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test 2',
        StartTime       => '2006-11-13 10:15:00',
        StartTimeSystem => '',
        Diff            => 60 * 60 * 4,
        EndTime         => '2006-11-13 14:15:00',
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test 3',
        StartTime       => '2006-11-13 10:15:00',
        StartTimeSystem => '',
        Diff            => 60 * 60 * 11,
        EndTime         => '2006-11-14 08:15:00',
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test 4',
        StartTime       => '2006-12-31 10:15:00',
        StartTimeSystem => '',
        Diff            => 60 * 60 * 11,
        EndTime         => '2007-01-02 19:00:00',
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test 5',
        StartTime       => '2006-12-29 10:15:00',
        StartTimeSystem => '',
        Diff            => 60 * 60 * 11,
        EndTime         => '2007-01-02 08:15:00',
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test 6',
        StartTime       => '2006-12-30 10:45:00',
        StartTimeSystem => '',
        Diff            => 60 * 60 * 11,
        EndTime         => '2007-01-02 19:00:00',
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test 7',
        StartTime       => '2006-12-06 07:50:00',
        StartTimeSystem => '',
        Diff            => $WorkingTime12,
        EndTime         => '2006-12-07 08:54:00',
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test 8',
        StartTime       => '2007-01-16 20:15:00',
        StartTimeSystem => '',
        Diff            => 60 * 60 * 1.25,
        EndTime         => '2007-01-17 08:30:00',
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test 9',
        StartTime       => '2007-03-14 21:21:02',
        StartTimeSystem => '',
        Diff            => 60 * 60,
        EndTime         => '2007-03-15 09:00:00',
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test 10',
        StartTime       => '2007-03-12 11:56:01',
        StartTimeSystem => '',
        Diff            => 60 * 60 * 2,
        EndTime         => '2007-03-12 13:56:01',
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test 11',
        StartTime       => '2007-03-15 17:21:27',
        StartTimeSystem => '',
        Diff            => 60 * 60 * 3,
        EndTime         => '2007-03-15 20:21:27',
        EndTimeSystem   => '',
    },

    # Summertime test - switch back to winter time (without + 60 minutes)
    {
        Name            => 'Test summertime -> wintertime (prepare without +60 min)',
        StartTime       => '2007-10-19 18:12:23',
        StartTimeSystem => 1192810343,
        Diff            => 60 * 60 * 5.5,
        EndTime         => '2007-10-22 10:42:23',
        EndTimeSystem   => 1193042543,
    },

    # Summertime test - switch back to winter time (+ 60 minutes)
    {
        Name            => 'Test summertime -> wintertime (+60 min)',
        StartTime       => '2007-10-26 18:12:23',
        StartTimeSystem => '1193415143',
        Diff            => 60 * 60 * 5.5,
        EndTime         => '2007-10-29 10:42:23',
        EndTimeSystem   => 1193650943,
    },

    # Summertime test - switch back to winter time (without + 60 minutes)
    {
        Name            => 'Test summertime -> wintertime (prepare without +60 min)',
        StartTime       => '2007-10-19 18:12:23',
        StartTimeSystem => 1192810343,
        Diff            => 60 * 60 * 18.5,
        EndTime         => '2007-10-23 10:42:23',
        EndTimeSystem   => 1193128943,
    },

    # Summertime test - switch back to winter time (+ 60 minutes)
    {
        Name            => 'Test summertime -> wintertime (+60 min)',
        StartTime       => '2007-10-26 18:12:23',
        StartTimeSystem => '1193415143',
        Diff            => 60 * 60 * 18.5,
        EndTime         => '2007-10-30 10:42:23',
        EndTimeSystem   => 1193737343,
    },

    # Wintertime test - switch to summer time (without - 60 minutes)
    {
        Name            => 'Test wintertime -> summertime (prepare without -60 min)',
        StartTime       => '2007-03-16 18:12:23',
        StartTimeSystem => '1174065143',
        Diff            => 60 * 60 * 5.5,
        EndTime         => '2007-03-19 10:42:23',
        EndTimeSystem   => 1174297343,
    },

    # Wintertime test - switch to summer time (- 60 minutes)
    {
        Name            => 'Test wintertime -> summertime (-60 min)',
        StartTime       => '2007-03-23 18:12:23',
        StartTimeSystem => 1174669943,
        Diff            => 60 * 60 * 5.5,
        EndTime         => '2007-03-26 10:42:23',
        EndTimeSystem   => 1174898543,
    },

    # Wintertime test - switch to summer time (without - 60 minutes)
    {
        Name            => 'Test wintertime -> summertime (prepare without -60 min)',
        StartTime       => '2007-03-16 18:12:23',
        StartTimeSystem => 1174065143,
        Diff            => 60 * 60 * 18.5,
        EndTime         => '2007-03-20 10:42:23',
        EndTimeSystem   => 1174383743,
    },

    # Wintertime test - switch to summer time (- 60 minutes)
    {
        Name            => 'Test wintertime -> summertime (-60 min)',
        StartTime       => '2007-03-23 18:12:23',
        StartTimeSystem => 1174669943,
        Diff            => 60 * 60 * 18.5,
        EndTime         => '2007-03-27 10:42:23',
        EndTimeSystem   => 1174984943,
    },

    # Behavior tests
    {
        Name            => 'Test weekend',
        StartTime       => '2013-03-16 10:00:00',    # Saturday
        StartTimeSystem => '',
        Diff            => 60 * 1,
        EndTime         => '2013-03-18 08:01:00',    # Monday
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test weekend -1',
        StartTime       => '2013-03-16 10:00:00',    # Saturday
        Calendar        => 9,
        StartTimeSystem => '',
        Diff            => 60 * 1,
        EndTime         => $Calendar9_DST ? '2013-03-18 08:01:00' : '2013-03-18 09:01:00',    # Monday
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test weekend +1',
        StartTime       => '2013-03-16 10:00:00',    # Saturday
        Calendar        => 8,
        StartTimeSystem => '',
        Diff            => 60 * 1,
        EndTime         => $Calendar8_DST ? '2013-03-18 06:01:00' : '2013-03-18 07:01:00',    # Monday
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test weekend',
        StartTime       => '2013-03-16 10:00:00',    # Saturday
        StartTimeSystem => '',
        Diff            => 60 * 60 * 1,
        EndTime         => '2013-03-18 09:00:00',    # Monday
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test weekend',
        StartTime       => '2013-03-16 10:00:00',    # Saturday
        StartTimeSystem => '',
        Diff            => 60 * 60 * 13,
        EndTime         => '2013-03-18 21:00:00',    # Monday
        EndTimeSystem   => '',
    },
    {
        Name            => 'Test weekend',
        StartTime       => '2013-03-16 10:00:00',    # Saturday
        StartTimeSystem => '',
        Diff            => 60 * 60 * 14 + 60 * 1,
        EndTime         => '2013-03-19 09:01:00',    # Monday
        EndTimeSystem   => '',
    },
);

# DestinationTime test
for my $Test (@DestinationTime) {

    # get system time
    my $SystemTimeDestination = $TimeObject->TimeStamp2SystemTime( String => $Test->{StartTime} );

    # check system time
    if ( $Test->{StartTimeSystem} ) {
        $Self->Is(
            $SystemTimeDestination,
            $Test->{StartTimeSystem},
            "TimeStamp2SystemTime() - $Test->{Name}",
        );
    }

    # get system destination time based on calendar settings
    my $DestinationTime = $TimeObject->DestinationTime(
        StartTime => $SystemTimeDestination,
        Time      => $Test->{Diff},
        Calendar  => $Test->{Calendar},
    );

    # check system destination time
    if ( $Test->{EndTimeSystem} ) {
        $Self->Is(
            $DestinationTime,
            $Test->{EndTimeSystem},
            "DestinationTime() - $Test->{Name}",
        );
    }

    # check time stamp destination time
    my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) =
        $TimeObject->SystemTime2Date( SystemTime => $DestinationTime );
    $Self->Is(
        "$Year-$Month-$Day $Hour:$Min:$Sec",
        $Test->{EndTime},
        "DestinationTime() - $Test->{Name}",
    );
}

# WorkingTime/DestinationTime roundtrip test (random)
my @WorkingTimeDestinationTimeRoundtrip = (
    {
        Name       => 'Test 1',
        BaseDate   => '2013-12-26 15:15:00',
        DaysBefore => 8,
        DaysAfter  => 12,
        Runs       => 80,
        Calendar   => '',
        MaxDiff    => 4 * 24 * 60 * 60,
    },
    {
        Name       => 'Test 2',
        BaseDate   => '2013-10-24 04:41:17',
        DaysBefore => 3,
        DaysAfter  => 12,
        Runs       => 40,
        Calendar   => '',
        MaxDiff    => 3 * 24 * 60 * 60,
    },
    {
        Name       => 'Test 3',
        BaseDate   => '2013-03-01 10:11:12',
        DaysBefore => 5,
        DaysAfter  => 180,
        Runs       => 40,
        Calendar   => 7,                       # 24/7
        MaxDiff    => 0,
    },
);

# modify calendar 7 -- 24/7
my $WorkingHoursFull = [ '0' .. '23' ];
$ConfigObject->Set(
    Key   => 'TimeWorkingHours::Calendar7',
    Value => {
        map { $_ => $WorkingHoursFull, } qw( Mon Tue Wed Thu Fri Sat Sun ),
    },
);

for my $Test (@WorkingTimeDestinationTimeRoundtrip) {
    my $BaseDate   = $Test->{BaseDate};
    my $BaseTime   = $TimeObject->TimeStamp2SystemTime( String => $BaseDate );
    my $DaysBefore = $Test->{DaysBefore};
    my $DaysAfter  = $Test->{DaysAfter};
    for my $Run ( 1 .. 40 ) {

        # Use random start/stop dates around base date
        my $StartTime = $BaseTime - int( rand( $DaysBefore * 24 * 60 * 60 ) );
        my $StartDate = $TimeObject->SystemTime2TimeStamp( SystemTime => $StartTime );
        my $StopTime  = $BaseTime + int( rand( $DaysAfter * 24 * 60 * 60 ) );
        my $StopDate  = $TimeObject->SystemTime2TimeStamp( SystemTime => $StopTime );

        my $WorkingTime = $TimeObject->WorkingTime(
            StartTime => $StartTime,
            StopTime  => $StopTime,
            Calendar  => $Test->{Calendar},
        );
        my $DestinationTime = $TimeObject->DestinationTime(
            StartTime => $StartTime,
            Time      => $WorkingTime,
            Calendar  => $Test->{Calendar},
        );
        my $WorkingTime2 = $TimeObject->WorkingTime(    # re-check
            StartTime => $StartTime,
            StopTime  => $DestinationTime,
            Calendar  => $Test->{Calendar},
        );
        my $DestinationDate = $TimeObject->SystemTime2TimeStamp( SystemTime => $DestinationTime );
        my $WH              = int( $WorkingTime / 3600 );
        my $WM              = int( ( $WorkingTime - $WH * 3600 ) / 60 );
        my $WS              = $WorkingTime - $WH * 3600 - $WM * 60;
        my $WT              = sprintf( "%u:%02u:%02u", $WH, $WM, $WS );

        my $Ok = $DestinationTime >= $StopTime - $Test->{MaxDiff}    # within MaxDiff of StopDate...
            && $DestinationTime <= $StopTime                         # ...but not later
            && $WorkingTime == $WorkingTime2;

        $Self->Is(
            $Ok,
            1,
            "WorkingTime/DestinationTime roundtrip $Test->{Name}.$Run -- $StartDate .. $DestinationDate <= $StopDate ($WT)",
        );

        if ( !$Ok ) {
            print "\tStart: $StartTime / $StartDate\n";
            print "\tStop:  $StopTime / $StopDate\n";
            print "\tDest:  $DestinationTime / $DestinationDate\n";
            print "\tWork:  $WT = $WorkingTime"
                . ( $WorkingTime != $WorkingTime2 ? " --> $WorkingTime2" : "" ) . "\n";
        }
    }
}

my @VacationDays = (
    {
        Name        => 'VacationCheck - Base calendar - 2005-01-01',
        Year        => '2005',
        Month       => '1',
        Day         => '1',
        Calendar    => '',
        VacationDay => 'New Year\'s Day',
    },
    {
        Name        => 'VacationCheck - Base calendar - 2005-01-01 - Leading zeros',
        Year        => '2005',
        Month       => '01',
        Day         => '01',
        Calendar    => '',
        VacationDay => 'New Year\'s Day',
    },
    {
        Name        => 'VacationCheck - Base calendar - 2005-12-31',
        Year        => '2005',
        Month       => '12',
        Day         => '31',
        Calendar    => '',
        VacationDay => 'New Year\'s Eve',
    },
    {
        Name        => 'VacationCheck - Base calendar - Easter Monday 2005',
        Year        => '2005',
        Month       => '3',
        Day         => '28',
        Calendar    => '',
        VacationDay => 'Easter Monday',
    },
    {
        Name        => 'VacationCheck - Base calendar - Ascension Day 2005',
        Year        => '2005',
        Month       => '5',
        Day         => '5',
        Calendar    => '',
        VacationDay => 'Ascension Day',
    },
    {
        Name        => 'VacationCheck - Base calendar - Whit Monday 2005',
        Year        => '2005',
        Month       => '5',
        Day         => '16',
        Calendar    => '',
        VacationDay => 'Whit Monday',
    },
    {
        Name        => 'VacationCheck - Base calendar - Easter Monday 2023',
        Year        => '2023',
        Month       => '4',
        Day         => '10',
        Calendar    => '',
        VacationDay => 'Easter Monday',
    },
    {
        Name        => 'VacationCheck - Base calendar - Ascension Day 2023',
        Year        => '2023',
        Month       => '5',
        Day         => '18',
        Calendar    => '',
        VacationDay => 'Ascension Day',
    },
    {
        Name        => 'VacationCheck - Base calendar - Whit Monday 2023',
        Year        => '2023',
        Month       => '5',
        Day         => '29',
        Calendar    => '',
        VacationDay => 'Whit Monday',
    },
    {
        Name        => 'VacationCheck - Base calendar - Easter Monday 2024',
        Year        => '2024',
        Month       => '4',
        Day         => '1',
        Calendar    => '',
        VacationDay => 'Easter Monday',
    },
    {
        Name        => 'VacationCheck - Base calendar - Ascension Day 2024',
        Year        => '2024',
        Month       => '5',
        Day         => '9',
        Calendar    => '',
        VacationDay => 'Ascension Day',
    },
    {
        Name        => 'VacationCheck - Base calendar - Whit Monday 2024',
        Year        => '2024',
        Month       => '5',
        Day         => '20',
        Calendar    => '',
        VacationDay => 'Whit Monday',
    },
    {
        Name        => 'VacationCheck - Base calendar - Easter Monday 2030',
        Year        => '2030',
        Month       => '4',
        Day         => '22',
        Calendar    => '',
        VacationDay => 'Easter Monday',
    },
    {
        Name        => 'VacationCheck - Base calendar - Ascension Day 2030',
        Year        => '2030',
        Month       => '5',
        Day         => '30',
        Calendar    => '',
        VacationDay => 'Ascension Day',
    },
    {
        Name        => 'VacationCheck - Base calendar - Whit Monday 2030',
        Year        => '2030',
        Month       => '6',
        Day         => '10',
        Calendar    => '',
        VacationDay => 'Whit Monday',
    },
    {
        Name        => 'VacationCheck - Base calendar - 2005-02-14',
        Year        => '2005',
        Month       => '02',
        Day         => '14',
        Calendar    => '',
        VacationDay => 'no vacation day',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - 2005-01-01',
        Year        => '2005',
        Month       => '1',
        Day         => '1',
        Calendar    => '1',
        VacationDay => 'New Year\'s Day',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - 2005-01-01 - Leading zeros',
        Year        => '2005',
        Month       => '01',
        Day         => '01',
        Calendar    => '1',
        VacationDay => 'New Year\'s Day',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Easter Monday 2005',
        Year        => '2005',
        Month       => '3',
        Day         => '28',
        Calendar    => '1',
        VacationDay => 'Easter Monday',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Ascension Day 2005',
        Year        => '2005',
        Month       => '5',
        Day         => '5',
        Calendar    => '1',
        VacationDay => 'Ascension Day',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Whit Monday 2005',
        Year        => '2005',
        Month       => '5',
        Day         => '16',
        Calendar    => '1',
        VacationDay => 'Whit Monday',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Easter Monday 2023',
        Year        => '2023',
        Month       => '4',
        Day         => '10',
        Calendar    => '1',
        VacationDay => 'Easter Monday',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Ascension Day 2023',
        Year        => '2023',
        Month       => '5',
        Day         => '18',
        Calendar    => '1',
        VacationDay => 'Ascension Day',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Whit Monday 2023',
        Year        => '2023',
        Month       => '5',
        Day         => '29',
        Calendar    => '1',
        VacationDay => 'Whit Monday',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Easter Monday 2024',
        Year        => '2024',
        Month       => '4',
        Day         => '1',
        Calendar    => '1',
        VacationDay => 'Easter Monday',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Ascension Day 2024',
        Year        => '2024',
        Month       => '5',
        Day         => '9',
        Calendar    => '1',
        VacationDay => 'Ascension Day',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Whit Monday 2024',
        Year        => '2024',
        Month       => '5',
        Day         => '20',
        Calendar    => '1',
        VacationDay => 'Whit Monday',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Easter Monday 2030',
        Year        => '2030',
        Month       => '4',
        Day         => '22',
        Calendar    => '1',
        VacationDay => 'Easter Monday',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Ascension Day 2030',
        Year        => '2030',
        Month       => '5',
        Day         => '30',
        Calendar    => '1',
        VacationDay => 'Ascension Day',
    },
    {
        Name        => 'VacationCheck - Calendar 1 - Whit Monday 2030',
        Year        => '2030',
        Month       => '6',
        Day         => '10',
        Calendar    => '1',
        VacationDay => 'Whit Monday',
    },
);

for my $Test (@VacationDays) {
    my $Vacation = $TimeObject->VacationCheck(
        Year     => $Test->{Year},
        Month    => $Test->{Month},
        Day      => $Test->{Day},
        Calendar => $Test->{Calendar},
    );

    $Self->Is(
        $Vacation || 'no vacation day',
        $Test->{VacationDay},
        $Test->{Name},
    );
}

# disable all vacations on calendar 1
$ConfigObject->Set(
    Key   => 'TimeVacationDays::Calendar1',
    Value => undef,
);
$ConfigObject->Set(
    Key   => 'TimeVacationDaysOneTime::Calendar1',
    Value => undef,
);
$ConfigObject->Set(
    Key   => 'TimeVacationDaysModules::Calendar1',
    Value => undef,
);

for my $Test (@VacationDays) {
    my $Vacation = $TimeObject->VacationCheck(
        Year     => $Test->{Year},
        Month    => $Test->{Month},
        Day      => $Test->{Day},
        Calendar => $Test->{Calendar},
    );

    my $VacationDay;
    if ( $Test->{Calendar} eq '1' ) {
        $VacationDay = 'no vacation day';
    }
    else {
        $VacationDay = $Test->{VacationDay};
    }

    $Self->Is(
        $Vacation || 'no vacation day',
        $VacationDay,
        $Test->{Name} . ' - Calendar 1 disabled vacations',
    );
}

# UTC tests
$ENV{TZ} = 'UTC';
my @Tests = (
    {
        Name       => 'Zero Hour',
        TimeStamp  => '1970-01-01 00:00:00',
        SystemTime => 0,
    },
    {
        Name       => '+ Second',
        TimeStamp  => '1970-01-01 00:00:01',
        SystemTime => 1,
    },
    {
        Name       => '+ Hour',
        TimeStamp  => '1970-01-01 01:00:00',
        SystemTime => 3600,
    },
    {
        Name       => '- Second',
        TimeStamp  => '1969-12-31 23:59:59',
        SystemTime => -1,
    },
    {
        Name       => '- Hour',
        TimeStamp  => '1969-12-31 23:00:00',
        SystemTime => -3600,
    },
);

# the following tests implies a conversion to 'Date' in the middle, so tests for 'Date' are not
# needed
for my $Test (@Tests) {
    my $SystemTime = $TimeObject->TimeStamp2SystemTime( String => $Test->{TimeStamp} );
    $Self->Is(
        $SystemTime,
        $Test->{SystemTime},
        " $Test->{Name} TimeStamp2SystemTime()",
    );
    my $TimeStamp = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $Test->{SystemTime},
    );
    $Self->Is(
        $TimeStamp,
        $Test->{TimeStamp},
        " $Test->{Name} SystemTime2TimeStamp()",
    );
}

# calculation tests
$ENV{TZ} = 'UTC';
@Tests = (
    {
        Name       => '+1Y',
        TimeStamp  => '1970-01-01 00:00:00 +1Y',
        Result     => '1971-01-01 00:00:00',
    },
    {
        Name       => '+1M',
        TimeStamp  => '1970-01-01 00:00:00 +1M',
        Result     => '1970-02-01 00:00:00',
    },
    {
        Name       => '+1w',
        TimeStamp  => '1970-01-01 00:00:00 +1w',
        Result     => '1970-01-08 00:00:00',
    },
    {
        Name       => '+1d',
        TimeStamp  => '1970-01-01 00:00:00 +1d',
        Result     => '1970-01-02 00:00:00',
    },
    {
        Name       => '+1h',
        TimeStamp  => '1970-01-01 00:00:00 +1h',
        Result     => '1970-01-01 01:00:00',
    },
    {
        Name       => '+1m',
        TimeStamp  => '1970-01-01 00:00:00 +1m',
        Result     => '1970-01-01 00:01:00',
    },
    {
        Name       => '+1s',
        TimeStamp  => '1970-01-01 00:00:00 +1s',
        Result     => '1970-01-01 00:00:01',
    },
    {
        Name       => '-1Y',
        TimeStamp  => '1970-01-01 00:00:00 -1Y',
        Result     => '1969-01-01 00:00:00',
    },
    {
        Name       => '-1M',
        TimeStamp  => '1970-01-01 00:00:00 -1M',
        Result     => '1969-12-01 00:00:00',
    },
    {
        Name       => '-1w',
        TimeStamp  => '1970-01-01 00:00:00 -1w',
        Result     => '1969-12-25 00:00:00',
    },
    {
        Name       => '-1d',
        TimeStamp  => '1970-01-01 00:00:00 -1d',
        Result     => '1969-12-31 00:00:00',
    },
    {
        Name       => '-1h',
        TimeStamp  => '1970-01-01 00:00:00 -1h',
        Result     => '1969-12-31 23:00:00',
    },
    {
        Name       => '-1m',
        TimeStamp  => '1970-01-01 00:00:00 -1m',
        Result     => '1969-12-31 23:59:00',
    },
    {
        Name       => '-1s',
        TimeStamp  => '1970-01-01 00:00:00 -1s',
        Result     => '1969-12-31 23:59:59',
    },
    {
        Name       => 'NOW +1h',
        TimeStamp  => '+1h',
        FixedTimeSet => '1970-01-01 00:00:00',
        Result     => '1970-01-01 01:00:00',
    },
    {
        Name       => '+1Y -2M +3w -4d +5h -6m +7s',
        TimeStamp  => '1970-01-01 00:00:00 +1Y -2M +3w -4d +5h -6m +7s',
        Result     => '1970-11-18 04:54:07',
    },
    {
        Name       => '+1Y -2M +3w -4d +5h -6m +7s -1Y +2M -3w +4d -5h +6m -7s +188s',
        TimeStamp  => '1970-01-01 00:00:00 +1Y -2M +3w -4d +5h -6m +7s -1Y +2M -3w +4d -5h +6m -7s +188s',
        Result     => '1970-01-01 00:03:08',
    },
    {
        Name       => '+188',
        TimeStamp  => '1970-01-01 00:00:00 +188',
        Result     => '1970-01-01 00:03:08',
    },
    {
        Name       => '+0s',
        TimeStamp  => '+0s',
        FixedTimeSet => '2022-01-01 01:11:22',
        Result     => '2022-01-01 01:11:22',
    },
);

for my $Test (@Tests) {
    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeSet(
            $TimeObject->TimeStamp2SystemTime( String => $Test->{FixedTimeSet} ),
        );
    }

    my $SystemTime = $TimeObject->TimeStamp2SystemTime( String => $Test->{TimeStamp});
    my $Result = $TimeObject->TimeStamp2SystemTime( String => $Test->{Result} );
    $Self->Is(
        $SystemTime,
        $Result,
        " $Test->{Name} TimeStamp2SystemTime()",
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
