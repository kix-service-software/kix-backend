# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::Logging::Default;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::Logging::Common);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Automation::Logging::Default - automation lib default logging module

=head1 SYNOPSIS

Handles default logging.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Log()

Log something

Example:
    my $Success = $Object->Log(
        UserID => 123,
    );

=cut

sub Log {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserID Priority Message)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my %LogData = %{$Param{LogData}||{}};

    my $ObjectIDString = $LogData{ObjectID};
    if ( IsHashRef($LogData{ObjectID}) || IsArrayRef($LogData{ObjectID}) ) {
        $ObjectIDString = $Kernel::OM->Get('JSON')->Encode(
            Data => $LogData{ObjectID},
        );
    }

    # log in DB automation log
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'INSERT INTO automation_log (job_id, run_id, macro_id, macro_action_id, object_id, priority, message, create_time, create_by) '
            . 'VALUES (?, ?, ?, ?, ?, ?, ?, current_timestamp, ?)',
        Bind => [
            \$LogData{JobID}, \$LogData{RunID}, \$LogData{MacroID}, \$LogData{MacroActionID}, 
            \$ObjectIDString, \$Param{Priority}, \$Param{Message}, \$Param{UserID}
        ],
    );

    # log in system log
    if ( !$Param{Silent} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => $Param{Priority},
            Message  => sprintf("%s (Job: %s, RunID: %s, Macro: %s, MacroAction: %s)", $Param{Message}, $LogData{JobInfo}, $LogData{RunID} || '', $LogData{MacroInfo}, $LogData{MacroActionInfo}),
        );
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
