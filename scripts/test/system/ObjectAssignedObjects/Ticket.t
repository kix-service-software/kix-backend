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

# get needed objects for rollback
my $QueueObject   = $Kernel::OM->Get('Queue');
my $StateObject   = $Kernel::OM->Get('State');
my $TimeObject    = $Kernel::OM->Get('Time');
my $TypeObject    = $Kernel::OM->Get('Type');

# get actual needed objects
my $ConfigObject       = $Kernel::OM->Get('Config');
my $TicketObject       = $Kernel::OM->Get('Ticket');
my $ContactObject      = $Kernel::OM->Get('Contact');
my $UserObject         = $Kernel::OM->Get('User');
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $DFBackendObject    = $Kernel::OM->Get('DynamicField::Backend');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# prepare test data
my %TestData  = _PrepareData();
my @TicketIDs = map{ $_ } values %{ $TestData{Tickets} };

_CheckWithContactData();

_CheckWithUserData();

_CheckWithStaticData();

_DoNegativeTests();

# rollback transaction on database
$Helper->Rollback();

sub _PrepareData {

    # create customer user
    my $CustomerLogin = $Helper->TestUserCreate(
        Roles => [ 'Ticket Agent' ],
    );
    $Self->True(
        $CustomerLogin,
        'TestUserCreate - Customer',
    );
    my $CustomerUserID = $UserObject->UserLookup(
        UserLogin => $CustomerLogin,
    );
    my %CustomerContact = $ContactObject->ContactGet(UserID => $CustomerUserID);
    my %CustomerUser    = $UserObject->GetUserData(UserID => $CustomerContact{AssignedUserID});
    if (IsHashRefWithData(\%CustomerUser)) {
        $CustomerContact{User} = \%CustomerUser;
    } else {
        $Self->True(
            0, 'CustomerContactCreate - UserGet',
        );
    }

    # create other user
    my $OtherLogin = $Helper->TestUserCreate(
        Roles => [ 'Ticket Agent' ],
    );
    $Self->True(
        $OtherLogin,
        'TestUserCreate - Other',
    );
    my $OtherUserID = $UserObject->UserLookup(
        UserLogin => $OtherLogin,
    );
    my %OtherContact = $ContactObject->ContactGet(UserID => $OtherUserID);

    # create tickets
    # 1) create a ticket with ContactID, OrgansiationID of CustomerContact
    my $ContactOrgaTicketID = $TicketObject->TicketCreate(
        Title          => 'Customer ticket with customer contact and organisation',
        Queue          => 'Junk',
        Lock           => 'unlock',
        Priority       => '3 normal',
        State          => 'closed',
        OrganisationID => $CustomerContact{PrimaryOrganisationID},
        ContactID      => $CustomerContact{ID},
        OwnerID        => 1,
        UserID         => 1,
    );
    $Self->True(
        $ContactOrgaTicketID,
        'Create ContactOrgaTicket',
    );

    # 2) create a ticket with ContactID
    my $ContactTicketID = $TicketObject->TicketCreate(
        Title          => 'Customer ticket with customer contact',
        Queue          => 'Junk',
        Lock           => 'unlock',
        Priority       => '3 normal',
        State          => 'closed',
        OrganisationID => $OtherContact{PrimaryOrganisationID},
        ContactID      => $CustomerContact{ID},
        OwnerID        => 1,
        UserID         => 1,
    );
    $Self->True(
        $ContactTicketID,
        'Create ContactTicket',
    );

    # 3) create a ticket with OrgansiationID of CustomerContact
    my $OrgaTicketID = $TicketObject->TicketCreate(
        Title          => 'Customer ticket with customer organisation',
        Queue          => 'Junk',
        Lock           => 'unlock',
        Priority       => '3 normal',
        State          => 'closed',
        OrganisationID => $CustomerContact{PrimaryOrganisationID},
        ContactID      => $OtherContact{ID},
        OwnerID        => 1,
        UserID         => 1,
    );
    $Self->True(
        $OrgaTicketID,
        'Create OrgaTicket',
    );

    # 4) create a ticket with of other contact but customer contact as owner
    my $OtherTicketID = $TicketObject->TicketCreate(
        Title          => 'Ticket of other contact',
        Queue          => 'Junk',
        Lock           => 'unlock',
        Priority       => '3 normal',
        State          => 'closed',
        OrganisationID => $OtherContact{PrimaryOrganisationID},
        ContactID      => $OtherContact{ID},
        OwnerID        => $CustomerContact{AssignedUserID},
        UserID         => 1,
    );
    $Self->True(
        $OtherTicketID,
        'Create OtherTicket',
    );

    # 5) create a ticket with a selection dynamic field
    my $SelectionTicketID = $TicketObject->TicketCreate(
        Title          => 'Ticket with selection DF',
        Queue          => 'Junk',
        Lock           => 'unlock',
        Priority       => '3 normal',
        State          => 'open',
        OrganisationID => 1,
        ContactID      => 1,
        OwnerID        => $CustomerContact{AssignedUserID},
        UserID         => 1,
    );
    $Self->True(
        $SelectionTicketID,
        'Create SelectionTicket',
    );
    my $DFName  = 'CustomerAssignedTicketsSelection';
    my $DFValue = 'Key';
    my $SelectionDynamicFieldID = $DynamicFieldObject->DynamicFieldAdd(
        Name            => $DFName,
        Label           => $DFName,
        InternalField   => 1,
        FieldType       => 'Multiselect',
        ObjectType      => 'Ticket',
        Config          => {
            PossibleValues => {
                $DFValue =>  'Value',
                'Key2'   =>  'Value2'
            }
        },
        CustomerVisible => 1,
        ValidID         => 1,
        UserID          => 1,
    );
    $Self->True(
        $SelectionDynamicFieldID,
        'Create SelectionDynamicField',
    );
    my $SelectionDynamicField = $DynamicFieldObject->DynamicFieldGet(
        ID => $SelectionDynamicFieldID,
    );
    $Self->True(
        IsHashRefWithData($SelectionDynamicField) || 0,
        'Get SelectionDynamicField',
    );
    if (IsHashRefWithData($SelectionDynamicField)) {
        my $Success = $DFBackendObject->ValueSet(
            DynamicFieldConfig => $SelectionDynamicField,
            ObjectID           => $SelectionTicketID,
            Value              => [$DFValue],
            UserID             => 1,
        );
    }

    return (
        Tickets => {
            ContactOrgaTicketID => $ContactOrgaTicketID,
            ContactTicketID     => $ContactTicketID,
            OrgaTicketID        => $OrgaTicketID,
            OtherTicketID       => $OtherTicketID,
            SelectionTicketID   => $SelectionTicketID
        },
        CustomerContact => \%CustomerContact,
        OtherContactID  => $OtherContact{ID},
        DFName          => $DFName,
        DFValue         => $DFValue
    );
}

sub _CheckWithContactData {
    _SetConfig(
        'with Contact',
        <<"END",
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                "SearchAttributes": [
                    "ID"
                ]
            },
            "OrganisationID": {
                "SearchAttributes": [
                    "PrimaryOrganisationID", "OrganisationIDs"
                ]
            }
        }
    }
}
END
        1
    );

    # get cutomer tickets (ContactID or OrganisationID have to be from the given contact)
    my $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        3,
        'Customer ticket list should contain 3 tickets (contact data)',
    );
    $Self->ContainedIn(
        $TestData{Tickets}->{ContactOrgaTicketID},
        $TicketIDList,
        'List should contain ContactOrgaTicket (contact data)',
    );
    $Self->ContainedIn(
        $TestData{Tickets}->{ContactTicketID},
        $TicketIDList,
        'List should contain ContactTicket (contact data)',
    );
    $Self->ContainedIn(
        $TestData{Tickets}->{OrgaTicketID},
        $TicketIDList,
        'List should contain OrgTicket (contact data)',
    );
    $Self->NotContainedIn(
        $TestData{Tickets}->{OtherTicketID},
        $TicketIDList,
        'List should NOT contain OtherTicket (contact data)',
    );
    return 1;
}

sub _CheckWithUserData {

    _SetConfig(
        'with User of Contact',
        <<"END",
{
    "Contact": {
        "Ticket": {
            "OwnerID": {
                "SearchAttributes": [
                    "User.UserID"
                ]
            }
        }
    }
}
END
        1
    );

    # get cutomer tickets (OwnerID have to be from user of the given contact)
    my $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        2,
        'Customer ticket list should contain 2 tickets (user data)',
    );
    $Self->ContainedIn(
        $TestData{Tickets}->{OtherTicketID},
        $TicketIDList,
        'List should contain OtherTicket (user data)',
    );
    $Self->ContainedIn(
        $TestData{Tickets}->{SelectionTicketID},
        $TicketIDList,
        'List should contain SelectionTicketID (user data)',
    );
    $Self->NotContainedIn(
        $TestData{Tickets}->{ContactOrgaTicketID},
        $TicketIDList,
        'List should NOT contain ContactOrgaTicket (user data)',
    );

    return 1;
}

sub _CheckWithStaticData {

    _SetConfig(
        'with static for contact and dynamic field',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                "SearchStatic": [
                    $TestData{OtherContactID}
                ]
            },
            "DynamicField_$TestData{DFName}": {
                "SearchStatic": [
                    "$TestData{DFValue}"
                ]
            }
        }
    }
}
END
    );

    # get cutomer tickets (ContactID of other customer or DF matches (by static))
    my $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        3,
        'Customer ticket list should contain 3 tickets (static)',
    );
    $Self->ContainedIn(
        $TestData{Tickets}->{OtherTicketID},
        $TicketIDList,
        'List should contain OtherTicket (static)',
    );
    $Self->ContainedIn(
        $TestData{Tickets}->{SelectionTicketID},
        $TicketIDList,
        'List should contain SelectionTicketID (static)',
    );
    $Self->NotContainedIn(
        $TestData{Tickets}->{ContactOrgaTicketID},
        $TicketIDList,
        'List should NOT contain ContactOrgaTicket (static)',
    );

    # get cutomer tickets (ContactID of other customer or DF matches (by static),
    # like above, but do not use object (should NOT be required, if static is possible)
    my $TicketIDListWithout = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        # Object       => $TestData{CustomerContact},    # check without object
        UserID       => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDListWithout}),
        3,
        'Customer ticket list should contain 3 tickets (static - without object)',
    );

    # check with other contact, but allow more tickets
    _SetConfig(
        'with static for contact and dynamic field',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                "SearchStatic": [
                    $TestData{OtherContactID}
                ]
            },
            "StateType": {
                "SearchStatic": [
                    "Open"
                ]
            }
        }
    }
}
END
    );

    # get cutomer tickets (ContactID of other customer or DF matches (by static))
    $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        # ObjectIDList => \@TicketIDs  # do NOT consider only test tickets
    );
    $Self->True(
        (scalar(@{$TicketIDList}) >= 3) ? 1 : 0,
        'Customer ticket list should contain at least 3 tickets (static with "Open" statetype)',
    );
    $Self->ContainedIn(
        $TestData{Tickets}->{OtherTicketID},
        $TicketIDList,
        'List should contain OtherTicket (static with "Open" statetype)',
    );
    $Self->NotContainedIn(
        $TestData{Tickets}->{ContactOrgaTicketID},
        $TicketIDList,
        'List should NOT contain ContactOrgaTicket (because "closed" is not in "Open"',
    );

    return 1;
}

sub _DoNegativeTests {

    # negative (object value, without object) ---------------------------
    _SetConfig(
        'negative (object dependent config without object)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                "SearchAttributes": [
                    "ID"
                ]
            }
        }
    }
}
END
    );
    my $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType => 'Contact',
        UserID     => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        0,
        'Customer ticket list should be empty (missing object)',
    );

    # negative (unknown attribute) ---------------------------
    _SetConfig(
        'negative (unknown attribute)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "UnknownID": {
                "SearchStatic": [
                    5
                ]
            }
        }
    }
}
END
    );
    $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs,  # consider only test tickets
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        0,
        'Customer ticket list should be empty (unknown attribute)',
    );

    # negative (missing objecttype config) ---------------------------
    _SetConfig(
        'negative (missing objecttype config',
        <<"END"
{
    "Organisation": {
        "Ticket": {
            "OrganisationID": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        0,
        'Customer ticket list should be empty (missing objecttype config)',
    );

    # negative (missing ticket config) ---------------------------
    _SetConfig(
        'negative (missing ticket config)',
        <<"END"
{
    "Contact": {
        "FAQArticle": {
            "CustomerVisible": {
                "SearchStatic": [
                    1
                ]
            }
        }
    }
}
END
    );
    $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        0,
        'Customer ticket list should be empty (missing ticket config)',
    );

    # negative (empty ticket config) ---------------------------
    _SetConfig(
        'negative (missing ticket config)',
        <<"END"
{
    "Contact": {
        "Ticket": {}
    }
}
END
    );
    $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        0,
        'Customer ticket list should be empty (empty ticket config)',
    );

    # negative (empty attribute) ---------------------------
    _SetConfig(
        'negative (missing attribute)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {}
        }
    }
}
END
    );
    $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        0,
        'Customer ticket list should be empty (empty attribute)',
    );

    # negative (empty value) ---------------------------
    _SetConfig(
        'negative (empty value)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "StateID": {
                "SearchStatic": []
            }
        }
    }
}
END
    );
    $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        0,
        'Customer ticket list should be empty (empty value)',
    );

    # negative (empty config) ---------------------------
    _SetConfig(
        'negative (empty config)',
        q{}
    );
    $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs  # consider only test tickets
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        0,
        'Customer ticket list should be empty (empty config)',
    );

    # negative (invalid config, missing " and unnecessary ,) ---------------------------
    _SetConfig(
        'negative (invalid config)',
        <<"END"
{
    "Contact": {
        "Ticket": {
            "ContactID": {
                SearchStatic: [
                    $TestData{OtherContactID}
                ]
            },
        },
    }
}
END
    );
    $TicketIDList = $TicketObject->GetAssignedTicketsForObject(
        ObjectType   => 'Contact',
        Object       => $TestData{CustomerContact},
        UserID       => 1,
        ObjectIDList => \@TicketIDs,  # consider only test tickets
        Silent       => 1
    );
    $Self->Is(
        scalar(@{$TicketIDList}),
        0,
        'Customer ticket list should be empty (invalid config)',
    );

    return 1;
}

sub _SetConfig {
    my ($Name, $Config, $DoCheck) = @_;

    $ConfigObject->Set(
        Key   => 'AssignedObjectsMapping',
        Value => $Config,
    );

    # check config
    if ($DoCheck) {
        my $MappingString = $ConfigObject->Get('AssignedObjectsMapping');
        $Self->True(
            IsStringWithData($MappingString) || 0,
            "AssignedObjectsMapping - get config string ($Name)",
        );

        my $NewConfig = 0;
        if ($MappingString && $MappingString eq $Config) {
            $NewConfig = 1;
        }
        $Self->True(
            $NewConfig,
            "AssignedObjectsMapping - mapping is new value",
        );
    }
    return 1;
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
