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

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $TicketObject = $Kernel::OM->Get('Ticket');
my $ContactObject = $Kernel::OM->Get('Contact');
my $OrgaObject = $Kernel::OM->Get('Organisation');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my @ContactIDs;
my %OrgIDs;

# add two customer users
for ( 1 .. 2 ) {
    my $UserRand = "ContactLogin + " . $Helper->GetRandomID();
    my $OrgRand = "Orga " . $Helper->GetRandomID();
    my $OrgID = $OrgaObject->OrganisationAdd(
        Number  => $OrgRand,
        Name    => $OrgRand,
        ValidID => 1,
        UserID  => 1,
    );

    my $ContactID = $ContactObject->ContactAdd(
        Source                => 'Contact',
        Firstname             => 'Firstname Test',
        Lastname              => 'Lastname Test',
        Email                 => $UserRand . '-Email@example.com',
        PrimaryOrganisationID => $OrgID,
        OrganisationIDs       => [ $OrgID ],
        ValidID               => 1,
        UserID                => 1,
    );

    push @ContactIDs, $ContactID;
    $OrgIDs{$ContactID} = $OrgID;

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
            Title          => 'My ticket created by Agent A',
            Queue          => 'Junk',
            Lock           => 'unlock',
            Priority       => '3 normal',
            State          => 'open',
            ContactID      => $ContactID,
            OrganisationID => $OrgIDs{$ContactID},
            OwnerID        => 1,
            UserID         => 1,
        );

        $Self->True(
            $TicketID,
            "Ticket created for test - $ContactID - $TicketID",
        );
        push @TicketIDs, $TicketID;
        push @{ $CustomerIDTickets{$ContactID} }, $TicketID;

    }
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
        "Test TicketSearch for ContactID: \'$ContactID\'",
    );

}

# test search by OrganisationID, when OrganisationID have special chars or whitespaces
# result is empty

for my $ContactID (@ContactIDs) {

    my %User              = $ContactObject->ContactGet( ID => $ContactID );
    my $CustomerIDRaw     = $User{PrimaryOrganisationID};
    my @ReturnedTicketIDs = $TicketObject->TicketSearch(
        Result         => 'ARRAY',
        OrganisationID => $CustomerIDRaw,
        UserID         => 1,
        OrderBy        => ['Up'],
        SortBy         => ['TicketNumber'],
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
