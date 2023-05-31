# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::Migrate::CountObjects;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Migration',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Count the number of supported objects typed from another tool.');
    $Self->AddOption(
        Name        => 'source',
        Description => "The source to get the data from.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'options',
        Description => "The options needed for the specific source.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'type',
        Description => "Only count the given object types, i.e. ticket. Separate multiple types by comma. If not given, all supported objects will be counted.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^.*$/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Counting objects...</yellow>\n");

    my %Result = $Kernel::OM->Get('Migration')->CountMigratableObjects(
        Source      => $Self->GetOption('source'),
        Options     => $Self->GetOption('options'),
        ObjectType  => $Self->GetOption('type'),
    );

    $Self->Print("Type                           Count\n");
    $Self->Print("------------------------------ --------\n");

    foreach my $Type ( sort keys %Result ) {
        $Self->Print(sprintf("%30s %8i\n", $Type, $Result{$Type}));
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
