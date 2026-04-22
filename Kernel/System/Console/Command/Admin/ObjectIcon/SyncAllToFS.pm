# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::ObjectIcon::SyncAllToFS;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

use MIME::Base64 qw(encode_base64);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Main',
    'SysConfig',
    'Time',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Synchronize icons to filesystem.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ObjectIconObject = $Kernel::OM->Get('ObjectIcon');

    $Self->Print("<yellow>Synchronizing icons to $ObjectIconObject->{Config}->{Directory}...</yellow>\n");

    my $Success = $ObjectIconObject->SyncAllToFS();
    if ( !$Success ) {
        $Self->PrintError("Can't synchronize icons to filesystem.");
        return $Self->ExitCodeError();
    }

    $Self->Print("\n<green>Done.</green>\n");

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
