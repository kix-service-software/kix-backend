# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Time;

use strict;
use warnings;

use Time::Local;
use Time::Seconds;
use DateTime;
use DateTime::TimeZone;
use Date::Pcalc qw(Add_Delta_YMDHMS);

use Kernel::System::VariableCheck qw( :all );

our @ObjectDependencies = qw(
    Config
    Cache
    Log
);

=head1 NAME

Kernel::System::Time - time functions

=head1 SYNOPSIS

This module is managing time functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a time object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TimeObject = $Kernel::OM->Get('Time');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = 0;

    $Self->{TimeZone} = $Param{TimeZone}
        || $Param{UserTimeZone}
        || $Kernel::OM->Get('Config')->Get('TimeZone'); # may config is "empty" if time object is created during sysonfig object creation

    $Self->{TimeSecDiff} = 0;
    if ( $Self->{TimeZone} && lc $Self->{TimeZone} ne 'local' ) {
        my $TimeZoneObject   = DateTime::TimeZone->new(name => $Self->{TimeZone});
        $Self->{TimeSecDiff} = $TimeZoneObject->offset_for_datetime(DateTime->now);     # time zone offset in seconds
    }

    $Self->{CacheObject} = $Kernel::OM->Get('Cache');
    $Self->{CacheType}   = 'Time';

    return $Self;
}

=item SystemTime()

returns the number of non-leap seconds since what ever time the
system considers to be the epoch (that's 00:00:00, January 1, 1904
for Mac OS, and 00:00:00 UTC, January 1, 1970 for most other systems).

This will the time that the server considers to be the local time (based on
time zone configuration) plus the configured KIX "TimeZone" diff (only recommended
for systems running in UTC).

    my $SystemTime = $TimeObject->SystemTime();

=cut

sub SystemTime {
    my $Self = shift;

    return time() + $Self->{TimeSecDiff};
}

=item SystemTime2TimeStamp()

returns a time stamp for a given system time in "yyyy-mm-dd 23:59:59" format.

    my $TimeStamp = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $SystemTime,
    );

If you need the short format "23:59:59" for dates that are "today",
pass the Type parameter like this:

    my $TimeStamp = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $SystemTime,
        Type       => 'Short',
    );

=cut

sub SystemTime2TimeStamp {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{SystemTime} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need SystemTime!',
        );
        return;
    }

    my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $Self->SystemTime2Date(%Param);
    if ( $Param{Type} && $Param{Type} eq 'Short' ) {
        my ( $CSec, $CMin, $CHour, $CDay, $CMonth, $CYear ) = $Self->SystemTime2Date(
            SystemTime => $Self->SystemTime(),
        );
        if ( $CYear == $Year && $CMonth == $Month && $CDay == $Day ) {
            return "$Hour:$Min:$Sec";
        }
        return "$Year-$Month-$Day $Hour:$Min:$Sec";
    }
    return "$Year-$Month-$Day $Hour:$Min:$Sec";
}

=item CurrentTimestamp()

returns a time stamp of the local system time (see L<SystemTime()>)
in "yyyy-mm-dd 23:59:59" format.

    my $TimeStamp = $TimeObject->CurrentTimestamp();

=cut

sub CurrentTimestamp {
    my ( $Self, %Param ) = @_;

    return $Self->SystemTime2TimeStamp( SystemTime => $Self->SystemTime() );
}

=item SystemTime2Date()

converts a system time to a structured date array.

    my ($Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime(),
    );

$WeekDay is the day of the week, with 0 indicating Sunday and 3 indicating Wednesday.

=cut

sub SystemTime2Date {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !defined $Param{SystemTime} ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need SystemTime!',
        );
        return;
    }

    # get time format
    my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WDay ) = localtime $Param{SystemTime};    ## no critic
    $Year  += 1900;
    $Month += 1;
    $Month = sprintf "%02d", $Month;
    $Day   = sprintf "%02d", $Day;
    $Hour  = sprintf "%02d", $Hour;
    $Min   = sprintf "%02d", $Min;
    $Sec   = sprintf "%02d", $Sec;

    return ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WDay );
}

=item TimeStamp2SystemTime()

converts a given time stamp to local system time.

    my $SystemTime = $TimeObject->TimeStamp2SystemTime(
        String => '2004-08-14 22:45:00',
    );

simple calculations using time units can be used to calculate a relative point in time.
supported units: Y(years),M(months),w(weeks),d(days),h(hours),m(minutes),s(seconds).

    my $SystemTime = $TimeObject->TimeStamp2SystemTime(
        String => '2004-08-14 22:45:00 +1w',
    );

    my $SystemTime = $TimeObject->TimeStamp2SystemTime(
        String => '2004-08-14 22:45:00 -1w -2d +7h',
    );

if no timestamp is used in the calculation, the current system time will be used
    my $SystemTime = $TimeObject->TimeStamp2SystemTime(
        String => '+1w',
    );

if no date part is given, the current day will be used
    my $SystemTime = $TimeObject->TimeStamp2SystemTime(
        String => '22:45:00',
    );


=cut

sub TimeStamp2SystemTime {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{String} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Need String!',
            );
        }
        return;
    }

    my $SystemTime = 0;
    my $TimeStamp;

    my @Parts = split(/\s+/, $Param{String});

    if ( $Parts[0] !~ /^[+-]\d+[YMwdhms]?/ ) {
        # we have a real timestamp
        $TimeStamp = (shift @Parts);
        $TimeStamp .= (' ' . shift @Parts) if $Parts[0];
    }
    else {
        # we have to use NOW as TimeStamp
        $TimeStamp = $Self->CurrentTimestamp(
            Silent => $Param{Silent} || 0
        );
    }

    # match iso date format
    if ( $TimeStamp =~ /(\d{4})-(\d{1,2})-(\d{1,2})\s(\d{1,2}):(\d{1,2}):(\d{1,2})/ ) {
        $SystemTime = $Self->Date2SystemTime(
            Year   => $1,
            Month  => $2,
            Day    => $3,
            Hour   => $4,
            Minute => $5,
            Second => $6,
            Silent => $Param{Silent} || 0
        );
    }

    # match iso date format (wrong format)
    elsif ( $TimeStamp =~ /(\d{1,2})-(\d{1,2})-(\d{4})\s(\d{1,2}):(\d{1,2}):(\d{1,2})/ ) {
        $SystemTime = $Self->Date2SystemTime(
            Year   => $3,
            Month  => $2,
            Day    => $1,
            Hour   => $4,
            Minute => $5,
            Second => $6,
            Silent => $Param{Silent} || 0
        );
    }

    # match euro time format
    elsif ( $TimeStamp =~ /(\d{1,2})\.(\d{1,2})\.(\d{4}),?\s(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?/ ) {
        $SystemTime = $Self->Date2SystemTime(
            Year   => $3,
            Month  => $2,
            Day    => $1,
            Hour   => $4,
            Minute => $5,
            Second => $6 || '00',
            Silent => $Param{Silent} || 0
        );
    }

    # match yyyy-mm-ddThh:mm:ss+tt:zz time format
    elsif (
        $TimeStamp
        =~ /(\d{4})-(\d{1,2})-(\d{1,2})T(\d{1,2}):(\d{1,2}):(\d{1,2})(\+|\-)((\d{1,2}):(\d{1,2}))/i
    ) {
        $SystemTime = $Self->Date2SystemTime(
            Year   => $1,
            Month  => $2,
            Day    => $3,
            Hour   => $4,
            Minute => $5,
            Second => $6,
            Silent => $Param{Silent} || 0
        );
    }

    # match mail time format
    elsif (
        $TimeStamp
        =~ /((...),\s+|)(\d{1,2})\s(...)\s(\d{4})\s(\d{1,2}):(\d{1,2}):(\d{1,2})\s((\+|\-)(\d{2})(\d{2})|...)/
    ) {
        my $DiffTime = 0;
        if ( $10 && $10 eq '+' ) {

            #            $DiffTime = $DiffTime - ($11 * 60 * 60);
            #            $DiffTime = $DiffTime - ($12 * 60);
        }
        elsif ( $10 && $10 eq '-' ) {

            #            $DiffTime = $DiffTime + ($11 * 60 * 60);
            #            $DiffTime = $DiffTime + ($12 * 60);
        }
        my @MonthMap    = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
        my $Month       = 1;
        my $MonthString = $4;
        for my $MonthCount ( 0 .. $#MonthMap ) {
            if ( $MonthString =~ /$MonthMap[$MonthCount]/i ) {
                $Month = $MonthCount + 1;
            }
        }
        $SystemTime = $Self->Date2SystemTime(
            Year   => $5,
            Month  => $Month,
            Day    => $3,
            Hour   => $6,
            Minute => $7,
            Second => $8,
            Silent => $Param{Silent} || 0
        ) + $DiffTime + $Self->{TimeSecDiff};
    }
    # match yyyy-mm-ddThh:mm:ssZ
    elsif ($TimeStamp =~ /(\d{4})-(\d{1,2})-(\d{1,2})T(\d{1,2}):(\d{1,2}):(\d{1,2})Z$/) {
        $SystemTime = $Self->Date2SystemTime(
            Year   => $1,
            Month  => $2,
            Day    => $3,
            Hour   => $4,
            Minute => $5,
            Second => $6,
            Silent => $Param{Silent} || 0
        );
    }
    # match hh:mm:ss (time TODAY)
    elsif ($TimeStamp =~ /(^\d{1,2}):(\d{1,2}):(\d{1,2})$/) {
        my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $Self->SystemTime2Date(
            SystemTime => $Self->SystemTime(),
            Silent     => $Param{Silent} || 0
        );
        $SystemTime = $Self->Date2SystemTime(
            Year   => $Year,
            Month  => $Month,
            Day    => $Day,
            Hour   => $1,
            Minute => $2,
            Second => $3,
            Silent => $Param{Silent} || 0
        );
    }

    # no valid timestamp
    else {
        $SystemTime = undef;
    }

    # return error
    if ( !defined $SystemTime ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid Date '$Param{String}'!",
            );
        }
        return;
    }

    # do calculations if we have to
    if ( @Parts ) {
        my %Diffs = map { $_ => 0 } qw(Y M w d h m s);
        CALC:
        foreach my $Calc ( @Parts ) {
            if ( $Calc !~ /^([+-])(\d+)([YMwdhms])?$/ ) {
                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Invalid timestamp calculation '$Calc'!",
                    );
                }
                next CALC;
            }
            my ( $Operator, $Diff, $Unit ) = ( $1, $2, $3 );
            $Unit = 's' if !$Unit;

            eval "\$Diffs{\$Unit} = $Diffs{$Unit} $Operator $Diff";
        }

        # add the relatives to the current timestamp
        my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $Self->SystemTime2Date(
            SystemTime => $SystemTime,
            Silent     => $Param{Silent} || 0
        );
        ($Year,$Month,$Day, $Hour,$Min,$Sec) = Add_Delta_YMDHMS(
            $Year,$Month,$Day,$Hour,$Min,$Sec,
            $Diffs{Y},$Diffs{M},$Diffs{w}*7 + $Diffs{d},$Diffs{h},$Diffs{m},$Diffs{s}
        );
        $SystemTime = $Self->Date2SystemTime(
            Year   => $Year,
            Month  => $Month,
            Day    => $Day,
            Hour   => $Hour,
            Minute => $Min,
            Second => $Sec,
            Silent => $Param{Silent} || 0
        );
    }

    # return system time
    return $SystemTime;

}

=item Date2SystemTime()

converts a structured date array to local system time.

    my $SystemTime = $TimeObject->Date2SystemTime(
        Year   => 2004,
        Month  => 8,
        Day    => 14,
        Hour   => 22,
        Minute => 45,
        Second => 0,
    );

=cut

sub Date2SystemTime {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Year Month Day Hour Minute Second)) {
        if ( !defined $Param{$_} ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }
    my $SystemTime = eval {
        timelocal(
            $Param{Second}, $Param{Minute}, $Param{Hour}, $Param{Day}, ( $Param{Month} - 1 ),
            $Param{Year}
        );
    };

    if ( !defined $SystemTime ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Invalid Date '$Param{Year}-$Param{Month}-$Param{Day} $Param{Hour}:$Param{Minute}:$Param{Second}'!",
        );
        return;
    }

    return $SystemTime;
}

=item ServerLocalTimeOffsetSeconds()

returns the computed difference in seconds between UTC time and local time.

    my $ServerLocalTimeOffsetSeconds = $TimeObject->ServerLocalTimeOffsetSeconds(
        SystemTime => $SystemTime,  # optional, otherwise call time()
    );

=cut

sub ServerLocalTimeOffsetSeconds {
    my ( $Self, %Param ) = @_;

    my $ServerTime = $Param{SystemTime} || time();
    my $ServerLocalTime = Time::Local::timegm_nocheck( localtime($ServerTime) );

    # Check if local time and UTC time are different
    return $ServerLocalTime - $ServerTime;

}

=item MailTimeStamp()

returns the current time stamp in RFC 2822 format to be used in email headers:
"Wed, 22 Sep 2014 16:30:57 +0200".

    my $MailTimeStamp = $TimeObject->MailTimeStamp();

=cut

sub MailTimeStamp {
    my ( $Self, %Param ) = @_;

    # According to RFC 2822, section 3.3

    # The date and time-of-day SHOULD express local time.
    #
    # The zone specifies the offset from Coordinated Universal Time (UTC,
    # formerly referred to as "Greenwich Mean Time") that the date and
    # time-of-day represent.  The "+" or "-" indicates whether the
    # time-of-day is ahead of (i.e., east of) or behind (i.e., west of)
    # Universal Time.  The first two digits indicate the number of hours
    # difference from Universal Time, and the last two digits indicate the
    # number of minutes difference from Universal Time.  (Hence, +hhmm
    # means +(hh * 60 + mm) minutes, and -hhmm means -(hh * 60 + mm)
    # minutes).  The form "+0000" SHOULD be used to indicate a time zone at
    # Universal Time.  Though "-0000" also indicates Universal Time, it is
    # used to indicate that the time was generated on a system that may be
    # in a local time zone other than Universal Time and therefore
    # indicates that the date-time contains no information about the local
    # time zone.

    my @DayMap   = qw/Sun Mon Tue Wed Thu Fri Sat/;
    my @MonthMap = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;

    # Here we cannot use the KIX "TimeZone" because KIX uses localtime()
    #   and does not know if that is UTC or another time zone.
    #   Therefore KIX cannot generate the correct offset for the mail timestamp.
    #   So we need to use the real time configuration of the server to determine this properly.

    my $ServerTime = time();
    my $ServerTimeDiff = $Self->ServerLocalTimeOffsetSeconds( SystemTime => $ServerTime );

    # calculate offset - should be '+0200', '-0600', '+0545' or '+0000'
    my $Direction   = $ServerTimeDiff < 0 ? '-' : '+';
    my $DiffHours   = abs int( $ServerTimeDiff / 3600 );
    my $DiffMinutes = abs int( ( $ServerTimeDiff % 3600 ) / 60 );

    my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $Self->SystemTime2Date(
        SystemTime => $ServerTime,
    );

    my $TimeString = sprintf "%s, %d %s %d %02d:%02d:%02d %s%02d%02d",
        $DayMap[$WeekDay],    # 'Sat'
        $Day, $MonthMap[ $Month - 1 ], $Year,    # '2', 'Aug', '2014'
        $Hour,      $Min,       $Sec,            # '12', '34', '36'
        $Direction, $DiffHours, $DiffMinutes;    # '+', '02', '00'

    return $TimeString;
}

=item WorkingTime()

get the working time in seconds between these local system times.

    my $WorkingTime = $TimeObject->WorkingTime(
        StartTime => $Created,
        StopTime  => $TimeObject->SystemTime(),
    );

    my $WorkingTime = $TimeObject->WorkingTime(
        StartTime => $Created,
        StopTime  => $TimeObject->SystemTime(),
        Calendar  => 3,           # '' is default
        Debug     => 1            # 1|0 (0 is default) to output debug logs (e.g. given times, some calculation results, ...)
    );

=cut

sub WorkingTime {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(StartTime StopTime)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    if ($Param{Debug}) {
        print STDERR "WorkingTime - debugging infos ___________________\n";
        # handle it as UTC time (no TZ), so no offset is considered
        my $DebugDateTimeObject = DateTime->from_epoch( epoch => $Param{StartTime} );
        print STDERR "  START given:       " . $DebugDateTimeObject->datetime(" ") . "\n";
        $DebugDateTimeObject = DateTime->from_epoch( epoch => $Param{StopTime} );
        print STDERR "  STOP given:        " . $DebugDateTimeObject->datetime(" ") . "\n";
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $TimeWorkingHours        = $ConfigObject->Get('TimeWorkingHours');
    my $TimeVacationDays        = $Self->GetVacationDays();
    my $TimeVacationDaysOneTime = {};
    my $TimeZone = $Self->{TimeZone} || $Kernel::OM->Get('Config')->Get('TimeZone');
    if ( $Param{Calendar} ) {
        if ( $ConfigObject->Get( "TimeZone::Calendar" . $Param{Calendar} ) ) {
            $TimeWorkingHours = $ConfigObject->Get( "TimeWorkingHours::Calendar" . $Param{Calendar} );
            $TimeVacationDays = $Self->GetVacationDays( Calendar => $Param{Calendar} );
            $TimeZone         = $ConfigObject->Get( "TimeZone::Calendar" . $Param{Calendar} );
        }
    }
    $TimeZone ||= 'UTC';

    # add offsets
    my $DateTimeObject = DateTime->from_epoch(
        epoch     => $Param{StartTime},
        time_zone => $TimeZone
    );
    my $StartTZOffset = $DateTimeObject->offset;
    $Param{StartTime} += $StartTZOffset;

    $DateTimeObject = DateTime->from_epoch(
        epoch     => $Param{StopTime},
        time_zone => $TimeZone
    );
    my $StopTZOffset = $DateTimeObject->offset;
    $Param{StopTime}  += $StopTZOffset;

    # get TimeWorking
    my %TimeWorking;
    if (ref($TimeWorkingHours) eq 'HASH') {
        %TimeWorking = $Self->_GetTimeWorking(
            TimeWorkingHours => $TimeWorkingHours,
            Calendar         => $Param{Calendar} || '',
        );
    }
    if ($Param{Debug}) {
        # handle it as UTC time (no TZ), so no offset is considered
        my $DebugDateTimeObject = DateTime->from_epoch( epoch => $Param{StartTime} );
        print STDERR "  START calendar:    " . $DebugDateTimeObject->datetime(" ") . " - used timezone: $TimeZone, offset: $StartTZOffset (" . ($StartTZOffset/60/60) . "h)\n";
        $DebugDateTimeObject = DateTime->from_epoch( epoch => $Param{StopTime} );
        print STDERR "  STOP calendar:     " . $DebugDateTimeObject->datetime(" ") . " - used timezone: $TimeZone, offset: $StopTZOffset (" . ($StopTZOffset/60/60) . "h)\n";
    }

    my %LDay = (
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        0 => 'Sun',
    );

    my $Counted = 0;

    my $ADateTimeObject = DateTime->from_epoch( epoch => $Param{StartTime} );
    my $AYear  = $ADateTimeObject->year;
    my $AMonth = $ADateTimeObject->month;
    my $ADay   = $ADateTimeObject->day;
    my $AHour  = $ADateTimeObject->hour;
    my $AMin   = $ADateTimeObject->minute;
    my $ASec   = $ADateTimeObject->second;
    my $AWDay  = $ADateTimeObject->wday == 7 ? 0 : $ADateTimeObject->wday;
    my $ADate  = $ADateTimeObject->date;

    my $BDateTimeObject = DateTime->from_epoch( epoch => $Param{StopTime} );
    my $BYear  = $BDateTimeObject->year;
    my $BMonth = $BDateTimeObject->month;
    my $BDay   = $BDateTimeObject->day;
    my $BHour  = $BDateTimeObject->hour;
    my $BMin   = $BDateTimeObject->minute;
    my $BSec   = $BDateTimeObject->second;
    my $BWDay  = $BDateTimeObject->wday == 7 ? 0 : $BDateTimeObject->wday;
    my $BDate  = $BDateTimeObject->date;

    my $CInit = 1;
    my $DayLightSavingSwitch = 0;

    WORKINGDAY:
    while ( 1 ) {
        my $DateTimeObject = DateTime->from_epoch( epoch => $Param{StartTime} );
        my $Year  = $DateTimeObject->year;
        my $Month = $DateTimeObject->month;
        my $Day   = $DateTimeObject->day;
        my $Hour  = $DateTimeObject->hour;
        my $Min   = $DateTimeObject->minute;
        my $Sec   = $DateTimeObject->second;
        my $WDay  = $DateTimeObject->wday == 7 ? 0 : $DateTimeObject->wday;

        my $CDate  = $DateTimeObject->date;
        my $CTime00 = $Param{StartTime} - ( ( $Hour * 60 + $Min ) * 60 + $Sec );                  # 00:00:00

        # stop if actual date is after end date
        if ($BDate lt $CDate) {
            last WORKINGDAY;
        }

        my $DayStartHour;
        my $DayStartMinute;
        my $DayStartSecond;
        my $UsedWorkTime = 0;

        # prepare vacation days if needed
        if ( ref( $TimeVacationDaysOneTime->{ $Year } ) ne 'HASH' ) {
            $TimeVacationDaysOneTime->{ $Year } = $Self->PrepareVacationDaysOfYear(
                Calendar => $Param{Calendar},
                Year     => $Year,
            );
        }

        if ( %TimeWorking ) {
            # get WorkingDay
            my $WorkingDay = $LDay{$WDay};

            # check for VacationDay
            if ( $TimeVacationDays->{$Month}->{$Day} ) {
                $WorkingDay = $TimeVacationDays->{$Month}->{$Day};
            }
            if ( $TimeVacationDaysOneTime->{$Year}->{$Month}->{$Day} ) {
                $WorkingDay = $TimeVacationDaysOneTime->{$Year}->{$Month}->{$Day};
            }

            # process working minutes
            if ( $TimeWorking{ $WorkingDay } ) {
                WORKINGHOUR:
                for my $WorkingHour ( sort{ $a <=> $b }( keys( %{ $TimeWorking{$WorkingDay} } ) ) ) {
                    next WORKINGHOUR if ($WorkingHour < 0);

                    # not date of start or end (day between) => consider hole working time
                    if (
                        $CDate ne $ADate
                        && $CDate ne $BDate
                    ) {
                        $UsedWorkTime += $TimeWorking{$WorkingDay}->{-1}->{'DayWorkingTime'};

                        # remember working day start
                        if (!defined $DayStartHour) {
                            DAYSTART:
                            for my $StartHour ( sort{ $a <=> $b }( keys( %{ $TimeWorking{$WorkingDay} } ) ) ) {
                                next if ($StartHour < 0);
                                if ($TimeWorking{$WorkingDay}->{$StartHour}->{'WorkingTime'}) {
                                    $DayStartHour = $StartHour;
                                    my %Minutes = %{ $TimeWorking{$WorkingDay}->{$StartHour} };
                                    delete $Minutes{WorkingTime};
                                    for my $StartMinute ( sort{ $a <=> $b }( keys( %Minutes ) ) ) {
                                        if ($TimeWorking{$WorkingDay}->{$StartHour}->{$StartMinute}) {
                                            $DayStartMinute = $StartMinute;
                                            last DAYSTART;
                                        }
                                    }
                                }
                            }
                        }

                        last WORKINGHOUR;
                    }

                    # no service time this hour
                    elsif (
                        !$TimeWorking{$WorkingDay}->{$WorkingHour}->{'WorkingTime'}
                    ) {}

                    # same date and same hour of start/end date within service time
                    # and 60 minute working time this hour
                    elsif (
                        $ADate eq $BDate
                        && $AHour == $BHour
                        && $AHour == $WorkingHour
                        && $TimeWorking{$WorkingDay}->{$WorkingHour}->{'WorkingTime'} == 3600
                    ) {
                        return $Param{StopTime} - $Param{StartTime};
                    }
                    # same date and same hour of start/end date within service hour
                    elsif (
                        $ADate eq $BDate
                        && $AHour == $BHour
                        && $AHour == $WorkingHour
                    ) {
                        # remember working day start hour
                        if (!defined $DayStartHour) {
                            $DayStartHour = $WorkingHour;
                            $DayStartMinute = undef;
                        }
                        for my $WorkingMin (qw($AMin..$BMin)) {
                            if ($TimeWorking{$WorkingDay}->{$WorkingHour}->{$WorkingMin}) {
                                # remember working day start minute
                                if (!defined $DayStartMinute) {
                                    $DayStartMinute = $WorkingMin;
                                    $DayStartSecond = $Sec;
                                }
                                $UsedWorkTime += 60;
                            }
                        }
                        last WORKINGHOUR;
                    }

                    # date of start and before service time
                    elsif (
                        $CDate eq $ADate
                        && $WorkingHour < $AHour
                    ) {}

                    # date and hour of start
                    # and 60 minute working time this hour
                    elsif (
                        $CDate eq $ADate
                        && $AHour == $WorkingHour
                        && $TimeWorking{$WorkingDay}->{$WorkingHour}->{'WorkingTime'} == 3600
                    ) {
                        # remember working day start hour
                        if (!defined $DayStartHour) {
                            $DayStartHour = $WorkingHour;
                            $DayStartMinute = $AMin;
                            $DayStartSecond = $ASec;
                        }
                        $UsedWorkTime += ((59 - $AMin) * 60) + (60 - $ASec);
                    }

                    # date and hour of start
                    elsif (
                        $CDate eq $ADate
                        && $AHour == $WorkingHour
                    ) {
                        for my $WorkingMin (qw($AMin..59)) {
                            if ($TimeWorking{$WorkingDay}->{$WorkingHour}->{$WorkingMin}) {
                                if ($AMin == $WorkingMin) {
                                    $UsedWorkTime += (60 - $ASec);
                                } else {
                                    $UsedWorkTime += 60;
                                }
                            }
                        }
                    }

                    # date of end and after service time
                    elsif (
                        $CDate eq $BDate
                        && $WorkingHour > $BHour
                    ) {}

                    # date and hour from end
                    # and 60 minute working time this hour
                    elsif (
                        $CDate eq $BDate
                        && $BHour == $WorkingHour
                        && $TimeWorking{$WorkingDay}->{$WorkingHour}->{'WorkingTime'} == 3600
                    ) {
                        $UsedWorkTime += ($BMin * 60) + $BSec;
                    }

                    # date and hour from end
                    elsif (
                        $CDate eq $BDate
                        && $BHour == $WorkingHour
                    ) {
                        for my $WorkingMin (qw(0..$BMin)) {
                            if ($TimeWorking{$WorkingDay}->{$WorkingHour}->{$WorkingMin}) {
                                if ($BMin == $WorkingMin) {
                                    $UsedWorkTime += $BSec;
                                } else {
                                    $UsedWorkTime += 60;
                                }
                            }
                        }
                    }

                    # service time that is not first or last hour
                    else {
                        if (!defined $DayStartHour) {
                            $DayStartHour = $WorkingHour;
                            $DayStartMinute = $Min;
                            $DayStartSecond = $Sec;
                        }
                        $UsedWorkTime += $TimeWorking{$WorkingDay}->{$WorkingHour}->{'WorkingTime'};
                    }
                }
            }
        }

        $Counted += $UsedWorkTime;

        # only consider DST if happend during working time and calendar TZ is != UTC (etc/UTC, ...)
        my $DayLightOfStart = 0;
        my $DayLightOfEnd = 0;
        if ($TimeZone !~ /UTC/i) {
            # get DST state of working time start
            my $DSTDateTimeObject = DateTime->new(
                year => $Year, month => $Month, day => $Day,
                hour => ($DayStartHour||0), minute => ($DayStartMinute||0), second => ($DayStartSecond||0),
                time_zone => $TimeZone
            );
            $DayLightOfStart = $DSTDateTimeObject->is_dst;

            # add seconds to get calculated working end time and DST state
            $DSTDateTimeObject->add(seconds => $UsedWorkTime);
            $DayLightOfEnd = $DSTDateTimeObject->is_dst;

            # check for DST change during working time (if so one hour is just counted and not really done or not counted but "used" for work)
            if ($DayLightOfStart != $DayLightOfEnd) {
                $Counted -= $DSTDateTimeObject->offset - $StartTZOffset;
            }

            # set new offset (if DST happend - even if not during working time
            if ($StartTZOffset != $DSTDateTimeObject->offset) {
                # $DayLightSavingSwitch++;
                $StartTZOffset = $DSTDateTimeObject->offset;
            }
        }

        if ($Param{Debug} && 0) {
            my $DebugDateTimeObject = DateTime->new(
                year => $Year, month => $Month, day => $Day,
                hour => ($DayStartHour||0), minute => ($DayStartMinute||0), second => ($DayStartSecond||0)
            );
            print STDERR "      calculation start: " . $DebugDateTimeObject->datetime(" ") . " (working day start or incoming time if first iteration)\n";
            print STDERR "      calculation start is DST: $DayLightOfStart\n";
            $DebugDateTimeObject->add(seconds => $UsedWorkTime);
            print STDERR "      calculation end:   " . $DebugDateTimeObject->datetime(" ") . " (working day end or destination if last iteration)\n";
            print STDERR "      calculation end is DST: $DayLightOfEnd\n";
        }

        # reduce time => go to next day 00:00:00
        my $NextDayDateTimeObject = DateTime->new(
            year => $Year, month => $Month, day => $Day,
            hour => 23, minute => 59, second => 59
        );
        $NextDayDateTimeObject->add(seconds => 1);
        $Param{StartTime} = $NextDayDateTimeObject->epoch;
    }
    if ($Param{Debug}) {
        print STDERR "  DayLightSaving switched $DayLightSavingSwitch times\n";
        print STDERR "  End Working time:  " . $Counted . "s => " . Time::Seconds->new($Counted)->pretty . "\n";
        print STDERR "EO WorkingTime - debugging infos ___________________\n";
    }

    return $Counted;
}

=item DestinationTime()

get the destination time based on the current calendar working time (fallback: default
system working time) configuration.

The algorithm roughly works as follows:
    - Check if the start time is actually in the configured working time.
        - If not, set it to the next working time second. Example: start time is
            on a weekend, start time would be set to 8:00 on the following Monday.
    - Then the diff time (in seconds) is added to the start time incrementally, only considering
        the configured working times. So adding 24 hours could actually span multiple days because
        they would be spread over the configured working hours. If we have 8-20, 24 hours would be
        spread over 2 days (13/11 hours).

NOTE: Currently, the implementation stops silently after 600 iterations, making it impossible to
    specify longer escalation times, for example.

    my $DestinationTime = $TimeObject->DestinationTime(
        StartTime => $Created,
        Time      => 60*60*24*2,
    );

    my $DestinationTime = $TimeObject->DestinationTime(
        StartTime => $Created,
        Time      => 60*60*24*2,
        Calendar  => 3,                   # '' is default
        Debug     => 1                    # 1|0 (0 is default) to output debug logs (e.g. start time, intermediate results, ...)
    );

=cut

sub DestinationTime {
    my ( $Self, %Param ) = @_;

    # "Time zone" diff in seconds
    my $TZOffset = 0;

    # check needed stuff
    for (qw(StartTime Time)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    if ($Param{Debug}) {
        print STDERR "DestinationTime - debugging infos ___________________\n";
        # handle it as UTC time (no TZ), so no offset is considered
        my $DebugDateTimeObject = DateTime->from_epoch( epoch => $Param{StartTime} );
        print STDERR "  START given:    " . $DebugDateTimeObject->datetime(" ") . "\n";
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $TimeWorkingHours        = $ConfigObject->Get('TimeWorkingHours');
    my $TimeVacationDays        = $Self->GetVacationDays();
    my $TimeVacationDaysOneTime = {};
    my $TimeZone = $Self->{TimeZone} || $Kernel::OM->Get('Config')->Get('TimeZone');
    if ( $Param{Calendar} ) {
        if ( $ConfigObject->Get( "TimeZone::Calendar" . $Param{Calendar} ) ) {
            $TimeWorkingHours        = $ConfigObject->Get( "TimeWorkingHours::Calendar" . $Param{Calendar} );
            $TimeVacationDays        = $Self->GetVacationDays( Calendar => $Param{Calendar} );
            $TimeZone                = $ConfigObject->Get( "TimeZone::Calendar" . $Param{Calendar} );
        }
    }
    $TimeZone ||= 'UTC';

    # consider offset
    my $DateTimeObject = DateTime->from_epoch(
        epoch     => $Param{StartTime},
        time_zone => $TimeZone
    );
    $TZOffset = $DateTimeObject->offset;
    $Param{StartTime} += $TZOffset;

    my $DestinationTime = $Param{StartTime};
    my $CTime           = $Param{StartTime};

    if ($Param{Debug}) {
        # handle it as UTC time (no TZ), so no offset is considered
        my $DebugDateTimeObject = DateTime->from_epoch( epoch => $Param{StartTime} );
        print STDERR "  START calendar: " . $DebugDateTimeObject->datetime(" ") . " (used timezone: $TimeZone, offset: $TZOffset (" . ($TZOffset/60/60) . "h))\n";
    }

    # get TimeWorking
    my %TimeWorking;
    if (ref($TimeWorkingHours) eq 'HASH') {
        %TimeWorking = $Self->_GetTimeWorking(
            TimeWorkingHours => $TimeWorkingHours,
            Calendar         => $Param{Calendar} || '',
        );
    }
    if ( !%TimeWorking ) {
        return $DestinationTime - $TZOffset;
    }

    my %LDay = (
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        0 => 'Sun',
    );

    my $LoopCounter = 0;
    my $DayLightSavingSwitch = 0;

    LOOP:
    while ( $Param{Time} > 1 ) {
        $LoopCounter++;
        last LOOP if $LoopCounter > 5000;

        if ($Param{Debug}) {
            print STDERR "    $LoopCounter. Iteration\n";
            print STDERR "      time remaining start: $Param{Time}s => " . Time::Seconds->new($Param{Time})->pretty . "\n";
        }

        my $CTimeDateTimeObject = DateTime->from_epoch( epoch => $CTime );
        my $Year   = $CTimeDateTimeObject->year;
        my $Month  = $CTimeDateTimeObject->month;
        my $Day    = $CTimeDateTimeObject->day;
        my $Hour   = $CTimeDateTimeObject->hour;
        my $Minute = $CTimeDateTimeObject->minute;
        my $Second = $CTimeDateTimeObject->second;
        my $WDay   = $CTimeDateTimeObject->wday == 7 ? 0 : $CTimeDateTimeObject->wday;

        my $CTime00 = $CTime - ( ( $Hour * 60 + $Minute ) * 60 + $Second ); # 00:00:00

        my $DayStartHour;
        my $DayStartMinute;
        my $DayStartSecond;
        my $UsedWorkTime = 0;

        # prepare vacation days if needed
        if ( ref( $TimeVacationDaysOneTime->{ $Year } ) ne 'HASH' ) {
            $TimeVacationDaysOneTime->{ $Year } = $Self->PrepareVacationDaysOfYear(
                Calendar => $Param{Calendar},
                Year     => $Year,
            );
        }

        if ( %TimeWorking ) {

            # get WorkingDay
            my $WorkingDay = $LDay{$WDay};

            # check for VacationDay
            if ( $TimeVacationDays->{$Month}->{$Day} ) {
                $WorkingDay = $TimeVacationDays->{$Month}->{$Day};
            }
            if ( $TimeVacationDaysOneTime->{$Year}->{$Month}->{$Day} ) {
                $WorkingDay = $TimeVacationDaysOneTime->{$Year}->{$Month}->{$Day};
            }

            # skip days without working hours
            if ( !$TimeWorking{$WorkingDay}->{-1}->{'DayWorkingTime'} ) {

                # set destination time to next day, 00:00:00 - handle it as UTC (do not consider offset)
                my $NextDayDateTimeObject = DateTime->new(
                    year => $Year, month => $Month, day => $Day,
                    hour => 23, minute => 59, second => 59
                );
                $NextDayDateTimeObject->add(seconds => 1);
                $DestinationTime = $NextDayDateTimeObject->epoch;
            }

            # working time
            else {
                $DayStartHour = undef;
                HOUR:
                for my $WorkingHour ( $Hour .. 23 ) {
                    my $DiffDestTime = 0;
                    my $DiffWorkTime = 0;

                    # Working hour
                    if ( $TimeWorking{$WorkingDay}->{$WorkingHour} ) {
                        # remember working day start hour
                        if (!defined $DayStartHour) {
                            $DayStartHour = $WorkingHour;
                            $DayStartMinute = undef;
                        }
                        MINUTE:
                        for my $Min ( $Minute..59 ) {

                            # Working minute
                            if ( $TimeWorking{$WorkingDay}->{$WorkingHour}->{$Min} ) {
                                # remember working day start minute
                                if (!defined $DayStartMinute) {
                                    $DayStartMinute = $Min;
                                    $DayStartSecond = $Second;
                                }
                                if ( ($Param{Time} - $DiffWorkTime) > (60 - $Second) ) {
                                    $DiffDestTime += (60 - $Second);
                                    $DiffWorkTime += (60 - $Second);
                                } else {
                                    $DiffDestTime += ($Param{Time} - $DiffWorkTime);
                                    $DiffWorkTime += ($Param{Time} - $DiffWorkTime);
                                    last MINUTE;
                                }
                            }

                            # Not working minute
                            else {
                                $DiffDestTime += (60 - $Second);
                            }
                            $Second = 0;
                        }
                        # remember working day end
                        $UsedWorkTime += $DiffWorkTime;
                    }

                    # Not working hour
                    else {
                        $DiffDestTime = 3600 - ( $Minute * 60 + $Second );
                    }

                    # update time params
                    $DestinationTime += $DiffDestTime;
                    $Param{Time}     -= $DiffWorkTime;
                    $Minute = 0;
                    $Second = 0;

                    # check time left
                    if ($Param{Time} == 0) {
                        last HOUR;
                    }
                }
            }
        }

        # only consider DST if happend during working time and calendar TZ is != UTC (etc/UTC, ...)
        my $DayLightOfStart = 0;
        my $DayLightOfEnd = 0;
        if ($TimeZone !~ /UTC/i) {
            # get DST state of working time start
            my $DSTDateTimeObject = DateTime->new(
                year => $Year, month => $Month, day => $Day,
                hour => ($DayStartHour||0), minute => ($DayStartMinute||0), second => ($DayStartSecond||0),
                time_zone => $TimeZone
            );
            $DayLightOfStart = $DSTDateTimeObject->is_dst;

            # add seconds to get calculated working end time and DST state
            $DSTDateTimeObject->add(seconds => $UsedWorkTime);
            $DayLightOfEnd = $DSTDateTimeObject->is_dst;

            # check for DST change during working time (if so one hour is just counted and not really done or not counted but "used" for work)
            if ($DayLightOfStart != $DayLightOfEnd) {
                $DestinationTime += $DSTDateTimeObject->offset - $TZOffset;
            }

            # set new offset (if DST happend - even if not during working time
            if ($TZOffset != $DSTDateTimeObject->offset) {
                $DayLightSavingSwitch++;
                $TZOffset = $DSTDateTimeObject->offset;
            }
        }


        if ($Param{Debug}) {
            my $DebugDateTimeObject = DateTime->new(
                year => $Year, month => $Month, day => $Day,
                hour => ($DayStartHour||0), minute => ($DayStartMinute||0), second => ($DayStartSecond||0)
            );
            print STDERR "      calculation start: " . $DebugDateTimeObject->datetime(" ") . " (working day start or incoming time if first iteration)\n";
            print STDERR "      calculation start is DST: $DayLightOfStart\n";
            $DebugDateTimeObject->add(seconds => $UsedWorkTime);
            print STDERR "      calculation end:   " . $DebugDateTimeObject->datetime(" ") . " (working day end or destination if last iteration)\n";
            print STDERR "      calculation end is DST: $DayLightOfEnd\n";
            $DebugDateTimeObject = DateTime->from_epoch( epoch => $DestinationTime );
            print STDERR "      destination time:  " . $DebugDateTimeObject->datetime(" ") . " (next day if not last iteration)\n";
            print STDERR "      used time: " . $UsedWorkTime . "s => " . Time::Seconds->new($UsedWorkTime)->pretty . "\n";
            print STDERR "      time remaining end: $Param{Time}s => " . Time::Seconds->new($Param{Time})->pretty . "\n";
        }

        # get next loop time (next day) - handle it as UTC (do not consider offset)
        my $NextDayDateTimeObject = DateTime->new(
            year => $Year, month => $Month, day => $Day,
            hour => 23, minute => 59, second => 59
        );
        $NextDayDateTimeObject->add(seconds => 1);
        $CTime = $NextDayDateTimeObject->epoch;
    }

    if ($Param{Debug}) {
        print STDERR "  DayLightSaving switched $DayLightSavingSwitch times\n";
        # handle it as UTC time (no TZ), so no offset is considered
        my $DebugDateTimeObject = DateTime->from_epoch( epoch => $DestinationTime );
        print STDERR "  END calendar: " . $DebugDateTimeObject->datetime(" ") . "\n";
        # handle it as UTC time (no TZ), so no offset is considered
        $DebugDateTimeObject = DateTime->from_epoch( epoch => ($DestinationTime - $TZOffset) );
        print STDERR "  END outgoing: " . $DebugDateTimeObject->datetime(" ") . " (calendar offset: $TZOffset (" . ($TZOffset/60/60) . "h))\n";
        print STDERR "EO DestinationTime - debugging infos ___________________\n";
    }

    # return destination time - diff of calendar time zone
    return $DestinationTime - $TZOffset;
}

=item VacationCheck()

check if the selected day is a vacation (it doesn't matter if you
insert 01 or 1 for month or day in the function or in the SysConfig)

returns (true) vacation day if exists, returns false if date is no
vacation day

    $TimeObject->VacationCheck(
        Year     => 2005,
        Month    => 7 || '07',
        Day      => 13,
    );

    $TimeObject->VacationCheck(
        Year     => 2005,
        Month    => 7 || '07',
        Day      => 13,
        Calendar => 3, # '' is default; 0 is handled like ''
    );

=cut

sub VacationCheck {
    my ( $Self, %Param ) = @_;

    # check required params
    for my $ReqParam (qw(Year Month Day)) {
        if ( !$Param{$ReqParam} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "VacationCheck: Need $ReqParam!",
            );
            return;
        }
    }

    my $Year  = $Param{Year};
    my $Month = sprintf "%02d", $Param{Month};
    my $Day   = sprintf "%02d", $Param{Day};

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $TimeVacationDays;
    if (
        $Param{Calendar}
        && $ConfigObject->Get( 'TimeZone::Calendar' . $Param{Calendar} . 'Name' )
    ) {
        $TimeVacationDays = $Self->GetVacationDays( Calendar => $Param{Calendar} );
    }
    else {
        $TimeVacationDays = $Self->GetVacationDays();
    }
    my $TimeVacationDaysOneTime->{ $Year } = $Self->PrepareVacationDaysOfYear(
        Calendar => $Param{Calendar},
        Year     => $Year,
    );

    # '01' - format
    if ( defined $TimeVacationDays->{$Month}->{$Day} ) {
        return $TimeVacationDays->{$Month}->{$Day};
    }
    if ( defined $TimeVacationDaysOneTime->{$Year}->{$Month}->{$Day} ) {
        return $TimeVacationDaysOneTime->{$Year}->{$Month}->{$Day};
    }

    # 1 - int format
    $Month = int $Month;
    $Day   = int $Day;
    if ( defined $TimeVacationDays->{$Month}->{$Day} ) {
        return $TimeVacationDays->{$Month}->{$Day};
    }
    if ( defined $TimeVacationDaysOneTime->{$Year}->{$Month}->{$Day} ) {
        return $TimeVacationDaysOneTime->{$Year}->{$Month}->{$Day};
    }

    return;
}

=item GetVacationDays()

get TimeVacationDays from Config and prepare internal representation

    $TimeObject->GetVacationDays(
        Calendar => '...'           # optional
    );


=cut

sub GetVacationDays {
    my ( $Self, %Param ) = @_;
    my $Result;

    my $TimeVacationDays;
    if (
        $Param{Calendar}
        && $Kernel::OM->Get('Config')->Get( 'TimeZone::Calendar' . $Param{Calendar} . 'Name' )
    ) {
        $TimeVacationDays = $Kernel::OM->Get('Config')->Get( 'TimeVacationDays::Calendar' . $Param{Calendar} );
    }
    else {
        $TimeVacationDays = $Kernel::OM->Get('Config')->Get('TimeVacationDays');
    }

    return {} if !IsArrayRefWithData($TimeVacationDays);

    foreach my $Item ( @{$TimeVacationDays} ) {
        $Result->{$Item->{Month}}->{$Item->{Day}} = $Item->{content}
    }

    return $Result;
}

=item BOB()

get the begin of businessday based on calender (default is used if omitted)

    $TimeObject->BOB(
        String   => '2022-04-15 12:00:00',
        Calendar => '...'                       # optional
    );


=cut

sub BOB {
    my ( $Self, %Param ) = @_;

    if ( !defined $Param{String} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need String!",
        );
        return;
    }

    if ( $Param{Debug} ) {
        print STDERR "BOB - debugging infos ___________________\n";
        print STDERR "  IN: $Param{String}\n";
    }

    # get system time
    my $SystemTime = $Self->TimeStamp2SystemTime(
        String => $Param{String},
        Silent => $Param{Silent},
    );
    return if ( !$SystemTime );

    # get date parts
    my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $Self->SystemTime2Date(
        SystemTime => $SystemTime,
    );
    return if (!$Year);

    # get BOB unix
    my $BOBUnix = $Self->DestinationTime(
        StartTime => $Self->TimeStamp2SystemTime(
            String => "$Year-$Month-$Day 00:00:00",
        ),
        Time     => 2,   # at least 2 seconds needed, is substracted after next line
        Calendar => $Param{Calendar},
        Debug    => $Param{Debug}
    ) - 2;

    # get BOB date time string
    my $BOB = $Self->SystemTime2TimeStamp(
        SystemTime => $BOBUnix
    );

    if ( $Param{Debug} ) {
        print STDERR "  OUT: $BOB\n";
        print STDERR "EO BOB - debugging infos ___________________\n";
    }

    return $BOB;
}

=item EOB()

get the end of businessday based on calender (default is used if omitted)

    $TimeObject->EOB(
        String   => '2022-04-15 12:00:00',
        Calendar => '...'                       # optional
    );


=cut

sub EOB {
    my ( $Self, %Param ) = @_;

    if ( !defined $Param{String} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need String!",
        );
        return;
    }

    if ( $Param{Debug} ) {
        print STDERR "EOB - debugging infos ___________________\n";
        print STDERR "  IN: $Param{String}\n";
    }

    # get date parts
    my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $Self->SystemTime2Date(
        SystemTime => $Self->TimeStamp2SystemTime(
            String => $Param{String}
        )
    );
    return if (!$Year);

    # get BOB unix
    my $BOBUnix = $Self->DestinationTime(
        StartTime => $Self->TimeStamp2SystemTime(
            String => "$Year-$Month-$Day 00:00:00",
        ),
        Time     => 2,   # at least 2 seconds needed, is substracted after next line
        Calendar => $Param{Calendar},
        Debug    => $Param{Debug}
    ) - 2;

    # get 0:00 to 24:00 of relevant day
    my $BOBDateTimeObject = DateTime->from_epoch( epoch => $BOBUnix );
    $BOBDateTimeObject = DateTime->new(
        year => $BOBDateTimeObject->year, month => $BOBDateTimeObject->month, day => $BOBDateTimeObject->day,
        hour => 0, minute => 0, second => 0
    );
    my $StartTime = $BOBDateTimeObject->epoch;
    $BOBDateTimeObject->add(days => 1);
    my $StopTime = $BOBDateTimeObject->epoch;

    # get working time of relevant day (seconds)
    my $WorkingTime = $Self->WorkingTime(
        StartTime => $StartTime,
        StopTime  => $StopTime,
        Calendar  => $Param{Calendar},
        Debug     => $Param{Debug}
    );

    if ( $Param{Debug} ) {
        my $DebugDateTimeObject = DateTime->from_epoch( epoch => $BOBUnix );
        print STDERR "  BOB for EOB: " . $DebugDateTimeObject->datetime(" ") . "\n";
        print STDERR "  WorkingTime: " . Time::Seconds->new($WorkingTime)->pretty . "\n";
    }

    # get EOB date time string (= BOB + working time for this day)
    my $EOB = $Self->SystemTime2TimeStamp(
        SystemTime => $BOBUnix + $WorkingTime
    );

    if ( $Param{Debug} ) {
        print STDERR "  OUT: $EOB\n";
        print STDERR "EO EOB - debugging infos ___________________\n";
    }

    return $EOB;
}

=item CalculateTimeInterval()

returns given seconds as counted days, hours, minutes, seconds string

    $TimeObject->CalculateTimeInterval(
        Seconds => 60*60*24*2 + 60*60*5 + 30        # not as string!
    );

given seconds => result
    60*60*24*2 + 60*60*5 + 30 => 2d 5h 0m 30s
    60*60*24*2 + 30           => 2d 0h 0m 30s
    60*60*5 + 30              => 5h 0m 30s
    123                       => 2m 3s
    -123                      => -2m 3s

=cut

sub CalculateTimeInterval {
    my ( $Self, %Param ) = @_;

    return if (!defined $Param{Seconds} || $Param{Seconds} !~ m/^-?\d+$/);

    my $IsNegative = 0;
    if ( $Param{Seconds} < 0 ) {
        $IsNegative = 1;
        $Param{Seconds} *= -1;
    }

    my $Result = '';
    if ( $Param{Seconds} > 59) {
        my $HourSec   = 60*60;
        my $DaySec    = 60*60*24;

        my $Seconds    = $Param{Seconds};

        my $Days    = int($Seconds / $DaySec);
        my $Hours   = int(($Seconds - $Days * $DaySec) / $HourSec);
        my $Minutes = int(($Seconds - $Days * $DaySec - $Hours * $HourSec) / 60);
        $Seconds = $Seconds - $Days * $DaySec - $Hours * $HourSec - $Minutes * 60;

        my @Parts;
        if ($Days) {
            push(@Parts, $Days . 'd');
        }
        if ($Hours || (@Parts && ($Minutes || $Seconds))) {
            push(@Parts, $Hours . 'h');
        }
        if ($Minutes || (@Parts && $Seconds)) {
            push(@Parts, $Minutes . 'm');
        }
        if ($Seconds) {
            push(@Parts, $Seconds . 's');
        }
        $Result = join(' ', @Parts);
    } else {
        $Result = $Param{Seconds} . 's';
    }

    if ($IsNegative) {
        $Result = '-' . $Result;
    }

    return $Result;
}

sub _GetTimeWorking {
    my ( $Self, %Param ) = @_;

    # check cache
    my $TimeWorkingCache = $Self->{CacheObject}->Get(
        Type => $Self->{CacheType},
        Key  => "TimeWorkingHours::Calendar" . $Param{Calendar},
    );
    return %{$TimeWorkingCache} if ( defined($TimeWorkingCache) );

    # set WorkingTime
    my %TimeWorking;
    for my $Entry ( keys( %{$Param{TimeWorkingHours}} ) ) {
        my @ConfigEntries = split(',', $Param{TimeWorkingHours}->{$Entry});
        for my $Config ( @ConfigEntries ) {
            if (
                $Config =~ m/^\s*([0-1]?[0-9]|2[0-3]):([0-5][0-9])-([0-1]?[0-9]|2[0-3]):([0-5][0-9])\s*$/
                || $Config =~ m/^\s*([0-1]?[0-9]|2[0-3]):([0-5][0-9])-(24):(00)\s*$/
            ) {
                my $StartHour   = $1;
                my $StartMin    = $2;
                my $StopHour    = $3;
                my $StopMin     = $4;
                $StartHour =~ s/0([0-9])/$1/;
                $StartMin =~ s/0([0-9])/$1/;
                $StopHour =~ s/0([0-9])/$1/;
                $StopMin =~ s/0([0-9])/$1/;
                while (
                    $StopHour > $StartHour
                    || $StopMin > $StartMin
                ) {
                    $TimeWorking{$Entry}->{$StartHour}->{$StartMin} = 1;
                    $StartMin++;
                    if ($StartMin == 60) {
                        $StartHour++;
                        $StartMin = 0;
                    }
                }
            } else {
                if ( $Param{Calendar} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Invalid entry in TimeWorkingHours::Calendar' . $Param{Calendar} . ' <' . $Entry . '>',
                    );
                } else {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Invalid entry in TimeWorkingHours <' . $Entry . '>',
                    );
                }
            }
        }
    }
    # prepare WorkingMinutes per day and hour
    for my $WorkingDay ( keys( %TimeWorking ) ) {
        my $DayWorkingMinutes = 0;
        for my $Hour ( keys( %{$TimeWorking{$WorkingDay}} ) ) {
            my $WorkingMinutes = 0;
            for my $Minute ( keys( %{$TimeWorking{$WorkingDay}->{$Hour}} ) ) {
                $DayWorkingMinutes++;
                $WorkingMinutes++;
            }
            $TimeWorking{$WorkingDay}->{$Hour}->{'WorkingTime'} = $WorkingMinutes * 60;
        }
        $TimeWorking{$WorkingDay}->{-1}->{'DayWorkingTime'} = $DayWorkingMinutes * 60;
    }
    $Self->{CacheObject}->Set(
        Type  => $Self->{CacheType},
        Key   => "TimeWorkingHours::Calendar" . $Param{Calendar},
        Value => \%TimeWorking,
        TTL   => 5 * 60,
        Depends => ['SysConfig'] # delete also if config is changed (TimeWorkingHours)
    );
    return %TimeWorking;
}

sub PrepareVacationDaysOfYear {
    my ( $Self, %Param ) = @_;

    # init return value
    my %VacationDaysOfYear = ();

    # check data
    if ( !defined( $Param{Year} ) ) {
        return \%VacationDaysOfYear;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # process sysconfig
    my $TimeVacationDaysOneTime;
    my $TimeVacationDaysModules;
    if (
        $Param{Calendar}
        && $ConfigObject->Get( 'TimeZone::Calendar' . $Param{Calendar} . 'Name' )
    ) {
        $TimeVacationDaysOneTime = $ConfigObject->Get( 'TimeVacationDaysOneTime::Calendar' . $Param{Calendar} );
        $TimeVacationDaysModules = $ConfigObject->Get( 'TimeVacationDaysModules::Calendar' . $Param{Calendar} );
    }
    else {
        $TimeVacationDaysOneTime = $ConfigObject->Get('TimeVacationDaysOneTime');
        $TimeVacationDaysModules = $ConfigObject->Get('TimeVacationDaysModules');
    }

    # process modules
    if ( ref( $TimeVacationDaysModules ) eq 'HASH' ) {

        CONFIG:
        for my $ModuleConfig ( sort( keys( %{ $TimeVacationDaysModules } ) ) ) {

            next CONFIG if (
                ref( $TimeVacationDaysModules->{$ModuleConfig} ) ne 'HASH'
                || !$TimeVacationDaysModules->{$ModuleConfig}->{Name}
                || !$TimeVacationDaysModules->{$ModuleConfig}->{Module}
            );
            last CONFIG if ( !$Kernel::OM->Get('Main')->Require( $TimeVacationDaysModules->{$ModuleConfig}->{Module} ) );

            my $VacationObject = $TimeVacationDaysModules->{$ModuleConfig}->{Module}->new(
                %{$Self},
            );

            if ( !$VacationObject ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "new() of vacation module $TimeVacationDaysModules->{$ModuleConfig}->{Module} not successfully!",
                );
                next CONFIG;
            }

            # run module
            my %ModuleVacationDaysOfYear = $VacationObject->Run(
                Name => $TimeVacationDaysModules->{$ModuleConfig}->{Name},
                Year => $Param{Year},
            );

            # merge hashes
            if ( %ModuleVacationDaysOfYear ) {
                for my $Month ( keys( %ModuleVacationDaysOfYear ) ) {
                    if ( ref( $ModuleVacationDaysOfYear{ $Month } ) eq 'HASH' ) {
                        for my $Day ( keys ( %{ $ModuleVacationDaysOfYear{ $Month } } ) ) {
                            $VacationDaysOfYear{ $Month }->{ $Day } = $ModuleVacationDaysOfYear{ $Month }->{ $Day };
                        }
                    }
                }
            }
        }
    }

    if (
        ref( $TimeVacationDaysOneTime ) eq 'HASH'
        && ref( $TimeVacationDaysOneTime->{ $Param{Year} } ) eq 'HASH'
    ) {
        %VacationDaysOfYear = %{ $TimeVacationDaysOneTime->{ $Param{Year} } };
    }

    return \%VacationDaysOfYear;
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
