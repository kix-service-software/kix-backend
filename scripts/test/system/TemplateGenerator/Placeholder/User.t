# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
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

my $TicketID = _CreateTicket(
    Contact  => \%Contact,
    User     => \%User,
    TestName => '_CreateTicket(): ticket create'
);

my @UnitTests;
for my $Prefix (
    qw(
        KIX_OWNER_
        KIX_TICKETOWNER_
        KIX_TICKET_OWNER_
        KIX_RESPONSIBLE_
        KIX_TICKETRESPONSIBLE_
        KIX_TICKET_RESPONSIBLE_
    )
) {
    for my $Attribute ( sort keys %User ) {

        if ( $Attribute eq 'Preferences' ) {
            for my $Pref ( sort keys %{$User{$Attribute}} ) {
                push(
                    @UnitTests,
                    {
                        TestName  => "Placeholder: <" . $Prefix . $Attribute . "_" . $Pref . ">",
                        TicketID  => $TicketID,
                        Test      => "<" . $Prefix . $Attribute . "_" . $Pref . ">",
                        Expection => defined $User{$Attribute}->{$Pref} ? $User{$Attribute}->{$Pref} : q{-},
                    }
                );
            }
        }
        else {
            push(
                @UnitTests,
                {
                    TestName  => "Placeholder: <" . $Prefix . $Attribute . ">",
                    TicketID  => $TicketID,
                    Test      => "<" . $Prefix . $Attribute . ">",
                    Expection => defined $User{$Attribute} ? $User{$Attribute} : q{-},
                }
            );
        }
    }
}

# placeholder of KIX_CURRENT_
for my $Attribute ( sort keys %User ) {
    if ( $Attribute eq 'Preferences' ) {
        for my $Pref ( sort keys %{$User{$Attribute}} ) {
            push(
                @UnitTests,
                {
                    TestName  => "Placeholder: <KIX_CURRENT_" . $Attribute . "_" . $Pref . ">",
                    UserID    => $User{UserID},
                    Test      => "<KIX_CURRENT_" . $Attribute . "_" . $Pref . ">",
                    Expection => defined $User{$Attribute}->{$Pref} ? $User{$Attribute}->{$Pref} : q{-},
                }
            );
        }
    }
    else {
        push(
            @UnitTests,
            {
                TestName  => "Placeholder: <KIX_CURRENT_" . $Attribute . ">",
                UserID    => $User{UserID},
                Test      => "<KIX_CURRENT_" . $Attribute . ">",
                Expection => defined $User{$Attribute} ? $User{$Attribute} : q{-},
            }
        );
    }
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