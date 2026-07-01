# --
# Modified version of the work: Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

use Kernel::System::PostMaster;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create test queue
my $QueueID = $Kernel::OM->Get('Queue')->QueueAdd(
    Name            => 'NewTestQueue',
    ValidID         => 1,
    FollowUpID      => 3,                # create new ticket
    SystemAddressID => 1,
    UserID          => 1
);
$Self->True(
    $QueueID,
    "Create test queue",
);

# enable strict followup
my $Success = $Helper->ConfigSettingChange(
    Key   => 'PostMaster::StrictFollowUp',
    Value => 1,
);
$Self->True(
    $Success,
    "Enable PostMaster::StrictFollowUp",
);

# set PostmasterDefaultQueue
$Success = $Helper->ConfigSettingChange(
    Key   => 'PostmasterDefaultQueue',
    Value => 'NewTestQueue',
);
$Self->True(
    $Success,
    "Set PostmasterDefaultQueue",
);

# get sample mail for new ticket and process it
my $LocationNew = $Kernel::OM->Get('Config')->Get('Home')
    . "/scripts/test/system/sample/PostMaster/KIX2018-16378-NewTicket.box";
my $ContentRefNew = $Kernel::OM->Get('Main')->FileRead(
    Location => $LocationNew,
    Mode     => 'binmode',
    Result   => 'ARRAY',
);
my @ReturnNew;
{
    my $PostMasterObject = Kernel::System::PostMaster->new(
        Email => $ContentRefNew,
    );

    @ReturnNew = $PostMasterObject->Run();
}

my $TicketIDNew = $ReturnNew[0][1];
$Self->IsDeeply(
    \@ReturnNew,
    [
        [ 1, $TicketIDNew ]
    ],
    'First mail handled as expected',
);

$Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
    State     => 'closed',
    TicketID  => $TicketIDNew,
    UserID    => 1,
);
$Self->True(
    $Success,
    'Closed ticket',
);

# get sample mail for followup and process it
my $LocationFollowUp = $Kernel::OM->Get('Config')->Get('Home')
    . "/scripts/test/system/sample/PostMaster/KIX2018-16378-FollowUp.box";
my $ContentRefFollowUp = $Kernel::OM->Get('Main')->FileRead(
    Location => $LocationFollowUp,
    Mode     => 'binmode',
    Result   => 'ARRAY',
);
my @ReturnFollowUp;
{
    my $PostMasterObject = Kernel::System::PostMaster->new(
        Email => $ContentRefFollowUp,
    );

    @ReturnFollowUp = $PostMasterObject->Run();
}

my $TicketIDFollowUp = $ReturnFollowUp[0][1];
$Self->IsDeeply(
    \@ReturnFollowUp,
    [
        [ 3, $TicketIDFollowUp ],
        [ 6, $TicketIDNew ],
        [ 6, $TicketIDNew ],
        [ 6, $TicketIDNew ],
    ],
    'Second mail handled as expected',
);


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
