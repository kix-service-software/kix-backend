# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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
my $TicketObject  = $Kernel::OM->Get('Ticket');
my $UserObject    = $Kernel::OM->Get('User');
my $ContactObject = $Kernel::OM->Get('Contact');
my $QueueObject   = $Kernel::OM->Get('Queue');
my $SystemAddressObject = $Kernel::OM->Get('SystemAddress');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $UserFirstname = 'Test';
my $UserLastname  = 'User';
my $EmailName     = 'SomeTest';
my $Email         = 'sometest@somemail.com';
my ($TestUserID, $TicketID);

_Preparations();

if ($TestUserID && $TicketID) {

    my @ArticleTests = (
        {
            Name => 'Preference is undefined',
        },
        {
            Name      => 'Preference is "SystemAddress"',
            PrefValue => 'SystemAddress'
        },
        {
            Name      => 'Preference is "Agent"',
            PrefValue => 'Agent'
        },
        {
            Name      => 'Preference is "AgentViaSystemAddress"',
            PrefValue => 'AgentViaSystemAddress'
        },
        {
            Name => 'Preference is irrelevant - From is given',
            From => '"some agent" <someagent@somecompany.com>'
        },
    );

    TEST:
    for my $Test (@ArticleTests) {

        if ($Test->{PrefValue}) {
            my $Success = $UserObject->SetPreferences(
                Key    => 'ArticleFromFormat',
                Value  => $Test->{PrefValue},
                UserID => $TestUserID
            );
            $Self->True(
                $Success,
                'Preference value "' . $Test->{PrefValue} . '" set'
            );
        } else {
            my $Success = $UserObject->DeletePreferences(
                Key    => 'ArticleFromFormat',
                UserID => $TestUserID
            );
            $Self->True(
                $Success,
                'Preference delete'
            );
        }

        my $ArticleID = $TicketObject->ArticleCreate(
            TicketID       => $TicketID,
            Channel        => 'email',
            SenderType     => 'agent',
            From           => $Test->{From} || undef,
            To             => '"Some TestCustomer" <customer@test.com>',
            Subject        => 'some short description',
            Body           => 'the message text',
            MimeType       => 'text/plain',
            Charset        => 'UTF-8',
            HistoryType    => 'EmailAgent',
            HistoryComment => 'Some comment',
            UserID         => $TestUserID
        );
        $Self->True(
            $ArticleID,
            'Article "' . $Test->{Name} . '" created'
        );

        if ($ArticleID) {
            my %Article = $TicketObject->ArticleGet(ArticleID => $ArticleID);

            $Self->True(
                IsHashRefWithData(\%Article) ? 1 : 0,
                'Article "' . $Test->{Name} . '" get'
            );
            if (IsHashRefWithData(\%Article)) {
                if (!$Test->{From}) {
                    if (!$Test->{PrefValue} || $Test->{PrefValue} eq 'SystemAddress') {
                        $Test->{From} = "\"$EmailName\" <$Email>";
                    } elsif ($Test->{PrefValue} eq 'Agent') {
                        $Test->{From} = "\"$UserFirstname $UserLastname\" <$Email>";
                    } elsif ($Test->{PrefValue} eq 'AgentViaSystemAddress') {
                        $Test->{From} = "\"$UserFirstname $UserLastname via $EmailName\" <$Email>";
                    }
                }

                $Self->Is(
                    $Article{From},
                    $Test->{From},
                    'Article "' . $Test->{Name} . '" - From check'
                );
            }
        }
    }
}

sub _Preparations {
    my $TestUserLogin = $Helper->TestUserCreate(
        Firstname => $UserFirstname,
        Lastname  => $UserLastname
    );
    $TestUserID = $UserObject->UserLookup(
        UserLogin => $TestUserLogin
    );
    $Self->True(
        $TestUserID,
        'Test user created'
    );

    my $SystemAddressID = $SystemAddressObject->SystemAddressAdd(
        Name     => $Email,
        Realname => $EmailName,
        ValidID  => 1,
        UserID   => 1
    );
    $Self->True(
        $SystemAddressID,
        'System address created'
    );

    my $QueueID;
    if ($SystemAddressID) {
        $QueueID = $QueueObject->QueueAdd(
            Name                => 'Some test queue for pref check',
            ValidID             => 1,
            SystemAddressID     => $SystemAddressID,
            Signature           => '',
            UserID              => 1
        );
    }

    if ($TestUserID && $QueueID) {
        $TicketID = $TicketObject->TicketCreate(
            Title          => 'ArticleFromByAgentPref test ticket',
            QueueID        => $QueueID,
            Lock           => 'unlock',
            Priority       => '3 normal',
            State          => 'closed',
            OwnerID        => 1,
            UserID         => 1,
            Silent         => 1
        );
        $Self->True(
            $TicketID,
            'Ticket created'
        );
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
