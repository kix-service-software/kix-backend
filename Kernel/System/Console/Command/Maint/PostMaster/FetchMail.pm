# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::PostMaster::FetchMail;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Log',
    'MailAccount',
    'PID',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Execute fetchmail using the daemon task config.');
    $Self->AddOption(
        Name        => 'task-name',
        Description => "Use the config from this daemon task. If omitted \"FetchMail\" will be used. PLEASE NOTE: you need to activate the task config at first.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr{^.+$}smx,
    );

    return;
}

sub PreRun {
    my ($Self) = @_;

    # validate given config
    my $TaskName = $Self->GetOption('task-name') || 'FetchMail';

    my $Config = $Kernel::OM->Get('Config')->Get('Daemon::SchedulerCronTaskManager::Task');
    if ( !$Config->{$TaskName} ) {
        die "The given task \"$TaskName\" doesn't exist or is inactive.\n";
    }

    $Self->{TaskConfig} = $Config->{$TaskName};

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Executing fetchmail...</yellow>\n\n");

    my $ModuleObject;
    eval {
        $ModuleObject = $Kernel::OM->Get( $Self->{TaskConfig}->{Module} );
    };
    if ( !$ModuleObject ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Cannot create a new Object for Module: '$Self->{TaskConfig}->{Module}'!",
        );

        return;
    }

    my $Function = $Self->{TaskConfig}->{Function};

    # Check if the module provide the required function.
    return if !$ModuleObject->can($Function);

    my @Parameters = @{ $Self->{TaskConfig}->{Params} || [] };

    my $Result;

    eval {
        # Run function on the module with the specified parameters in Params
        $Result = $ModuleObject->$Function(
            @Parameters,
        );
    };

    if (!$Result) {
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
