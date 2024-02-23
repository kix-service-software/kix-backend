# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Token::Inspect;

use strict;
use warnings;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Token',
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

    my $Payload = $Kernel::OM->Get('Token')->ExtractToken(
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
