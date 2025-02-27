# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::Migrate::Run;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Migration',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Migrate the supported data from another tool.');
    $Self->AddOption(
        Name        => 'source',
        Description => "The source to migrate the data from.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'source-id',
        Description => "And identifier for this specific source.",
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
        Description => "Import the objects of a specific type, i.e. ticket. Separate multiple types by comma. If not given, all supported objects will be migrated.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^.*$/smx,
    );

    $Self->AddOption(
        Name        => 'mapping-file',
        Description => "The JSON file to use for mappings (use an existing object instead of creating a new one).",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^.*$/smx,
    );

    $Self->AddOption(
        Name        => 'filter',
        Description => "A filter expression. The format and content depends on the selected source.",
        Required    => 0,
        HasValue    => 1,
        Multiple    => 1,
        ValueRegex  => qr/^.*$/smx,
    );

    $Self->AddOption(
        Name        => 'workers',
        Description => "Number of parallel processes to use for the mass objects like tickets etc. Default: 1",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );

    $Self->AddOption(
        Name        => 'debug',
        Description => "Enable debug output in kix log (MinimumLogLevel has to be \"debug\")",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Migrating data...</yellow>\n");

    my $Result = $Kernel::OM->Get('Migration')->MigrationStart(
        Source       => $Self->GetOption('source'),
        SourceID     => $Self->GetOption('source-id'),
        Options      => $Self->GetOption('options'),
        ObjectType   => $Self->GetOption('type'),
        Filter       => $Self->GetOption('filter'),
        MappingFile  => $Self->GetOption('mapping-file'),
        Workers      => $Self->GetOption('workers'),
        Debug        => $Self->GetOption('debug'),
    );

    if ( !$Result ) {
        $Self->PrintError("Something went wrong. Update aborted. Please check the KIX log for details.");
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
