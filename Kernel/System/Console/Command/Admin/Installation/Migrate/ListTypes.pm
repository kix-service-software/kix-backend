# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::Migrate::ListTypes;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Migration',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List supported types of the given source.');
    $Self->AddOption(
        Name        => 'source',
        Description => "The source to list the supported types for.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing supported types of the given data source...</yellow>\n");

    my @TypeList = $Kernel::OM->Get('Migration')->MigrationSupportedTypeList(
        Source => $Self->GetOption('source'),
    );
    if ( !@TypeList ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No registered types for source "' . $Self->GetOption('source') . '" available!',
        );
        return;
    }

    foreach my $Type ( sort @TypeList ) {
        $Self->Print($Type."\n");
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
