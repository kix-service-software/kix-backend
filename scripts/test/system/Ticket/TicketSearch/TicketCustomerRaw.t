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

my @CustomerLogins;

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
    push @CustomerLogins, $ContactID;

    $Self->True(
        $ContactID,
        "ContactAdd() - $ContactID",
    );
}

my @TicketIDs;
my %CustomerIDTickets;
for my $ContactLogin (@CustomerLogins) {
    for ( 1 .. 3 ) {

        # create a new ticket
        my $TicketID = $TicketObject->TicketCreate(
            Title        => 'My ticket created by Agent A',
            Queue        => 'Raw',
            Lock         => 'unlock',
            Priority     => '3 normal',
            State        => 'open',
            Contact => $ContactLogin,
            CustomerID   => "CustomerID-$ContactLogin",
            OwnerID      => 1,
            UserID       => 1,
        );

        $Self->True(
            $TicketID,
            "Ticket created for test - $ContactLogin - $TicketID",
        );
        push @TicketIDs, $TicketID;
        push @{ $CustomerIDTickets{$ContactLogin} }, $TicketID;

    }
}

# test search by ContactLoginRaw, when ContactLogin have special chars or whitespaces

for my $ContactLogin (@CustomerLogins) {

    my @ReturnedTicketIDs = $TicketObject->TicketSearch(
        Result               => 'ARRAY',
        ContactLoginRaw => $ContactLogin,
        UserID               => 1,
        OrderBy              => ['Up'],
        SortBy               => ['TicketNumber'],
    );

    $Self->IsDeeply(
        \@ReturnedTicketIDs,
        $CustomerIDTickets{$ContactLogin},
        "Test TicketSearch for CustomerLoginRaw: \'$ContactLogin\'",
    );

}

# test search by ContactLogin, when ContactLogin have special chars or whitespaces
# result is empty

for my $ContactLogin (@CustomerLogins) {

    my @ReturnedTicketIDs = $TicketObject->TicketSearch(
        Result            => 'ARRAY',
        ContactLogin => $ContactLogin,
        UserID            => 1,
        OrderBy           => ['Up'],
        SortBy            => ['TicketNumber'],
    );

    $Self->IsNotDeeply(
        \@ReturnedTicketIDs,
        $CustomerIDTickets{$ContactLogin},
        "Test TicketSearch for CustomerLoginRaw: \'$ContactLogin\'",
    );

}

# test search by CustomerIDRaw, when CustomerID have special chars or whitespaces

for my $ContactLogin (@CustomerLogins) {

    my %User              = $ContactObject->ContactGet( User => $ContactLogin );
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
        $CustomerIDTickets{$ContactLogin},
        "Test TicketSearch for CustomerIDRaw \'$CustomerIDRaw\'",
    );
}

# test search by CustomerID, when CustomerID have special chars or whitespaces
# result is empty

for my $ContactLogin (@CustomerLogins) {

    my %User              = $ContactObject->ContactGet( User => $ContactLogin );
    my $CustomerIDRaw     = $User{UserCustomerID};
    my @ReturnedTicketIDs = $TicketObject->TicketSearch(
        Result     => 'ARRAY',
        CustomerID => $CustomerIDRaw,
        UserID     => 1,
        OrderBy    => ['Up'],
        SortBy     => ['TicketNumber'],
    );

    $Self->IsNotDeeply(
        \@ReturnedTicketIDs,
        $CustomerIDTickets{$ContactLogin},
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
