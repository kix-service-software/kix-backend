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
        LogPrefix => 'framework_update-to-build-2317',
    },
);

use vars qw(%INC);

_UpdateTimeAccounting();

sub _UpdateTimeAccounting {
    my ( $Self, %Param ) = @_;

    my @TimeAccountingIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'TimeAccounting',
        Result     => 'ARRAY',
        UserID     => 1,
        UserType   => 'Agent'
    );

    if ( @TimeAccountingIDs ) {
        for my $TimeAccountingID ( @TimeAccountingIDs ) {
            my %TimeAccounting = $Kernel::OM->Get('TimeAccounting')->TimeAccountingGet(
                TimeAccountingID => $TimeAccountingID
            );

            $Kernel::OM->Get('TimeAccounting')->TimeAccountingUpdate(
                %TimeAccounting,
                TimeAccountingID   => $TimeAccountingID,
                ExecutingContactID => $Kernel::OM->Get('Contact')->ContactLookup( UserID => $TimeAccounting{CreateBy} ),
                StartTime          => $TimeAccounting{CreateTime},
                IsInvoiced         => 0,
                UserID             => 1
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
