# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Metric::Exporter::API;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Export {
    my ( $Self, $Metrics ) = @_;

    if ( !IsArrayRef($Metrics) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No metric list given!"
        );
        return;
    }

    my $Output;
    foreach my $Metric ( @{$Metrics} ) {
        if ( $Metric->{MetricType} ne 'API' ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Metric is not of type \"API\"!"
            );
            return;
        }

        my $DateTime = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $Metric->{StartTime}
        );

        my $Parameters = '';
        if ( $Metric->{Parameters} ) {
            $Parameters = $Kernel::OM->Get('JSON')->Encode(
                Data => $Metric->{Parameters}
            );
        }

        $Output .= sprintf "%s\t%i\t%s\t%s\t%s\t%i\t%i\t%s\t%i\t%s\t%s\n", 
            $DateTime, 
            $Metric->{ProcessID}, 
            $Metric->{RequestID} || '-', 
            $Metric->{UserID} || '-',
            $Metric->{UserType} || '-',
            $Metric->{Duration}*1000, 
            $Metric->{OutBytes} || 0, 
            $Metric->{RequestMethod}, 
            $Metric->{HTTPCode}, 
            $Metric->{Resource}, 
            $Parameters;
    }

    return $Output;
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
