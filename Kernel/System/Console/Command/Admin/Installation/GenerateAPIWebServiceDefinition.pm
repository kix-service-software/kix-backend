# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Installation::GenerateAPIWebServiceDefinition;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Installation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Generate a web service definition file for the application REST API');
    $Self->AddOption(
        Name        => 'api-version',
        Description => "The version of REST API web service to generate (i.e. v1).",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/^.*$/smx,
    );

    $Self->AddOption(
        Name        => 'output-file',
        Description => "The name of the file to create.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/^.*$/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Generating web service definition file for \"".$Self->GetOption('api-version')."\"...</yellow>\n");

    my $Version    = $Self->GetOption('api-version');
    my $OutputFile = $Self->GetOption('output-file');

    # get all plugins
    my $WebServiceDefinition = $Kernel::OM->Get('Installation')->GetAPIWebServiceDefinition(
        Version => $Version
    );

    if ( !$WebServiceDefinition ) {
        $Self->PrintError("Something went wrong. No API definition found.");
        return $Self->ExitCodeError();
    }

    my $Result = $Kernel::OM->Get('Main')->FileWrite(
        Location => $OutputFile,
        Content  => \$WebServiceDefinition,
    );
    if ( !$Result ) {
        $Self->PrintError("Something went wrong. Could not write output file.");
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
