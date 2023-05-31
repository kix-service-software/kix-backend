# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Daemon::Reload;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Reload daemon processes.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Reloading system daemons...</yellow>\n");

    my $CacheObject = $Kernel::OM->Get('Cache');

    my @Keys = $CacheObject->GetKeysForType(
        Type  => 'Daemon',
    );

    foreach my $Key ( @Keys ) {
        my $Cache = $CacheObject->Get(
            Type      => 'Daemon',
            Key       => $Key,
            UseRawKey => 1
        );
        if ( !IsHashRefWithData($Cache) ) {
            $Self->PrintError("Unable to trigger reload for daemon process\n");
            next;
        }

        $Cache->{Reload} = 1;

        $CacheObject->Set(
            Type      => 'Daemon',
            Key       => $Key,
            Value     => $Cache,
            UseRawKey => 1,
        );

        $Self->Print("triggered reload for daemon PID $Cache->{PID} on host $Cache->{Host}\n");
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
