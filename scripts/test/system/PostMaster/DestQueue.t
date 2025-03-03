# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

use Kernel::System::EmailParser;
use Kernel::System::PostMaster::DestQueue;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# add SystemAddress 1
my $SystemAddressEmail1    = $Helper->GetRandomID() . '@example.com';
my $SystemAddressRealname1 = "KIX-Team 1";
my $SystemAddressID1       = $Kernel::OM->Get('SystemAddress')->SystemAddressAdd(
    Name     => $SystemAddressEmail1,
    Realname => $SystemAddressRealname1,
    Comment  => $SystemAddressEmail1,
    ValidID  => 1,
    UserID   => 1,
);

# add SystemAddress 2
my $SystemAddressEmail2    = $Helper->GetRandomID() . '@example.com';
my $SystemAddressRealname2 = "KIX-Team 2";
my $SystemAddressID2       = $Kernel::OM->Get('SystemAddress')->SystemAddressAdd(
    Name     => $SystemAddressEmail2,
    Realname => $SystemAddressRealname2,
    Comment  => $SystemAddressEmail2,
    QueueID  => 2,
    ValidID  => 1,
    UserID   => 1,
);

# prepare unknown address
my $UnknownAddressEmail = $Helper->GetRandomID() . '@example.com';

# prepare DestQueue object
my $ParserObject = Kernel::System::EmailParser->new(
    Mode => 'Standalone',
);
my $DestQueueObject = Kernel::System::PostMaster::DestQueue->new(
    ParserObject => $ParserObject,
);

## Test for GetQueueID ##
my @TestsGetQueueID = (
    {
        Name            => 'To: UnknownAddress => PostmasterDefaultQueue (1)',
        Params => {
            'To'   => $UnknownAddressEmail,
        },
        QueueID => 1
    },
    {
        Name            => 'Resent-To: SystemAddress1 => PostmasterDefaultQueue (1)',
        Params => {
            'Resent-To'   => $SystemAddressEmail1,
        },
        QueueID => 1
    },
    {
        Name            => 'Envelope-To: SystemAddress2 => Queue of SystemAddress2 (2)',
        Params => {
            'Envelope-To' => $SystemAddressEmail2,
        },
        QueueID => 2
    },
    {
        Name            => 'To: SystemAddress1 / Cc: SystemAddress2 => Queue of SystemAddress2 (2)',
        Params => {
            'To' => $SystemAddressEmail1,
            'Cc' => $SystemAddressEmail2,
        },
        QueueID => 2
    },
    {
        Name            => 'To: SystemAddress2 / Cc: SystemAddress1 => Queue of SystemAddress2 (2)',
        Params => {
            'To' => $SystemAddressEmail2,
            'Cc' => $SystemAddressEmail1,
        },
        QueueID => 2
    },
    {
        Name            => 'To: UnknownAddress / Cc: SystemAddress2 => Queue of SystemAddress2 (2)',
        Params => {
            'To' => $UnknownAddressEmail,
            'Cc' => $SystemAddressEmail2,
        },
        QueueID => 2
    },
    {
        Name            => 'To: SystemAddress1, SystemAddress2 => Queue of SystemAddress2 (2)',
        Params => {
            'To' => $SystemAddressEmail1 . ',' . $SystemAddressEmail2,
        },
        QueueID => 2
    },
    {
        Name            => 'To: UnknownAddress, SystemAddress1, SystemAddress2 => Queue of SystemAddress2 (2)',
        Params => {
            'To' => $UnknownAddressEmail . ',' . $SystemAddressEmail1 . ',' . $SystemAddressEmail2,
        },
        QueueID => 2
    },
);

for my $Test (@TestsGetQueueID) {
    my $QueueID = $DestQueueObject->GetQueueID(
        Params => $Test->{Params}
    );

    $Self->Is(
        $QueueID,
        $Test->{QueueID},
        'GetQueueID() - ' . $Test->{Name},
    );
}
## EO Test for GetQueueID ##

## Test for GetTrustedQueueID ##
my @GetTrustedQueueIDTests = (
    {
        Name    => 'X-KIX-Queue not set',
        Params  => {},
        QueueID => undef
    },
    {
        Name    => 'X-KIX-Queue undefined',
        Params  => {
            'X-KIX-Queue' => undef,
        },
        QueueID => undef
    },
    {
        Name    => 'X-KIX-Queue: Service Desk',
        Params  => {
            'X-KIX-Queue' => 'Service Desk',
        },
        QueueID => 1
    },
    {
        Name    => 'X-KIX-Queue: Junk',
        Params  => {
            'X-KIX-Queue' => 'Junk',
        },
        QueueID => 3
    },
    {
        Name    => 'X-KIX-Queue: Unknown',
        Params  => {
            'X-KIX-Queue' => 'Unknown',
        },
        QueueID => undef
    },
);

for my $Test ( @GetTrustedQueueIDTests ) {
    my $QueueID = $DestQueueObject->GetTrustedQueueID(
        Params => $Test->{Params}
    );

    $Self->Is(
        $QueueID,
        $Test->{QueueID},
        'GetTrustedQueueID() - ' . $Test->{Name},
    );
}
## EO Test for GetTrustedQueueID ##

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
