# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
my $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');
my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $RandomID = $Helper->GetRandomID();

# add two users
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my @Tests = (
    {
        Name                    => 'Regular User',
        ContactLogin       => "johndoe$RandomID",
        CustomerID              => "johndoe$RandomID",
        CustomerEmail           => "johndoe$RandomID\@email.com",
        ContactLoginUpdate => "johndoe2$RandomID",
        CustomerIDUpdate        => "johndoe2$RandomID",
    },
    {
        Name                    => 'Update to special characters',
        ContactLogin       => "max$RandomID",
        CustomerID              => "max$RandomID",
        CustomerEmail           => "max$RandomID\@email.com",
        ContactLoginUpdate => "max + & # () $RandomID",
        CustomerIDUpdate        => "max + & # () $RandomID",
    },
    {
        Name                    => 'Update from special characters',
        ContactLogin       => "moritz + & # () $RandomID",
        CustomerID              => "moritz + & # () $RandomID",
        CustomerEmail           => "moritz$RandomID\@email.com",
        ContactLoginUpdate => "moritz$RandomID",
        CustomerIDUpdate        => "moritz$RandomID",
    },
);

for my $Test (@Tests) {

    my $ContactID = $ContactObject->ContactAdd(
        Firstname  => 'Firstname Test',
        Lastname   => 'Lastname Test',
        CustomerID => $Test->{CustomerID},
        Login      => $Test->{ContactLogin},
        Email      => $Test->{CustomerEmail},
        Password   => 'some_pass',
        ValidID    => 1,
        UserID     => 1,
    );

    $Self->True(
        $ContactID,
        "$Test->{Name} - customer created",
    );

    my $TicketID = $TicketObject->TicketCreate(
        Title        => 'Some Ticket_Title',
        Queue        => 'Raw',
        Lock         => 'unlock',
        Priority     => '3 normal',
        State        => 'closed successful',
        CustomerNo   => $Test->{CustomerID},
        Contact => $Test->{ContactLogin},
        OwnerID      => 1,
        UserID       => 1,
    );

    $Self->True(
        $TicketID,
        "$Test->{Name} - ticket created",
    );

    my $Update = $ContactObject->ContactUpdate(
        ID         => $Test->{ContactLogin},
        Firstname  => 'Firstname Test',
        Lastname   => 'Lastname Test',
        CustomerID => $Test->{CustomerIDUpdate},
        Login      => $Test->{ContactLoginUpdate},
        Email      => $Test->{CustomerEmail},
        Password   => 'some_pass',
        ValidID    => 1,
        UserID     => 1,
    );

    $Self->True(
        $Update,
        "$Test->{Name} - customer updated",
    );

    $Self->Is(
        $TicketObject->TicketSearch(
            Result        => 'COUNT',
            CustomerIDRaw => $Test->{CustomerIDUpdate},
            UserID        => 1,
            OrderBy       => ['Up'],
            SortBy        => ['TicketNumber'],
        ),
        1,
        "$Test->{Name} - ticket was updated with new CustomerID $Test->{CustomerIDUpdate}"
    );

    $Self->Is(
        $TicketObject->TicketSearch(
            Result               => 'COUNT',
            ContactLoginRaw => $Test->{ContactLoginUpdate},
            UserID               => 1,
            OrderBy              => ['Up'],
            SortBy               => ['TicketNumber'],
        ),
        1,
        "$Test->{Name} - ticket was updated with new CustomerID $Test->{ContactLoginUpdate}"
    );

}

# cleanup is done by RestoreDatabase

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
