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

use vars (qw($Self));

# get time object
my $TimeObject = $Kernel::OM->Get('Time');

my $SystemTime = $TimeObject->SystemTime();

# NextEventGet() tests
my @Tests = (
    {
        Name    => 'No Params',
        Config  => {
            Silent => 1,
        },
        Success => 0,
    },
    {
        Name   => 'No Schedule',
        Config => {
            StartTimeStamp => '2015-12-12 00:00:00',
            Silent         => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule minute (greater)',
        Config => {
            Schedule => '60 * * * * *',
            Silent   => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule minute (lower)',
        Config => {
            Schedule => '-1 * * * * *',
            Silent   => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule hour (greater)',
        Config => {
            Schedule => '* 24 * * * *',
            Silent   => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule hour (lower)',
        Config => {
            Schedule => '* -1 * * *',
            Silent   => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule day of month (greater)',
        Config => {
            Schedule => '* * 32 * *',
            Silent   => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule day of month (lower)',
        Config => {
            Schedule => '* * 0 * *',
            Silent   => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule month (greater)',
        Config => {
            Schedule => '* * * 13 *',
            Silent   => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule month (lower)',
        Config => {
            Schedule => '* * * 0 *',
            Silent   => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule day of week (greater)',
        Config => {
            Schedule => '* * * * 8',
            Silent   => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule day of week (lower)',
        Config => {
            Schedule => '* * * * -1',
            Silent   => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Correct each 1 minute 0 secs',
        Config => {
            Schedule       => '*/1 * * * *',
            StartTimeStamp => '2015-03-05 14:15:00',
        },
        ExpectedValue => '2015-03-05 14:16:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 1 minute 30 secs',
        Config => {
            Schedule       => '*/1 * * * *',
            StartTimeStamp => '2015-03-05 14:15:30',
        },
        ExpectedValue => '2015-03-05 14:16:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 1 minute 59 secs',
        Config => {
            Schedule       => '*/1 * * * *',
            StartTimeStamp => '2015-03-05 14:15:59',
        },
        ExpectedValue => '2015-03-05 14:16:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 minutes',
        Config => {
            Schedule       => '*/2 * * * *',
            StartTimeStamp => '2015-03-05 14:16:00',
        },
        ExpectedValue => '2015-03-05 14:18:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 5 minutes',
        Config => {
            Schedule       => '*/5 * * * *',
            StartTimeStamp => '2015-03-05 14:16:00',
        },
        ExpectedValue => '2015-03-05 14:20:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 1 hour',
        Config => {
            Schedule       => '0 * * * *',
            StartTimeStamp => '2015-03-05 14:16:00',
        },
        ExpectedValue => '2015-03-05 15:00:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 hours',
        Config => {
            Schedule       => '0 */2 * * *',
            StartTimeStamp => '2015-03-05 14:16:00',
        },
        ExpectedValue => '2015-03-05 16:00:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 hours on minute 30 (1)',
        Config => {
            Schedule       => '30 */2 * * *',
            StartTimeStamp => '2015-03-05 14:16:00',
        },
        ExpectedValue => '2015-03-05 14:30:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 hours on minute 30 (2)',
        Config => {
            Schedule       => '30 */2 * * *',
            StartTimeStamp => '2015-03-05 14:36:00',
        },
        ExpectedValue => '2015-03-05 16:30:00',
        Success       => 1,
    },
    {
        Name   => 'Correct next day at 11:30',
        Config => {
            Schedule       => '30 11 * * *',
            StartTimeStamp => '2015-01-05 14:36:00',
        },
        ExpectedValue => '2015-01-06 11:30:00',
        Success       => 1,
    },
    {
        Name   => 'Correct on day 12th at 11:30',
        Config => {
            Schedule       => '30 11 12 * *',
            StartTimeStamp => '2015-12-05 14:36:00',
        },
        ExpectedValue => '2015-12-12 11:30:00',
        Success       => 1,
    },
    {
        Name   => 'Correct next month at 11:30',
        Config => {
            Schedule       => '30 11 5 * *',
            StartTimeStamp => '2015-03-05 14:36:00',
        },
        ExpectedValue => '2015-04-05 11:30:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 minutes (next year)',
        Config => {
            Schedule       => '*/2 * * * *',
            StartTimeStamp => '2015-12-31 23:59:00',
        },
        ExpectedValue => '2016-01-01 00:00:00',
        Success       => 1,
    },
    {
        Name   => 'Not existing date April 31',
        Config => {
            Schedule       => '2 2 31 4 *',
            StartTimeStamp => '2015-01-01 00:00:00',
            Silent         => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Not existing date February 30',
        Config => {
            Schedule       => '2 2 30 2 *',
            StartTimeStamp => '2015-01-01 00:00:00',
            Silent         => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Existing date February 29',
        Config => {
            Schedule       => '2 2 29 2 *',
            StartTimeStamp => '2015-01-01 00:00:00',
        },
        ExpectedValue => '2016-02-29 02:02:00',
        Success       => 1,
    },
);

# get cron event object
my $CronEventObject = $Kernel::OM->Get('CronEvent');

for my $Test (@Tests) {

    if ( $Test->{Config}->{StartTimeStamp} ) {
        $Test->{Config}->{StartTime} = $TimeObject->TimeStamp2SystemTime(
            String => $Test->{Config}->{StartTimeStamp},
        );
    }

    my $EventSystemTime = $CronEventObject->NextEventGet( %{ $Test->{Config} } );

    if ( $Test->{Success} ) {

        $Self->Is(
            $TimeObject->SystemTime2TimeStamp(
                SystemTime => $EventSystemTime,
                )
                || '',
            $Test->{ExpectedValue},
            "$Test->{Name} NextEvent() - Human TimeStamp Match",
        );
    }
    else {
        $Self->Is(
            $EventSystemTime,
            undef,
            "$Test->{Name} NextEvent()",
        );
    }
}

# NextEventList() tests
@Tests = (
    {
        Name    => 'No Params',
        Config  => {
            Silent => 1,
        },
        Success => 0,
    },
    {
        Name   => 'No Schedule',
        Config => {
            StartTimeStamp => '2015-03-05 00:00:00',
            Silent         => 1,
        },
        Success => 0,
    },
    {
        Name   => 'No StopTimeStamp',
        Config => {
            Schedule       => '*/2 * * * *',
            StartTimeStamp => '2015-03-05 00:00:00',
            Silent         => 1,

        },
        Success => 0,
    },
    {
        Name   => 'Lower StoptimeStamp',
        Config => {
            Schedule       => '*/2 * * * *',
            StartTimeStamp => '2015-03-05 00:00:01',
            StopTimeStamp  => '2015-03-05 00:00:00',
            Silent         => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Correct very small range (empty)',
        Config => {
            Schedule       => '*/2 * * * *',
            StartTimeStamp => '2015-03-05 00:00:00',
            StopTimeStamp  => '2015-03-05 00:00:01',
        },
        ExpectedValue => [],
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 minutes',
        Config => {
            Schedule       => '*/2 * * * *',
            StartTimeStamp => '2015-03-05 14:15:00',
            StopTimeStamp  => '2015-03-05 14:16:00'
        },
        ExpectedValue => ['2015-03-05 14:16:00'],
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 minutes (2)',
        Config => {
            Schedule       => '*/2 * * * *',
            StartTimeStamp => '2015-03-05 14:15:00',
            StopTimeStamp  => '2015-03-05 14:31:00'
        },
        ExpectedValue => [
            '2015-03-05 14:16:00',
            '2015-03-05 14:18:00',
            '2015-03-05 14:20:00',
            '2015-03-05 14:22:00',
            '2015-03-05 14:24:00',
            '2015-03-05 14:26:00',
            '2015-03-05 14:28:00',
            '2015-03-05 14:30:00',
        ],
        Success => 1,
    },
    {
        Name   => 'Correct each hour',
        Config => {
            Schedule       => '0 * * * *',
            StartTimeStamp => '2015-03-05 14:15:00',
            StopTimeStamp  => '2015-03-05 17:31:00'
        },
        ExpectedValue => [
            '2015-03-05 15:00:00',
            '2015-03-05 16:00:00',
            '2015-03-05 17:00:00',
        ],
        Success => 1,
    },

    {
        Name   => 'Correct each month on 1st at 1 AM (year overlapping)',
        Config => {
            Schedule       => '0 1 1 * *',
            StartTimeStamp => '2014-03-05 14:15:00',
            StopTimeStamp  => '2015-01-05 17:31:00'
        },
        ExpectedValue => [
            '2014-04-01 01:00:00',
            '2014-05-01 01:00:00',
            '2014-06-01 01:00:00',
            '2014-07-01 01:00:00',
            '2014-08-01 01:00:00',
            '2014-09-01 01:00:00',
            '2014-10-01 01:00:00',
            '2014-11-01 01:00:00',
            '2014-12-01 01:00:00',
            '2015-01-01 01:00:00',
        ],
        Success => 1,
    },
);

for my $Test (@Tests) {

    for my $Part (qw(StartTime StopTime)) {
        if ( $Test->{Config}->{ $Part . 'Stamp' } ) {
            $Test->{Config}->{$Part} = $TimeObject->TimeStamp2SystemTime(
                String => $Test->{Config}->{ $Part . 'Stamp' },
            );
        }
    }

    my @NextEvents = $CronEventObject->NextEventList( %{ $Test->{Config} } );

    if ( $Test->{Success} ) {

        my @NextEventsConverted = map {
            $TimeObject->SystemTime2TimeStamp(
                SystemTime => $_,
            ) || '';
            }
            @NextEvents;

        $Self->IsDeeply(
            \@NextEventsConverted,
            $Test->{ExpectedValue},
            "$Test->{Name} NextEventList() - Human TimeStamp Match",
        );
    }
    else {
        $Self->IsDeeply(
            \@NextEvents,
            [],
            "$Test->{Name} NextEventList()",
        );
    }
}

# PreviousEventList() tests
@Tests = (
    {
        Name    => 'No Params',
        Config  => {
            Silent => 1,
        },
        Success => 0,
    },
    {
        Name   => 'No Schedule',
        Config => {
            StartDate => '2015-12-12 00:00:00',
            Silent    => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Invalid Schedule minute (greater)',
        Config => {
            Schedule => '60 * * * * *',
            Silent   => 1,
        },
        Success => 0,
    },

    {
        Name   => 'Correct each 1 minute 0 secs',
        Config => {
            Schedule       => '*/1 * * * *',
            StartTimeStamp => '2015-03-05 14:15:00',
        },
        ExpectedValue => '2015-03-05 14:15:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 1 minute 30 secs',
        Config => {
            Schedule       => '*/1 * * * *',
            StartTimeStamp => '2015-03-05 14:15:30',
        },
        ExpectedValue => '2015-03-05 14:15:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 1 minute 59 secs',
        Config => {
            Schedule       => '*/1 * * * *',
            StartTimeStamp => '2015-03-05 14:15:59',
        },
        ExpectedValue => '2015-03-05 14:15:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 minutes',
        Config => {
            Schedule       => '*/2 * * * *',
            StartTimeStamp => '2015-03-05 14:15:59',
        },
        ExpectedValue => '2015-03-05 14:14:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 5 minutes',
        Config => {
            Schedule       => '*/5 * * * *',
            StartTimeStamp => '2015-03-05 14:16:00',
        },
        ExpectedValue => '2015-03-05 14:15:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 1 hour',
        Config => {
            Schedule       => '0 * * * *',
            StartTimeStamp => '2015-03-05 14:16:00',
        },
        ExpectedValue => '2015-03-05 14:00:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 hours',
        Config => {
            Schedule       => '0 */2 * * *',
            StartTimeStamp => '2015-03-05 13:59:50',
        },
        ExpectedValue => '2015-03-05 12:00:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 hours on minute 30 (1)',
        Config => {
            Schedule       => '30 */2 * * *',
            StartTimeStamp => '2015-03-05 14:16:00',
        },
        ExpectedValue => '2015-03-05 12:30:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 hours on minute 30 (2)',
        Config => {
            Schedule       => '30 */2 * * *',
            StartTimeStamp => '2015-03-05 14:36:00',
        },
        ExpectedValue => '2015-03-05 14:30:00',
        Success       => 1,
    },
    {
        Name   => 'Correct previous day at 11:30',
        Config => {
            Schedule       => '30 11 * * *',
            StartTimeStamp => '2015-01-05 10:36:00',
        },
        ExpectedValue => '2015-01-04 11:30:00',
        Success       => 1,
    },
    {
        Name   => 'Correct on day 12th at 11:30',
        Config => {
            Schedule       => '30 11 12 * *',
            StartTimeStamp => '2015-11-05 11:29:00',
        },
        ExpectedValue => '2015-10-12 11:30:00',
        Success       => 1,
    },
    {
        Name   => 'Correct previous month at 11:30',
        Config => {
            Schedule       => '30 11 5 * *',
            StartTimeStamp => '2015-03-05 10:36:00',
        },
        ExpectedValue => '2015-02-05 11:30:00',
        Success       => 1,
    },
    {
        Name   => 'Correct each 2 minutes (previous year)',
        Config => {
            Schedule       => '*/2 23 * * *',
            StartTimeStamp => '2016-01-01 00:00:00',
        },
        ExpectedValue => '2015-12-31 23:58:00',
        Success       => 1,
    },
);

for my $Test (@Tests) {

    if ( $Test->{Config}->{StartTimeStamp} ) {
        $Test->{Config}->{StartTime} = $TimeObject->TimeStamp2SystemTime(
            String => $Test->{Config}->{StartTimeStamp},
        );
    }

    my $EventSystemTime = $CronEventObject->PreviousEventGet( %{ $Test->{Config} } );

    if ( $Test->{Success} ) {

        $Self->Is(
            $TimeObject->SystemTime2TimeStamp(
                SystemTime => $EventSystemTime,
                )
                || '',
            $Test->{ExpectedValue},
            "$Test->{Name} PreviousEvent() - Human TimeStamp Match",
        );
    }
    else {
        $Self->Is(
            $EventSystemTime,
            undef,
            "$Test->{Name} NextEvent()",
        );
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
