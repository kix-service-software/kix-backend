# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my @CommandFiles = $Kernel::OM->Get('Main')->DirectoryRead(
    Directory => $Kernel::OM->Get('Config')->Get('Home') . '/Kernel/System/Console/Command',
    Filter    => '*.pm',
    Recursive => 1,
);

my @Commands;

for my $CommandFile (@CommandFiles) {
    $CommandFile =~ s{^.*(Kernel/System.*)[.]pm$}{$1}xmsg;
    $CommandFile =~ s{/+}{::}xmsg;
    push @Commands, $CommandFile;
}

for my $Command (@Commands) {

    my $CommandObject = $Kernel::OM->Get($Command);

    $Self->True(
        $CommandObject,
        "$Command could be created",
    );

    $Self->Is(
        $CommandObject->{_ConfigureSuccessful},
        1,
        "$Command was correctly configured",
    );
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
