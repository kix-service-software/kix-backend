# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Token::Inspect;

use strict;
use warnings;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Token',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Inspect token.');
    $Self->AddOption(
        Name        => 'token',
        Description => "The token to inspect.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Inspecting token...</yellow>\n");

    my $Payload = $Kernel::OM->Get('Kernel::System::Token')->ExtractToken(
        Token => $Self->GetOption('token'),
    );

    if ( !IsHashRefWithData($Payload) ) {
        $Self->PrintError("Token does not exists or unable to extract token payload.");
        return $Self->ExitCodeError();
    }

    $Self->Print("\n".Dumper($Payload)."\n");

    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
