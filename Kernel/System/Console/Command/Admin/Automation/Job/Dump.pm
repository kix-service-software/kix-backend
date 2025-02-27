# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Automation::Job::Dump;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Automation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Dump a job.');
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

    my $Code = $Kernel::OM->Get('Automation')->JobDump(
        ID     => $Self->{JobID},
        UserID => 1,
    );

    if ( $Code ) {
        $Self->Print($Code);
        return $Self->ExitCodeOk();
    }

    $Self->PrintError("Can't dump job");
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
