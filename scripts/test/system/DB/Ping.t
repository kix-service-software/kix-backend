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

# get DB object
my $DBObject = $Kernel::OM->Get('DB');

my @TestsMofifiers = (
    {
        Name        => 'Autoconnect off - No connect after object creation',
        Command     => '',
        Success     => 0,
        AutoConnect => 0,
    },
    {
        Name        => 'Autoconnect off - Connected',
        Command     => 'Connect',
        Success     => 1,
        AutoConnect => 0,
    },
    {
        Name        => 'Autoconnect off - Diconnected',
        Command     => 'Disconnect',
        Success     => 0,
        AutoConnect => 0,
    },
    {
        Name        => 'Autoconnect off - Connected again',
        Command     => 'Connect',
        Success     => 1,
        AutoConnect => 0,
    },
    {
        Name        => 'Autoconnect off - Diconnected again',
        Command     => 'Disconnect',
        Success     => 0,
        AutoConnect => 0,
    },
    {
        Name        => 'Autoconnect on - Ping should connect automatically',
        Command     => '',
        Success     => 1,
        AutoConnect => 1,
    },
    {
        Name        => 'Autoconnect on - Ping should connect again after disconnected',
        Command     => 'Disconnect',
        Success     => 1,
        AutoConnect => 1,
    },
    {
        Name        => 'Autoconnect on - Already connected',
        Command     => 'Connect',
        Success     => 1,
        AutoConnect => 1,
    },
    {
        Name        => 'Autoconnect on - Already connected',
        Command     => 'Connect',
        Success     => 1,
        AutoConnect => 1,
    },
);

for my $TestCase (@TestsMofifiers) {

    my $Command = $TestCase->{Command} || '';
    if ($Command) {
        $DBObject->$Command();
    }

    my $Success = $DBObject->Ping(
        AutoConnect => $TestCase->{AutoConnect},
    );

    if ( $TestCase->{Success} ) {
        $Self->True(
            $Success,
            "$TestCase->{Name} - Ping() with true",
        );
    }
    else {
        $Self->False(
            $Success,
            "$TestCase->{Name} - Ping() with false",
        );
    }
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
