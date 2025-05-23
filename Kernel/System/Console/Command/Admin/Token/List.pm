# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Token::List;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Token',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('List tokens.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Listing tokens...</yellow>\n");

    # get all tokens
    my %Tokens = %{$Kernel::OM->Get('Token')->GetAllTokens() || {}};

    foreach my $Token ( sort { $Tokens{$a} cmp $Tokens{$b} } keys %Tokens ) {
        $Self->Print(sprintf("%-11s\n%s\n\n", $Tokens{$Token} || '---', $Token));
    }

    $Self->Print("<green>Done</green>\n");
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
