# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Dev::Tools::Database::XMLExecute;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'DB',
    'Main',
    'XML',

);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Convert a KIX database XML file to SQL and execute it in the current database.');
    $Self->AddArgument(
        Name        => 'source-path',
        Description => "Specify the location of the database XML file to be executed.",
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );

    $Self->AddOption(
        Name        => 'sql-part',
        Description => "Generate only 'pre' or 'post' SQL",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^(pre|post)$/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $SourcePath = $Self->GetArgument('source-path');
    if ( !-r $SourcePath ) {
        die "Source file $SourcePath does not exist / is not readable.\n";
    }
    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $XML = $Kernel::OM->Get('Main')->FileRead(
        Location => $Self->GetArgument('source-path'),
    );
    if ( !$XML ) {
        $Self->PrintError("Could not read XML source.");
        return $Self->ExitCodeError();
    }
    my @XMLArray = $Kernel::OM->Get('XML')->XMLParse( String => $XML );
    my @SQL = $Kernel::OM->Get('DB')->SQLProcessor(
        Database => \@XMLArray,
    );
    if ( !@SQL ) {
        $Self->PrintError("Could not generate SQL.");
        return $Self->ExitCodeError();
    }

    my @SQLPost = $Kernel::OM->Get('DB')->SQLProcessorPost();

    my $SQLPart = $Self->GetOption('sql-part') || 'both';
    my @SQLCollection;
    if ( $SQLPart eq 'both' ) {
        push @SQLCollection, @SQL, @SQLPost;
    }
    elsif ( $SQLPart eq 'pre' ) {
        push @SQLCollection, @SQL;
    }
    elsif ( $SQLPart eq 'post' ) {
        push @SQLCollection, @SQLPost;
    }

    for my $SQL (@SQLCollection) {
        $Self->Print("$SQL\n");
        my $Success = $Kernel::OM->Get('DB')->Do( SQL => $SQL );
        if ( !$Success ) {
            $Self->PrintError("Database action failed. Exiting.");
            return $Self->ExitCodeError();
        }
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
