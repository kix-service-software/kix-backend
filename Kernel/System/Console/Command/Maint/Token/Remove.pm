# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Maint::Token::Remove;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Token',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Remove token.');
    $Self->AddOption(
        Name        => 'token',
        Description => "The token to remove.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'all',
        Description => "Remove all tokens (except AccessTokens)",
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Removing token(s)...</yellow>\n");

    my $All = $Self->GetOption('all') || 0;
    my $Token = $Self->GetOption('token') || '';

    if ( !$All && !$Token ) {
        $Self->PrintError("Please specify token to remove or declare all tokens to be removed by using the --all parameter.");
        return $Self->ExitCodeError();
    }

    if ($All) {
        my $Result = $Kernel::OM->Get('Kernel::System::Token')->CleanUp();
    }
    elsif ($Token) {
        my $Result = $Kernel::OM->Get('Kernel::System::Token')->RemoveToken(
            Token => $Token,
        );        
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
