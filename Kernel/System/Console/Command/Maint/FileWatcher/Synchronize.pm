# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Maint::FileWatcher::Synchronize;

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . "/Kernel/cpan-lib";

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Document::FS',
    'Log',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('KIX-FileWatcher');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # create common objects
    $Self->{LogObject}        = $Kernel::OM->Get('Log');
    $Self->{FileSystemObject} = $Kernel::OM->Get('Document::FS');

    $Self->{LogObject}->Log( Priority => 'notice', Message => "FileWatcher started." );

    $Self->{FileSystemObject}->_MetaImport();
    $Self->{FileSystemObject}->_MetaSync();

    # $Self->{LogObject}->Log( Priority => 'notice', Message => "FileWatcher syncronized ".$FileCount." files using metadata file." );

    $Self->{LogObject}->Log( Priority => 'notice', Message => "FileWatcher finished." );

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
