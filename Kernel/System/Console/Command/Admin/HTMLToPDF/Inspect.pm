# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::HTMLToPDF::Inspect;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    "HTMLToPDF"
);

use Kernel::System::VariableCheck qw(:all);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Inspect convert definition.');
    $Self->AddOption(
        Name        => 'name',
        Description => "(unique) Name of the convert definition.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'id',
        Description => "(required) id of the convert definition.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $PrintObject = $Kernel::OM->Get('HTMLToPDF');

    $Self->Print("<yellow>Inspect Convert Definition...</yellow>\n");

    my $Name = $Self->GetOption('name') || q{};
    my $ID   = $Self->GetOption('id')   || q{};

    if ( !$Name && !$ID ) {
        $Self->Print("<red>No name or id is given!</red>\n");
        return $Self->ExitCodeOk();
    }

    my %Data = $PrintObject->TemplateGet(
        Name   => $Name,
        ID     => $ID,
        UserID => 1
    );

    print STDOUT Data::Dumper::Dumper(\%Data);

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
