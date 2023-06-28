# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

# get needed objects
my $ConfigObject         = $Kernel::OM->Get('Config');
my $LoopProtectionObject = $Kernel::OM->Get('PostMaster::LoopProtection');

# define needed variable
my $RandomID = $Kernel::OM->Get('UnitTest::Helper')->GetRandomID();

for my $Module (qw(DB FS)) {

    $ConfigObject->Set(
        Key   => 'LoopProtectionModule',
        Value => "Kernel::System::PostMaster::LoopProtection::$Module",
    );

    # get rand sender address
    my $UserRand1 = 'example-user' . $RandomID . '@example.com';

    my $Check = $LoopProtectionObject->Check( To => $UserRand1 );

    $Self->True(
        $Check || 0,
        "#$Module - Check() - $UserRand1",
    );

    for ( 1 .. 42 ) {
        my $SendEmail = $LoopProtectionObject->SendEmail( To => $UserRand1 );
        $Self->True(
            $SendEmail || 0,
            "#$Module - SendEmail() - #$_ ",
        );
    }

    $Check = $LoopProtectionObject->Check( To => $UserRand1 );

    $Self->False(
        $Check || 0,
        "#$Module - Check() - $UserRand1",
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
