# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
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

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
my $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

$Kernel::OM->Get('Kernel::Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my @ContactIDs;

# add two customer users
for ( 1 .. 2 ) {
    my $UserRand = "ContactLogin + " . $Helper->GetRandomID();

    my $ContactID = $ContactObject->ContactAdd(
        Source         => 'Contact',
        UserFirstname  => 'Firstname Test',
        UserLastname   => 'Lastname Test',
        UserCustomerID => "CustomerID-$UserRand",
        UserLogin      => $UserRand,
        UserEmail      => $UserRand . '-Email@example.com',
        UserPassword   => 'some_pass',
        ValidID        => 1,
        UserID         => 1,
    );
    push @ContactIDs, $ContactID;

    $Self->True(
        $ContactID,
        "ContactAdd() - $ContactID",
    );
}

my @TicketIDs;
my %CustomerIDTickets;
for my $ContactID (@ContactIDs) {
    for ( 1 .. 3 ) {

        # create a new ticket
        my $TicketID = $TicketObject->TicketCreate(
            Title        => 'My ticket created by Agent A',
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'open',
            ContactID    => $ContactID,
            OrganisationID => "CustomerID-$ContactID",
            OwnerID      => 1,
            UserID       => 1,
        );

        $Self->True(
            $TicketID,
            "Ticket created for test - $ContactID - $TicketID",
        );
        push @TicketIDs, $TicketID;
        push @{ $CustomerIDTickets{$ContactID} }, $TicketID;

    }
}

# test search by ContactLognRaw, when ContactLogin have special chars or whitespaces

for my $ContactID (@ContactIDs) {

    my %Contact = $ContactObject->ContactGet(
        ID => $ContactID,
    );
    my @ReturnedTicketIDs = $TicketObject->TicketSearch(
        Result               => 'ARRAY',
        ContactLoginRaw      => $Contact{Login},
        UserID               => 1,
        OrderBy              => ['Up'],
        SortBy               => ['TicketNumber'],
    );

    $Self->IsDeeply(
        \@ReturnedTicketIDs,
        $CustomerIDTickets{$ContactID},
        "Test TicketSearch for CustomerLoginRaw: \'$Contact{Login}\'",
    );

}

# test search by ContactLogin, when ContactLogin have special chars or whitespaces
# result is empty

for my $ContactID (@ContactIDs) {

    my @ReturnedTicketIDs = $TicketObject->TicketSearch(
        Result            => 'ARRAY',
        ContactID         => $ContactID,
        UserID            => 1,
        OrderBy           => ['Up'],
        SortBy            => ['TicketNumber'],
    );

    $Self->IsNotDeeply(
        \@ReturnedTicketIDs,
        $CustomerIDTickets{$ContactID},
        "Test TicketSearch for CustomerLoginRaw: \'$ContactID\'",
    );

}

# test search by CustomerIDRaw, when CustomerID have special chars or whitespaces

for my $ContactID (@ContactIDs) {

    my %User              = $ContactObject->ContactGet( ID => $ContactID );
    my $CustomerIDRaw     = $User{UserCustomerID};
    my @ReturnedTicketIDs = $TicketObject->TicketSearch(
        Result        => 'ARRAY',
        CustomerIDRaw => $CustomerIDRaw,
        UserID        => 1,
        OrderBy       => ['Up'],
        SortBy        => ['TicketNumber'],
    );

    $Self->IsDeeply(
        \@ReturnedTicketIDs,
        $CustomerIDTickets{$ContactID},
        "Test TicketSearch for CustomerIDRaw \'$CustomerIDRaw\'",
    );
}

# test search by CustomerID, when CustomerID have special chars or whitespaces
# result is empty

for my $ContactID (@ContactIDs) {

    my %User              = $ContactObject->ContactGet( ID => $ContactID );
    my $CustomerIDRaw     = $User{PrimaryOrganisationID};
    my @ReturnedTicketIDs = $TicketObject->TicketSearch(
        Result        => 'ARRAY',
        OrgaisationID => $CustomerIDRaw,
        UserID        => 1,
        OrderBy       => ['Up'],
        SortBy        => ['TicketNumber'],
    );

    $Self->IsNotDeeply(
        \@ReturnedTicketIDs,
        $CustomerIDTickets{$ContactID},
        "Test TicketSearch for CustomerIDRaw \'$CustomerIDRaw\'",
    );
}

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
