# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# create test contacts
my $ContactID = $Helper->TestContactCreate();
$Self->True(
    $ContactID,
    'Test contact create',
);
my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID
);
# without primary
my $ContactIDWithoutPrimary = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => 'ContactWithoutPrimary',
    Lastname              => 'ContactWithoutPrimary',
    Email                 => 'ContactWithoutPrimary@localunittest.com',
    ValidID               => 1,
    UserID                => 1,
);
my %ContactWithoutPrimary = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactIDWithoutPrimary
);

# create test orga
my $OrgaNumber = 'knowOrga-' . $Helper->GetRandomID();
my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationAdd(
    Number  => $OrgaNumber,
    Name    => $OrgaNumber,
    ValidID => 1,
    UserID  => 1,
);

# create some ticket with different contact and orga combination and check if there correctly set
my @Tests = (
    {
        # ticket should have given contact (ID) and its orga (primary)
        Title          => 'known contact (ID), no orga',
        ContactID      => $ContactID,
        TicketContactID      => $ContactID,
        TicketOrganisationID => $Contact{PrimaryOrganisationID}
    },
    {
        # ticket should have given contact and given orga and orga should be added to contact
        Title          => 'known contact (ID), known orga (ID)',
        ContactID      => $ContactID,
        OrganisationID => $OrganisationID,
        TicketContactID      => $ContactID,
        TicketOrganisationID => $OrganisationID,
        CheckContactOrgIDs   => 1
    },
    {
        # ticket should have given contact and a newly created orga and orga should be added to contact
        Title          => 'known contact (ID), not existent orga (use as number => new)',
        ContactID      => $ContactID,
        OrganisationID => 999999,
        TicketContactID      => $ContactID,
        CheckNewOrganisation => 1,
        CheckContactOrgIDs   => 1
    },
    {
        # ticket should have given contact and a newly created orga and orga should be added to contact (OrganisationIDs)
        Title          => 'known contact (ID), unknown orga (use also as number => new)',
        ContactID      => $ContactID,
        OrganisationID => 'unknownOrga-' . $Helper->GetRandomID() . '@testcorp.com',
        TicketContactID      => $ContactID,
        CheckNewOrganisation => 1,
        CheckContactOrgIDs   => 1
    },
    {
        # ticket should have no contact and no orga
        Title                => 'not existent contact (ID), known orga (ID)',
        ContactID            => 999999,
        OrganisationID       => $OrganisationID,
        TicketOrganisationID => $OrganisationID
    },
    {
        # ticket should have no contact and no orga
        Title                => 'not existent contact (ID), unknown orga (no new)',
        ContactID            => 999999,
        OrganisationID       => 'org@test.com',
        CheckNewOrganisation => 1,
    },
    {
        # ticket should have no contact and no orga
        Title          => 'no contact, no orga'
    },
    {
        # ticket should have no contact and no orga
        Title                => 'no contact, known orga (ID)',
        OrganisationID       => $OrganisationID,
        TicketOrganisationID => $OrganisationID
    },
    {
        # ticket should have given contact and its orga (primary)
        Title          => 'known contact (email), no orga',
        ContactID      => $Contact{Email},
        TicketContactID      => $ContactID,
        TicketOrganisationID => $Contact{PrimaryOrganisationID}
    },
    {
        # ticket should have given contact and a newly created orga and orga should be added to contact (OrganisationIDs)
        Title          => 'known contact (email), unknown orga',
        ContactID      => $Contact{Email},
        OrganisationID => 'unknownOrga-' . $Helper->GetRandomID() . '@testcorp.com',
        TicketContactID      => $ContactID,
        CheckNewOrganisation => 1,
        CheckContactOrgIDs   => 1
    },
    # ToDo:Creating contacts without an organization currently no longer creates an organization with the ContactEmail. Contacts without organization are now possible.
    # {
    #     # ticket should have given contact (which has no primary) and a no newly created orga (by contact email) and orga should be primary of contact
    #     Title          => 'known contact (email without primary), no orga',
    #     ContactID      => $ContactWithoutPrimary{Email},
    #     TicketContactID      => $ContactIDWithoutPrimary,
    #     CheckNewOrganisation => ,
    #     CheckContactPrimary  => 1,
    #     CheckContactOrgIDs   => 1
    # },
    {
        # ticket should have given contact (which has now a primary) and known orga and orga should be added to contact (OrganisationIDs)
        Title          => 'known contact (email without primary), known orga',
        ContactID      => $ContactWithoutPrimary{Email},
        OrganisationID => $OrganisationID,
        TicketContactID      => $ContactIDWithoutPrimary,
        TicketOrganisationID => $OrganisationID,
        CheckContactOrgIDs   => 1
    },
    # ToDo:Creating contacts without an organization currently no longer creates an organization with the ContactEmail. Contacts without organization are now possible.
    {
        # ticket should have a newly created contact and a newly created orga (by contact email) and orga should be primary of contact
        Title          => 'unknown contact (email), no orga',
        ContactID      => 'unknowncontact-' . $Helper->GetRandomID() . '@testcorp.com',
        CheckNewContact      => 1,
        CheckNewOrganisation => 0,
        CheckContactPrimary  => 0
    },
    {
        # ticket should have a newly created contact and known orga and orga should be primary of contact
        Title          => 'unknown contact (email), known orga',
        ContactID      => 'unknowncontact-' . $Helper->GetRandomID() . '@testcorp.com',
        OrganisationID => $OrganisationID,
        TicketOrganisationID => $OrganisationID,
        CheckNewContact      => 1,
        CheckContactPrimary  => 1
    },
    {
        # ticket should have a newly created contact and known orga (by number) and orga should be primary of contact
        Title          => 'unknown contact (email), known orga (number)',
        ContactID      => 'unknowncontact-' . $Helper->GetRandomID() . '@testcorp.com',
        OrganisationID => $OrgaNumber,
        TicketOrganisationID => $OrganisationID,
        CheckNewContact      => 1,
        CheckContactPrimary  => 1
    },
    {
        # ticket should have a newly created contact and a newly created orga and orga should be primary of contact
        Title          => 'unknown contact, unknown orga',
        ContactID      => 'unknownContact-' . $Helper->GetRandomID() . '@testcorp.com',
        OrganisationID => 'unknownOrga-' . $Helper->GetRandomID() . '@testcorp.com',
        CheckNewContact      => 1,
        CheckNewOrganisation => 1,
        CheckContactPrimary  => 1
    },
);

my $Counter = 1;
for my $Test (@Tests) {
    my $TestPrefix  = ">> Test $Counter:";
    my $TestPostfix = "(\"$Test->{Title}\")";

    my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title          => $Test->{Title},
        Queue          => 'Junk',
        Lock           => 'unlock',
        Priority       => '3 normal',
        State          => 'open',
        ContactID      => $Test->{ContactID},
        OrganisationID => $Test->{OrganisationID},
        OwnerID        => 1,
        UserID         => 1
    );
    $Self->True(
        $TicketID,
        "$TestPrefix TicketCreate() $TestPostfix"
    );
    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID => $TicketID
    );
    $Self->True(
        IsHashRefWithData(\%Ticket) || 0,
        "$TestPrefix TicketGet() $TestPostfix"
    );
    if (IsHashRefWithData(\%Ticket)) {

        # (if) has ticket relevant contact
        if ($Test->{TicketContactID}) {
            $Self->Is(
                $Ticket{ContactID},
                $Test->{TicketContactID},
                "$TestPrefix Check set contact id $TestPostfix",
            );
        }

        # (elsif) has ticket a new created contact
        elsif ($Test->{CheckNewContact}) {
            $Self->True(
                $Ticket{ContactID},
                "$TestPrefix Check set contact id (new contact?) $TestPostfix"
            );
            if ($Ticket{ContactID}) {
                # is email the given ContactID value (which should be used as email for new contact)
                my $ContactEMail = $Kernel::OM->Get('Contact')->ContactLookup(
                    ID     => $Ticket{ContactID},
                    Silent => 1
                );
                $Self->Is(
                    $ContactEMail,
                    $Test->{ContactID},
                    "$TestPrefix Check set contact id (new contact?) - email check $TestPostfix",
                );
                # use id for further tests (e.g. CheckContactPrimary)
                if ($ContactEMail && $Test->{ContactID} && $ContactEMail eq $Test->{ContactID}) {
                    $Test->{ContactID} = $Ticket{ContactID};
                }
            }
        }

        # (else) if not given contact and not a new contact, ticket should has no contact at all
        else {
            $Self->False(
                $Ticket{ContactID},
                "$TestPrefix Check set contact id (undef) $TestPostfix"
            );
        }

        # is ticket organisation primary of contact
        if ($Test->{CheckContactPrimary}) {
            $Self->True(
                $Ticket{ContactID},
                "$TestPrefix Check primary organisation - contact set $TestPostfix"
            );
            if ($Ticket{ContactID}) {
                my %CheckContact = $Kernel::OM->Get('Contact')->ContactGet(
                    ID => $Ticket{ContactID}
                );
                $Self->Is(
                    $CheckContact{PrimaryOrganisationID},
                    $Ticket{OrganisationID},
                    "$TestPrefix Check primary organisation $TestPostfix",
                );
                # set relevant test value for further tests (e.g. CheckNewOrganisation)
                if (IsHashRefWithData(\%CheckContact) && !$Test->{OrganisationID}) {
                    $Test->{OrganisationID} = $CheckContact{Email};
                }
            }
        }

        # (if) has ticket relevant orgaisation
        if ($Test->{TicketOrganisationID}) {
            $Self->Is(
                $Ticket{OrganisationID},
                $Test->{TicketOrganisationID},
                "$TestPrefix Check set organisation id $TestPostfix",
            );
        }

        # (elsif) has ticket a new created organisation
        elsif ($Test->{CheckNewOrganisation}) {
            $Self->True(
                $Ticket{OrganisationID},
                "$TestPrefix Check set organisation id (new orga?) $TestPostfix"
            );
            if ($Ticket{OrganisationID}) {
                # is number the given OrganisationID value (which should be used as number for new orga)
                my $OrganisationNumber = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                    ID     => $Ticket{OrganisationID},
                    Silent => 1
                );
                $Self->Is(
                    $OrganisationNumber,
                    $Test->{OrganisationID},
                    "$TestPrefix Check set organisation id (new orga?) - number check $TestPostfix",
                );
                # use id for further tests (e.g. CheckContactOrgIDs)
                if ($OrganisationNumber && $Test->{OrganisationID} && $OrganisationNumber eq $Test->{OrganisationID}) {
                    $Test->{OrganisationID} = $Ticket{OrganisationID};
                }
            }
        }

        # (else) if not given a known orga and not new orga, ticket should has no orga at all
        else {
            $Self->False(
                $Ticket{OrganisationID},
                "$TestPrefix Check set organisation id (undef) $TestPostfix"
            );
        }

        # check organisation ids of ticket contact
        if ($Test->{CheckContactOrgIDs} && $Ticket{ContactID} && $Test->{OrganisationID}) {
            my %CheckContact = $Kernel::OM->Get('Contact')->ContactGet(
                ID => $Ticket{ContactID}
            );
            if (IsHashRefWithData(\%CheckContact)) {
                my $ContactHasOrga = grep {$_ == $Test->{OrganisationID}} @{ $CheckContact{OrganisationIDs} };
                $Self->True(
                    $ContactHasOrga,
                    "$TestPrefix Check contact: has orga in orga ids $TestPostfix"
                );
            }
        }
    }

    $Counter++;
}

# check valid/invalid contact with same email
# disable unique check
$Kernel::OM->Get('Config')->Set(
    Key   => 'ContactEmailUniqueCheck',
    Value => 0,
);
my $FirstContactID = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => 'First',
    Lastname              => 'Contact',
    Email                 => 'same@testemail.com',
    ValidID               => 1,
    UserID                => 1
);
my $SecondContactID = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname             => 'Second',
    Lastname              => 'Contact',
    Email                 => 'same@testemail.com',
    ValidID               => 1,
    UserID                => 1
);
$Self->True(
    $FirstContactID && $SecondContactID ? 1 : 0,
    "Same Email: ContactAdd()"
);

if ($FirstContactID && $SecondContactID) {
    _SameEmailContactCheck('first contact', $FirstContactID);

    # set first contact invalid
    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(ID => $FirstContactID);
    if (IsHashRefWithData(\%Contact)) {
        $Kernel::OM->Get('Contact')->ContactUpdate(%Contact, ValidID => 2, UserID => 1);

        # create new ticket, now second contact should be used, because first one is invalid
        _SameEmailContactCheck('second contact', $SecondContactID);

        # set also second contact invalid
        %Contact = $Kernel::OM->Get('Contact')->ContactGet(ID => $SecondContactID);
        if (IsHashRefWithData(\%Contact)) {
            $Kernel::OM->Get('Contact')->ContactUpdate(%Contact, ValidID => 2, UserID => 1);

            # create new ticket, now first contact should be used again, because second one is also invalid
            _SameEmailContactCheck('first contact again', $FirstContactID);
        }
    }
}

sub _SameEmailContactCheck {
    my ($Suffix, $CheckContactID) = @_;

    my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title          => 'Same Email Valid/Invalid Test',
        Queue          => 'Junk',
        Lock           => 'unlock',
        Priority       => '3 normal',
        State          => 'closed',
        ContactID      => 'same@testemail.com',
        OwnerID        => 1,
        UserID         => 1
    );
    $Self->True(
        $TicketID,
        "Same Email: TicketCreate() - $Suffix"
    );
    if ($TicketID) {
        my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID => $TicketID
        );
        $Self->True(
            IsHashRefWithData(\%Ticket) || 0,
            "Same Email: TicketGet() - $Suffix"
        );
        if (IsHashRefWithData(\%Ticket)) {
            $Self->Is(
                $Ticket{ContactID},
                $CheckContactID,
                "Same Email: ticket contact check - $Suffix"
            );
        }
    }
}

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
