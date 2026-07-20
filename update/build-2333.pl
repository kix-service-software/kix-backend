#!/usr/bin/perl
# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/plugins';
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-2333',
    },
);

use vars qw(%INC);

_CleanUpClientRegistration();

sub _CleanUpClientRegistration {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $ClientID = "kix-agent-portal-development-userid";

    my %ClientRegistration = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationGet(
        ClientID => $ClientID,
        Silent   => 1,
    );

    if ( %ClientRegistration ) {
        my $Result = $Kernel::OM->Get('ClientRegistration')->ClientRegistrationDelete(
            ClientID => $ClientID
        );

        if ( !$Result ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Unable to remove client ${ClientID}"
            );
        }
    }

    return 1;
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
