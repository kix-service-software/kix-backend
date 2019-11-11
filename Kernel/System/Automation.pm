# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation;

use strict;
use warnings;

use base qw(
    Kernel::System::Automation::ExecPlan
    Kernel::System::Automation::Job
    Kernel::System::Automation::Macro
    Kernel::System::Automation::MacroAction
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Automation - automation lib

=head1 SYNOPSIS

All role functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AutomationObject = $Kernel::OM->Get('Kernel::System::Automation');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Automation';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item LogError()

Logs an error message.

Example:
    my $Success = $Object->LogError(
        Referrer => $Object,
        Message  => '...',
        UserID   => 123,
    );

=cut

sub LogError {
    my ( $Self, %Param ) = @_;
    my $JobID;
    my $MacroID;
    my $MacroActionID;

    # check needed stuff
    for (qw(Message UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    if ( $Param{Referrer} ) {
        $JobID = $Param{Referrer}->{JobID};
        $MacroID = $Param{Referrer}->{MacroID};
        $MacroActionID = $Param{Referrer}->{MacroActionID};        
    }

    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'INSERT INTO automation_log (job_id, macro_id, macro_action_id, priority, message, create_time, create_by) '
            . 'VALUES (?, ?, ?, \'error\', ?, current_timestamp, ?)',
        Bind => [
            \$JobID, \$MacroID, \$MacroActionID, \$Param{Message}, \$Param{UserID}
        ],
    );

    # get job info
    my $JobInfo = '-';
    if ( $JobID ) {
        my %Job = $Self->JobGet(
            ID => $JobID
        );
        $JobInfo = "$Job{Name} ($JobID)";
    }

    # get macro info
    my $MacroInfo = '-';
    if ( $MacroID ) {
        my %Macro = $Self->MacroGet(
            ID => $MacroID
        );
        $MacroInfo = "$Macro{Name} ($MacroID)";
    }

    # get macro info
    my $MacroActionInfo = '-';
    if ( $MacroActionID ) {
        my %MacroAction = $Self->MacroActionGet(
            ID => $MacroActionID
        );
        $MacroActionInfo = "$MacroAction{Name} ($MacroActionID)";
    }

    # log in system log
    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'error',
        Message  => "$Param{Message} (Job: $JobInfo, Macro: $MacroInfo, MacroAction: $MacroActionInfo)",
    );

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
