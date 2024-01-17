# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $TestUser    = $Helper->TestUserCreate(
    Roles => [
        'Ticket Agent'
    ]
);

my %User = $Kernel::OM->Get('User')->GetUserData(
    User  => $TestUser
);

my $TestContactID = $Helper->TestContactCreate();

my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $TestContactID
);

my %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
    ID => $Contact{PrimaryOrganisationID}
);

my $TicketID = _CreateTicket(
    Contact  => \%Contact,
    User     => \%User,
    TestName => '_CreateTicket(): ticket create'
);

my @UnitTests;

# placeholder of KIX_CONTACT_
for my $Attribute ( sort keys %Contact ) {

    # ToDo: Handling of OrganisationIDs (ARRAY)
    if ( $Attribute eq 'OrganisationIDs' ) {
        # INDEX:
        # for my $Index ( keys @{$Contact{OrganisationIDs}} ) {
        #     push(
        #         @UnitTests,
        #         {
        #             TestName  => "Placeholder: <KIX_CONTACT_" . $Attribute . "_" . $Index . ">",
        #             TicketID  => $TicketID,
        #             Test      => "<KIX_CONTACT_" . $Attribute . "_" . $Index . ">",
        #             Expection => defined $Contact{OrganisationIDs}[$Index] ? $Contact{OrganisationIDs}[$Index] : q{-},
        #         }
        #     );
        # }
    }
    # ToDo: Handling of Preferences
    elsif ( $Attribute eq 'Preferences' ) {
        # for my $Pref ( sort keys %{$Contact{$Attribute}} ) {
        #     push(
        #         @UnitTests,
        #         {
        #             TestName  => "Placeholder: <KIX_CONTACT_" . $Attribute . "_" . $Pref . ">",
        #             TicketID  => $TicketID,
        #             Test      => "<KIX_CONTACT_" . $Attribute . "_" . $Pref . ">",
        #             Expection => defined $Contact{$Attribute}->{$Pref} ? $Contact{$Attribute}->{$Pref} : q{-},
        #         }
        #     );
        # }
    }
    else {
        push(
            @UnitTests,
            {
                TestName  => "Placeholder: <KIX_CONTACT_" . $Attribute . ">",
                TicketID  => $TicketID,
                Test      => "<KIX_CONTACT_" . $Attribute . ">",
                Expection => defined $Contact{$Attribute} ? $Contact{$Attribute} : q{-},
            }
        );
    }
}

# placeholder of KIX_ORG_
for my $Attribute ( sort keys %Organisation ) {
    if ( $Attribute eq 'Preferences' ) {
        for my $Pref ( sort keys %{$Organisation{$Attribute}} ) {
            push(
                @UnitTests,
                {
                    TestName  => "Placeholder: <KIX_ORG_" . $Attribute . "_" . $Pref . ">",
                    TicketID  => $TicketID,
                    Test      => "<KIX_ORG_" . $Attribute . "_" . $Pref . ">",
                    Expection => defined $Organisation{$Attribute}->{$Pref} ? $Organisation{$Attribute}->{$Pref} : q{-},
                }
            );
        }
    }
    else {
        push(
            @UnitTests,
            {
                TestName  => "Placeholder: <KIX_ORG_" . $Attribute . ">",
                TicketID  => $TicketID,
                Test      => "<KIX_ORG_" . $Attribute . ">",
                Expection => defined $Organisation{$Attribute} ? $Organisation{$Attribute} : q{-},
            }
        );
    }
}

# old placeholder of KIX_CUSTOMERDATA_ AND KIX_CUSTOMER_DATA_
my %OldData;
for my $Attribute ( keys %Contact ) {
    next if !$Contact{$Attribute};
    if ( $Attribute eq 'OrganisationIDs' ) {
        INDEX:
        for my $Index ( keys @{$Contact{OrganisationIDs}} ) {
            next INDEX if !$Contact{OrganisationIDs}[$Index];
            $OldData{"UserOrganisationIDs_$Index"} = $Contact{OrganisationIDs}[$Index];
        }
        next;
    }
    $OldData{'User' . $Attribute} = $Contact{$Attribute};
}
for my $Attribute ( keys %Organisation ) {
    next if !$Organisation{$Attribute};
    $OldData{'CustomerCompany' . $Attribute} = $Organisation{$Attribute};
}

_TestRun(
    Tests => \@UnitTests
);

sub _TestRun {
    my (%Param) = @_;

    for my $Test ( @{$Param{Tests}} ) {
        my $Result = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
            RichText  => 0,
            Data      => {},
            Text      => $Test->{Test},
            TicketID  => $Test->{TicketID} || undef,
            UserID    => $Test->{UserID}   || 1
        );

        $Self->Is(
            $Result,
            $Test->{Expection},
            $Test->{TestName}
        );
    }

    return 1;
}

sub _CreateTicket {
    my (%Param) = @_;

    my $ID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title           => 'UnitTest Ticket ' . $Helper->GetRandomID(),
        Queue           => 'Junk',
        Lock            => 'unlock',
        Priority        => '3 normal',
        State           => 'new',
        OrganisationID  => $Contact{PrimaryOrganisationID},
        ContactID       => $Contact{UserID},
        OwnerID         => $User{UserID},
        ResponsibleID   => $User{UserID},
        UserID          => 1
    );

    $Self->True(
        $ID,
        $Param{TestName}
    );

    $Kernel::OM->ObjectsDiscard(
        Objects => [
            'Ticket'
        ]
    );

    return $ID;
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