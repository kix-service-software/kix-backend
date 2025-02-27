# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::CronEvent;

use strict;
use warnings;

use Schedule::Cron::Events;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Log',
    'Time',
);

=head1 NAME

Kernel::System::CronEvent - Cron Events wrapper functions

=head1 SYNOPSIS

Functions to calculate cron events time.

=over 4

=cut

=item new()

create a CronEvent object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CronEventObject = $Kernel::OM->Get('CronEvent');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item NextEventGet()

gets the time when the next cron event should occur, from a given time.

    my $EventSystemTime = $CronEventObject->NextEventGet(
        Schedule  => '*/2 * * * *',    # recurrence parameters based in cron notation
        StartTime => '1423165100',     # optional, defaults to current time
    );

Returns:

    my $EventSystemTime = 1423165220;  # or false in case of an error

=cut

sub NextEventGet {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !$Param{Schedule} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need Schedule!",
            );
        }
        return;
    }

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    my $StartTime = $Param{StartTime} || $TimeObject->SystemTime();

    return if !$StartTime;

    # init cron object
    my $CronObject = $Self->_Init(
        Schedule  => $Param{Schedule},
        StartTime => $StartTime,
        Silent    => $Param{Silent},
    );

    return if !$CronObject;

    my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $CronObject->nextEvent();

    # it is needed to add 1 to the month for correct calculation
    my $SystemTime = $TimeObject->Date2SystemTime(
        Year   => $Year + 1900,
        Month  => $Month + 1,
        Day    => $Day,
        Hour   => $Hour,
        Minute => $Min,
        Second => $Sec,
    );

    return $SystemTime;
}

=item NextEventList()

gets the time when the next cron events should occur, from a given time on a defined range.

    my @NextEvents = $CronEventObject->NextEventList(
        Schedule  => '*/2 * * * *',           # recurrence parameters based in cron notation
        StartTime => '1423165100',            # optional, defaults to current time
        StopTime  => '1423165300',
    );

Returns:

    my @NextEvents = [ '1423165220', ...  ];  # or false in case of an error

=cut

sub NextEventList {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Schedule StopTime)) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!",
                );
            }
            return;
        }
    }

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    my $StartTime = $Param{StartTime} || $TimeObject->SystemTime();

    return if !$StartTime;

    if ( $StartTime > $Param{StopTime} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "StartTime must be lower than or equals to StopTime",
            );
        }
        return;
    }

    # init cron object
    my $CronObject = $Self->_Init(
        Schedule  => $Param{Schedule},
        StartTime => $StartTime,
        Silent    => $Param{Silent},
    );

    return if !$CronObject;

    my $SystemTime = $StartTime;

    my @Result;

    LOOP:
    while (1) {

        my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $CronObject->nextEvent();

        # it is needed to add 1 to the month for correct calculation
        $SystemTime = $TimeObject->Date2SystemTime(
            Year   => $Year + 1900,
            Month  => $Month + 1,
            Day    => $Day,
            Hour   => $Hour,
            Minute => $Min,
            Second => $Sec,
        );

        last LOOP if !$SystemTime;
        last LOOP if $SystemTime > $Param{StopTime};

        push @Result, $SystemTime;
    }

    return @Result;
}

=item PreviousEventGet()

gets the time when the last Cron event had occurred, from a given time.

    my $PreviousSystemTime = $CronEventObject->PreviousEventGet(
        Schedule  => '*/2 * * * *',          # recurrence parameters based in Cron notation
        StartTime => '2015-08-21 14:01:00',  # optional, defaults to current time
    );

Returns:

    my $EventSystemTime = 1423165200;        # or false in case of an error

=cut

sub PreviousEventGet {
    my ( $Self, %Param ) = @_;

    # check needed params
    if ( !$Param{Schedule} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need Schedule!",
            );
        }
        return;
    }

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    my $StartTime = $Param{StartTime} || $TimeObject->SystemTime();

    return if !$StartTime;

    # init cron object
    my $CronObject = $Self->_Init(
        Schedule  => $Param{Schedule},
        StartTime => $StartTime,
        Silent    => $Param{Silent},
    );

    return if !$CronObject;

    my ( $Sec, $Min, $Hour, $Day, $Month, $Year ) = $CronObject->previousEvent();

    # it is needed to add 1 to the month for correct calculation
    my $SystemTime = $TimeObject->Date2SystemTime(
        Year   => $Year + 1900,
        Month  => $Month + 1,
        Day    => $Day,
        Hour   => $Hour,
        Minute => $Min,
        Second => $Sec,
    );

    return $SystemTime;
}

=begin Internal:

=cut

=item _Init()

creates a Schedule::Cron::Events object.

    my $CronObject = $CronEventObject->_Init(
        Schedule  => '*/2 * * * *',  # recurrence parameters based in Cron notation
        StartTime => '1423165100',
    }

=cut

sub _Init {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Schedule StartTime)) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!",
                );
            }
            return;
        }
    }

    # if a day and month are specified validate that the month has that specific day
    # this could be removed after Schedule::Cron::Events 1.94 is released and tested
    # see https://rt.cpan.org/Public/Bug/Display.html?id=109246
    my ( $Min, $Hour, $DayMonth, $Month, $DayWeek ) = split ' ', $Param{Schedule};
    if ( IsPositiveInteger($DayMonth) && IsPositiveInteger($Month) ) {

        my @MonthLastDay = ( 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );
        my $LastDayOfMonth = $MonthLastDay[ $Month - 1 ];

        if ( $DayMonth > $LastDayOfMonth ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Schedule: $Param{Schedule} is invalid",
                );
            }
            return;
        }
    }

    # create new internal cron object
    my $CronObject;
    eval {
        $CronObject = Schedule::Cron::Events->new(    ## no critic
            $Param{Schedule},
            Seconds => $Param{StartTime},
        );
    };

    # error handling
    if ($@) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Schedule: $Param{Schedule} is invalid:",
            );
        }
        return;
    }

    # check cron object
    if ( !$CronObject ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not create new Schedule::Cron::Events object!",
            );
        }
        return;
    }

    return $CronObject;
}

1;

=end Internal:


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
