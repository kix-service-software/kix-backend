# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::Macro::Ticket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Automation::Macro::Common
);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Automation::Macro::Ticket - macro type for automation lib

=head1 SYNOPSIS

Handles ticket based macros.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

Run this macro module.

Example:
    my $Result = $Object->Run(
        ObjectID  => 123,
        ExecOrder => [],
        UserID    => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ExecOrder UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # FIXME: use given instance
    my $AutomationObject = $Param{AutomationInstance} || $Kernel::OM->Get('Automation');

    # execute all macro action given in the execution order attribute
    foreach my $MacroActionID ( @{$Param{ExecOrder}} ) {
        my $Result = $AutomationObject->MacroActionExecute(
            ID       => $MacroActionID,
            ObjectID => $Param{ObjectID},              # give the anonymous ObjectID as well for "Common" macro actions
            TicketID => $Param{ObjectID},
            UserID   => $Param{UserID},

            # FIXME: add instance if job was triggerd by event (ExecuteJobsForEvent)
            AutomationInstance => $Param{AutomationInstance},
            AdditionalData     => $Param{AdditionalData}
        );
        # we don't need error handling here since MacroActionExecute did that already and we don't have to abort here
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
