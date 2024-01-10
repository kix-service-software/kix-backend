# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Automation::Job::Delete;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Automation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete a job.');
    $Self->AddOption(
        Name        => 'name',
        Description => 'Name of the job.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{JobName} = $Self->GetOption('name');

    # check job
    $Self->{JobID} = $Kernel::OM->Get('Automation')->JobLookup( Name => $Self->{JobName} );
    if ( !$Self->{JobID} ) {
        die "Job $Self->{JobName} does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Delete a job...</yellow>\n");

    my $Success = $Kernel::OM->Get('Automation')->JobDelete(
        ID     => $Self->{JobID},
        UserID => 1,
    );

    if ($Success) {
        $Self->Print("<green>Done</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->PrintError("Can't delete job");
    return $Self->ExitCodeError();
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
