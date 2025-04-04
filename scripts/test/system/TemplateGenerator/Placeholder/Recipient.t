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

if ( IsHashRefWithData($User{Preferences}) ) {
    for my $Pref ( keys %{$User{Preferences}} ) {
        $User{"Preferences_$Pref"} = $User{Preferences}->{$Pref};
    }
    delete ($User{Preferences});
}

my @UnitTests;
for my $Prefix (
    qw(
        KIX_NOTIFICATIONRECIPIENT_
        KIX_NOTIFICATION_RECIPIENT_
    )
) {
    for my $Attribute ( sort keys %User ) {
        push(
            @UnitTests,
            {
                TestName    => "Placeholder (Recipient Type Agent): <" . $Prefix . $Attribute . ">",
                Recipient => {
                    Type => 'Agent',
                    %User
                },
                Test        => "<" . $Prefix . $Attribute . ">",
                Expection   => defined $User{$Attribute} ? $User{$Attribute} : q{-},
            }
        );
    }
}

my $TestContactID = $Helper->TestContactCreate();

my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $TestContactID
);

if ( IsHashRefWithData($Contact{Preferences}) ) {
    for my $Pref ( keys %{$Contact{Preferences}} ) {
        $Contact{"Preferences_$Pref"} = $Contact{Preferences}->{$Pref};
    }
    delete ($Contact{Preferences});
}
if ( IsArrayRefWithData($Contact{OrganisationIDs}) ) {
    for my $Index ( keys @{$Contact{OrganisationIDs}} ) {
        $Contact{"OrganisationIDs_$Index"} = $Contact{OrganisationIDs}->[$Index];
    }
    delete ($Contact{OrganisationIDs});
}

for my $Prefix (
    qw(
        KIX_NOTIFICATIONRECIPIENT_
        KIX_NOTIFICATION_RECIPIENT_
    )
) {
    for my $Attribute ( sort keys %Contact ) {
        push(
            @UnitTests,
            {
                TestName    => "Placeholder (Recipient Type Customer): <" . $Prefix . $Attribute . ">",
                Recipient => {
                    Type => 'Customer',
                    %Contact
                },
                Test        => "<" . $Prefix . $Attribute . ">",
                Expection   => defined $Contact{$Attribute} ? $Contact{$Attribute} : q{-},
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
            RichText    => 1,
            Data        => {},
            Text        => $Test->{Test},
            Recipient   => $Test->{Recipient},
            UserID      => 1
        );

        $Self->Is(
            $Result,
            $Test->{Expection},
            $Test->{TestName}
        );
    }

    return 1;
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