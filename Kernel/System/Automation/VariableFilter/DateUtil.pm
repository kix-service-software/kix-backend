# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::VariableFilter::DateUtil;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use base qw(
    Kernel::System::Automation::VariableFilter::Common
);

our @ObjectDependencies = (
    'Time'
);

sub GetFilterHandler {
    my ( $Self, %Param ) = @_;

    my %Handler = (
        'DateUtil.BOB' => \&_BOB,
        'DateUtil.EOB' => \&_EOB,
        'DateUtil.UnixTime' => \&_UnixTime,
        'DateUtil.TimeStamp' => \&_TimeStamp,
        'DateUtil.Calc' => \&_Calc,
    )
}

sub _BOB {
    my ( $Self, %Param ) = @_;

    # TODO: get relevant ticket/sla calender?
    my $Calendar;

    # handle unix time
    if ($Param{Value} =~ m/^\d+$/) {
        $Param{Value} = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $Param{Value}
        );
    }

    my $BOB = $Kernel::OM->Get('Time')->BOB(
        String   => $Param{Value},
        Calendar => $Calendar,
        Silent   => $Param{Silent},
    );

    return $BOB ? $BOB : $Param{Value};
}

sub _EOB {
    my ( $Self, %Param ) = @_;

    # TODO: get relevant ticket/sla calender?
    my $Calendar;

    # handle unix time
    if ($Param{Value} =~ m/^\d+$/) {
        $Param{Value} = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $Param{Value}
        );
    }

    my $EOB = $Kernel::OM->Get('Time')->EOB(
        String   => $Param{Value},
        Calendar => $Calendar
    );

    return $EOB ? $EOB : $Param{Value};
}

sub _UnixTime {
    my ( $Self, %Param ) = @_;

    my $UnixTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => $Param{Value}
    );
    return $UnixTime ? $UnixTime : $Param{Value};
}

sub _TimeStamp {
    my ( $Self, %Param ) = @_;

    my $TimeStamp = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
        SystemTime => $Param{Value}
    );

    return $TimeStamp ? $TimeStamp : $Param{Value};
}

sub _Calc {
    my ( $Self, %Param ) = @_;

    # handle unix time
    if ($Param{Value} =~ m/^\d+$/) {
        $Param{Value} = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $Param{Value}
        );
    }

    my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => $Param{Value} . ($Param{Parameter} ? " $Param{Parameter}" : ''),
        Silent => $Param{Silent},
    );

    my $Value;
    if ($SystemTime) {
        $Value = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $SystemTime,
        );
    }

    return $Value ? $Value : $Param{Value};
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


