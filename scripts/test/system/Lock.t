# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get lock object
my $LockObject = $Kernel::OM->Get('Lock');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my @Names = sort $LockObject->LockViewableLock(
    Type => 'Name',
);

$Self->IsDeeply(
    \@Names,
    [ 'unlock' ],
    'LockViewableLock()',
);

my @Tests = (
    {
        Name   => 'Lookup - lock',
        Input  => 'lock',
        Result => 1,
    },
    {
        Name   => 'Lookup - unlock',
        Input  => 'unlock',
        Result => 1,
    },
    {
        Name   => 'Lookup - unlock_not_extsits',
        Input  => 'unlock_not_exists',
        Result => 0,
        Silent => 1,
    },
);

for my $Test (@Tests) {

    my $LockID = $LockObject->LockLookup(
        Lock   => $Test->{Input},
        Silent => $Test->{Silent},
    );

    if ( $Test->{Result} ) {

        $Self->True( $LockID, $Test->{Name} );

        my $Lock = $LockObject->LockLookup( LockID => $LockID );

        $Self->Is(
            $Test->{Input},
            $Lock,
            $Test->{Name},
        );
    }
    else {
        $Self->False( $LockID, $Test->{Name} );
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
