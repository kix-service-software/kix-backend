# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::ExecPlan::EventBased;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Automation::ExecPlan::Common
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

Kernel::System::Automation::ExecPlan::EventBased - execution plan type for automation lib

=head1 SYNOPSIS

Provides a simple event based execution of jobs.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this execution plan module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Allows an event based execution of automation jobs. At least one event must be configured.'));
    $Self->AddOption(
        Name        => 'Event',
        Label       => Kernel::Language::Translatable('Event'),
        Description => Kernel::Language::Translatable('An array of events that should trigger the execution of the job.'),
        Required    => 1,
    );

    return;
}

=item Run()

Check if the criteria are met, based on the given event. Returns 1 if the job can be executed and 0 if not.

Example:
    my $CanExecute = $Object->Run(
        Event  => 'TicketCreate',
        Config => {},
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # just return in case it's not an event based check
    return 0 if !$Param{Event};

    # check needed stuff
    for (qw(Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    return 0 if !IsHashRefWithData($Param{Config}) || !IsArrayRefWithData($Param{Config}->{Event});

    my %RelevantEvents = map { $_ => 1 } @{$Param{Config}->{Event}};

    return $RelevantEvents{$Param{Event}} || 0;
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
