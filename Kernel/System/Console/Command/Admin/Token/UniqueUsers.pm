# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Token::UniqueUsers;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Token',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Count unique users.');

    $Self->AddOption(
        Name        => 'from',
        Description => "The start time of the count.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'to',
        Description => "The end time of the count.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'since',
        Description => "The time span into the past.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>counting unique users...</yellow>\n");

    my %UniqueUsers = $Kernel::OM->Get('Token')->CountUniqueUsers(
        StartTime => $Self->GetOption('from'),
        EndTime   => $Self->GetOption('to'),
        Since     => $Self->GetOption('since'),
    );

    $Self->Print("Context     Count\n");
    $Self->Print("---------- ------\n");

    foreach my $Context ( sort keys %UniqueUsers ) {
        $Self->Print(sprintf("%-10s %6i\n", $Context, $UniqueUsers{$Context}->{Count}));
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
