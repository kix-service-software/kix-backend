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

# get needed objects
my $ConfigObject       = $Kernel::OM->Get('Config');
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $BackendObject      = $Kernel::OM->Get('DynamicField::Backend');
my $TicketObject       = $Kernel::OM->Get('Ticket');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $RandomID = $Helper->GetRandomID();

my @DynamicFieldsToAdd = (
    {
        Name       => 'Replace1' . $RandomID,
        Label      => 'a description',
        FieldOrder => 9998,
        FieldType  => 'Text',
        ObjectType => 'Ticket',
        Config     => {
            Name        => 'Replace1' . $RandomID,
            Description => 'Description for Dynamic Field.',
        },
        Reorder => 0,
        ValidID => 1,
        UserID  => 1,
    },
    {
        Name       => 'Replace2' . $RandomID,
        Label      => 'a description',
        FieldOrder => 9999,
        FieldType  => 'Dropdown',
        ObjectType => 'Ticket',
        Config     => {
            Name           => 'Replace2' . $RandomID,
            Description    => 'Description for Dynamic Field.',
            PossibleValues => {
                1 => 'A',
                2 => 'B',
                }
        },
        Reorder => 0,
        ValidID => 1,
        UserID  => 1,
    },
);

my %AddedDynamicFieldIds;
my %DynamicFieldConfigs;

for my $DynamicField (@DynamicFieldsToAdd) {

    my $DynamicFieldID = $DynamicFieldObject->DynamicFieldAdd(
        %{$DynamicField},
    );
    $Self->IsNot(
        $DynamicFieldID,
        undef,
        'DynamicFieldAdd()',
    );

    # remember added DynamicFields
    $AddedDynamicFieldIds{$DynamicFieldID} = $DynamicField->{Name};

    my $DynamicFieldConfig = $DynamicFieldObject->DynamicFieldGet(
        Name => $DynamicField->{Name},
    );
    $Self->Is(
        ref $DynamicFieldConfig,
        'HASH',
        'DynamicFieldConfig must be a hash reference',
    );

    # remember the DF config
    $DynamicFieldConfigs{ $DynamicField->{FieldType} } = $DynamicFieldConfig;
}

# create template generator after the dynamic field are created as it gathers all DF in the
# constructor
my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

my $TestContactID = $Helper->TestContactCreate(
    Language => 'en',
);

my $TestUserLogin = $Helper->TestUserCreate(
    Language => 'en',
);

my %TestUser = $Kernel::OM->Get('User')->GetUserData(
    User => $TestUserLogin,
);

my %TestUserContact  = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $TestUser{UserID},
);

my $TestUser2Login = $Helper->TestUserCreate(
    Language => 'en',
);

my %TestUser2 = $Kernel::OM->Get('User')->GetUserData(
    User => $TestUserLogin,
);

my %TestUser2Contact  = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $TestUser2{UserID},
);

my $TestUser3Login = $Helper->TestUserCreate(
    Language => 'en',
);

my %TestUser3 = $Kernel::OM->Get('User')->GetUserData(
    User => $TestUserLogin,
);

my %TestUser3Contact  = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $TestUser3{UserID},
);

my $TestUser4Login = $Helper->TestUserCreate(
    Language => 'en',
);

my %TestUser4 = $Kernel::OM->Get('User')->GetUserData(
    User => $TestUserLogin,
);

my %TestUser4Contact  = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $TestUser4{UserID},
);

my $TicketID = $TicketObject->TicketCreate(
    Title         => 'Some Ticket_Title',
    Queue         => 'Junk',
    Lock          => 'unlock',
    Priority      => '3 normal',
    State         => 'closed',
    OrganisationID => '123465',
    ContactID     => $TestContactID,
    OwnerID       => $TestUser{UserID},
    ResponsibleID => $TestUser2{UserID},
    UserID        => $TestUser3{UserID},
);
$Self->IsNot(
    $TicketID,
    undef,
    'TicketCreate() TicketID',
);

my $Success = $BackendObject->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfigs{Text},
    ObjectID           => $TicketID,
    Value              => 'kix',
    UserID             => 1,
);
$Self->True(
    $Success,
    'DynamicField ValueSet() for Dynamic Field Text - with true',
);

$Success = $BackendObject->ValueSet(
    DynamicFieldConfig => $DynamicFieldConfigs{Dropdown},
    ObjectID           => $TicketID,
    Value              => 1,
    UserID             => 1,
);
$Self->True(
    $Success,
    'DynamicField ValueSet() Dynamic Field Dropdown - with true',
);

my $ArticleID = $TicketObject->ArticleCreate(
    TicketID       => $TicketID,
    Channel        => 'note',
    SenderType     => 'agent',
    From           => 'Some Agent <email@example.com>',
    To             => 'Some Customer <customer-a@example.com>',
    Subject        => 'some short description',
    Body           => 'the message text',
    ContentType    => 'text/plain; charset=ISO-8859-15',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'Some free text!',
    UserID         => 1,
    NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
);
$Self->IsNot(
    $ArticleID,
    undef,
    'ArticleCreate() ArticleID',
);

my @Tests = (
    {
        Name => 'Simple replace',
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_CUSTOMER_From>',
        Result   => 'Test test@home.com',
    },
    {
        Name => 'Simple replace, case insensitive',
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_CUSTOMER_FROM>',
        Result   => 'Test test@home.com',
    },
    {
        Name => 'remove unknown tags',
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_CUSTOMER_INVALID_TAG>',
        Result   => 'Test -',
    },
    {
        Name => 'KIX customer subject',    # <KIX_CUSTOMER_SUBJECT>
        Data => {
            From    => 'test@home.com',
            Subject => 'kix',
        },
        RichText => 0,
        Template => 'Test <KIX_CUSTOMER_SUBJECT>',
        Result   => 'Test kix',
    },
    {
        Name => 'KIX customer subject 3 letters',    # <KIX_CUSTOMER_SUBJECT[20]>
        Data => {
            From    => 'test@home.com',
            Subject => 'kix',
        },
        RichText => 0,
        Template => 'Test <KIX_CUSTOMER_SUBJECT[3]>',
        Result   => 'Test otr [...]',
    },
    {
        Name => 'KIX customer subject 20 letters + garbarge',    # <KIX_CUSTOMER_SUBJECT[20]>
        Data => {
            From    => 'test@home.com',
            Subject => 'RE: kix',
        },
        RichText => 0,
        Template => 'Test <KIX_CUSTOMER_SUBJECT[20]>',
        Result   => 'Test kix',
    },
    {
        Name => 'KIX responsible firstname',                     # <KIX_RESPONSIBLE_Firstname>
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_RESPONSIBLE_Firstname> <KIX_RESPONSIBLE_nonexisting>',
        Result   => "Test $TestUser2Contact{Firstname} -",
    },
    {
        Name => 'KIX_TICKET_RESPONSIBLE firstname',              # <KIX_RESPONSIBLE_Firstname>
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_TICKET_RESPONSIBLE_Firstname> <KIX_TICKET_RESPONSIBLE_nonexisting>',
        Result   => "Test $TestUser2Contact{Firstname} -",
    },
    {
        Name => 'KIX owner firstname',                           # <KIX_OWNER_*>
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_OWNER_Firstname> <KIX_OWNER_nonexisting>',
        Result   => "Test $TestUserContact{Firstname} -",
    },
    {
        Name => 'KIX_TICKET_OWNER firstname',                    # <KIX_OWNER_*>
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_TICKET_OWNER_Firstname> <KIX_TICKET_OWNER_nonexisting>',
        Result   => "Test $TestUserContact{Firstname} -",
    },
    {
        Name => 'KIX current firstname',                         # <KIX_CURRENT_*>
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_CURRENT_Firstname> <KIX_CURRENT_nonexisting>',
        Result   => "Test $TestUser3Contact{Firstname} -",
    },
    {
        Name => 'KIX ticket ticketid',                           # <KIX_TICKET_*>
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_TICKET_TicketID>',
        Result   => 'Test ' . $TicketID,
    },
    {
        Name => 'KIX dynamic field (text)',                      # <KIX_TICKET_DynamicField_*>
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_TICKET_DynamicField_Replace1' . $RandomID . '>',
        Result   => 'Test kix',
    },
    {
        Name => 'KIX dynamic field value (text)',                # <KIX_TICKET_DynamicField_*_Value>
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_TICKET_DynamicField_Replace1' . $RandomID . '_Value>',
        Result   => 'Test kix',
    },
    {
        Name => 'KIX dynamic field (Dropdown)',                  # <KIX_TICKET_DynamicField_*>
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_TICKET_DynamicField_Replace2' . $RandomID . '>',
        Result   => 'Test 1',
    },
    {
        Name => 'KIX dynamic field value (Dropdown)',            # <KIX_TICKET_DynamicField_*_Value>
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_TICKET_DynamicField_Replace2' . $RandomID . '_Value>',
        Result   => 'Test A',
    },
    {
        Name     => 'KIX config value',                          # <KIX_CONFIG_*>
        Data     => {},
        RichText => 0,
        Template => 'Test <KIX_CONFIG_DefaultTheme>',
        Result   => 'Test Standard',
    },
    {
        Name     => 'KIX secret config values, must be masked (even unknown settings)',
        Data     => {},
        RichText => 0,
        Template =>
            'Test <KIX_CONFIG_DatabasePw> <KIX_CONFIG_Core::MirrorDB::Password> <KIX_CONFIG_SomeOtherValue::Password> <KIX_CONFIG_SomeOtherValue::Pw>',
        Result => 'Test xxx xxx xxx xxx',
    },
    {
        Name     => 'KIX secret config value and normal config value',
        Data     => {},
        RichText => 0,
        Template => 'Test <KIX_CONFIG_DatabasePw> and <KIX_CONFIG_DefaultTheme>',
        Result   => 'Test xxx and Standard',
    },
    {
        Name     => 'KIX secret config values with numbers',
        Data     => {},
        RichText => 0,
        Template =>
            'Test <KIX_CONFIG_AuthModule::LDAP::SearchUserPw1> and <KIX_CONFIG_AuthModule::LDAP::SearchUserPassword1>',
        Result => 'Test xxx and xxx',
    },
    {
        Name => 'mailto-Links RichText enabled',
        Data => {
            From => 'test@home.com',
        },
        RichText => 1,
        Template =>
            'mailto-Link <a href="mailto:skywalker@test.org?subject=From%3A%20%3CKIX_CUSTOMER_From%3E&amp;body=From%3A%20%3CKIX_CUSTOMER_From%3E">E-Mail mit Subject und Body</a><br />
<br />
mailto-Link <a href="mailto:skywalker@test.org?subject=From%3A%20%3CKIX_CUSTOMER_From%3E">E-Mail mit Subject</a><br />
<br />
mailto-Link <a href="mailto:skywalker@test.org?body=From%3A%20%3CKIX_CUSTOMER_From%3E">E-Mail mit Body</a><br />',
        Result =>
            'mailto-Link <a href="mailto:skywalker@test.org?subject=From%3A%20test%40home.com&amp;body=From%3A%20test%40home.com">E-Mail mit Subject und Body</a><br /><br />mailto-Link <a href="mailto:skywalker@test.org?subject=From%3A%20test%40home.com">E-Mail mit Subject</a><br /><br />mailto-Link <a href="mailto:skywalker@test.org?body=From%3A%20test%40home.com">E-Mail mit Body</a><br />',
    },
    {
        Name => 'mailto-Links',
        Data => {
            From => 'test@home.com',
        },
        RichText => 0,
        Template =>
            'mailto-Link <a href="mailto:skywalker@test.org?subject=From%3A%20%3CKIX_CUSTOMER_From%3E&amp;body=From%3A%20%3CKIX_CUSTOMER_From%3E">E-Mail mit Subject und Body</a><br />
<br />
mailto-Link <a href="mailto:skywalker@test.org?subject=From%3A%20%3CKIX_CUSTOMER_From%3E">E-Mail mit Subject</a><br />
<br />
mailto-Link <a href="mailto:skywalker@test.org?body=From%3A%20%3CKIX_CUSTOMER_From%3E">E-Mail mit Body</a><br />',
        Result =>
            'mailto-Link <a href="mailto:skywalker@test.org?subject=From%3A%20test%40home.com&amp;body=From%3A%20test%40home.com">E-Mail mit Subject und Body</a><br />
<br />
mailto-Link <a href="mailto:skywalker@test.org?subject=From%3A%20test%40home.com">E-Mail mit Subject</a><br />
<br />
mailto-Link <a href="mailto:skywalker@test.org?body=From%3A%20test%40home.com">E-Mail mit Body</a><br />',
    },
    {
        Name => 'KIX AGENT + CUSTOMER FROM',    # <KIX_TICKET_DynamicField_*_Value>
        Data => {
            From => 'testcustomer@home.com',
        },
        DataAgent => {
            From => 'testagent@home.com',
        },
        RichText => 0,
        Template => 'Test <KIX_AGENT_From> - <KIX_CUSTOMER_From>',
        Result   => 'Test testagent@home.com - testcustomer@home.com',
    },
    {
        Name =>
            'KIX AGENT + CUSTOMER BODY',   # this is an special case, it sets the Body as it is since is the Data param
        Data => {
            Body => "Line1\nLine2\nLine3",
        },
        DataAgent => {
            Body => "Line1\nLine2\nLine3",
        },
        RichText => 0,
        Template => 'Test <KIX_AGENT_BODY> - <KIX_CUSTOMER_BODY>',
        Result   => "Test Line1\nLine2\nLine3 - Line1\nLine2\nLine3",
    },
    {
        Name =>
            'KIX AGENT + CUSTOMER BODY With RichText enabled'
        ,    # this is an special case, it sets the Body as it is since is the Data param
        Data => {
            Body => "Line1\nLine2\nLine3",
        },
        DataAgent => {
            Body => "Line1\nLine2\nLine3",
        },
        RichText => 1,
        Template => 'Test &lt;KIX_AGENT_BODY&gt; - &lt;KIX_CUSTOMER_BODY&gt;',
        Result   => "Test Line1<br/>
Line2<br/>
Line3 - Line1<br/>
Line2<br/>
Line3",
    },
    {
        Name => 'KIX AGENT + CUSTOMER BODY[2]',
        Data => {
            Body => "Line1\nLine2\nLine3",
        },
        DataAgent => {
            Body => "Line1\nLine2\nLine3",
        },
        RichText => 0,
        Template => 'Test <KIX_AGENT_BODY[2]> - <KIX_CUSTOMER_BODY[2]>',
        Result   => "Test > Line1\n> Line2 - > Line1\n> Line2",
    },
    {
        Name => 'KIX AGENT + CUSTOMER BODY[7] with RichText enabled',
        Data => {
            Body => "Line1\nLine2\nLine3\nLine4\nLine5\nLine6\nLine7\nLine8\nLine9",
        },
        DataAgent => {
            Body => "Line1\nLine2\nLine3\nLine4\nLine5\nLine6\nLine7\nLine8\nLine9",
        },
        RichText => 1,
        Template => 'Test &lt;KIX_AGENT_BODY[7]&gt; - &lt;KIX_CUSTOMER_BODY[7]&gt;',
        Result =>
            'Test <div  type="cite" style="border:none;border-left:solid blue 1.5pt;padding:0cm 0cm 0cm 4.0pt">Line1<br/>
Line2<br/>
Line3<br/>
Line4<br/>
Line5<br/>
Line6<br/>
Line7</div> - <div  type="cite" style="border:none;border-left:solid blue 1.5pt;padding:0cm 0cm 0cm 4.0pt">Line1<br/>
Line2<br/>
Line3<br/>
Line4<br/>
Line5<br/>
Line6<br/>
Line7</div>',
    },
    {
        Name => 'KIX AGENT + CUSTOMER EMAIL',    # EMAIL without [ ] does not exists
        Data => {
            Body => "Line1\nLine2\nLine3",
        },
        DataAgent => {
            Body => "Line1\nLine2\nLine3",
        },
        RichText => 0,
        Template => 'Test <KIX_AGENT_EMAIL> - <KIX_CUSTOMER_EMAIL>',
        Result   => "Test - - -",
    },
    {
        Name => 'KIX AGENT + CUSTOMER EMAIL[2]',
        Data => {
            Body => "Line1\nLine2\nLine3",
        },
        DataAgent => {
            Body => "Line1\nLine2\nLine3",
        },
        RichText => 0,
        Template => 'Test <KIX_AGENT_EMAIL[2]> - <KIX_CUSTOMER_EMAIL[2]>',
        Result   => "Test > Line1\n> Line2 - > Line1\n> Line2",
    },
    {
        Name => 'KIX COMMENT',    # EMAIL without [ ] does not exists
        Data => {
            Body => "Line1\nLine2\nLine3",
        },
        RichText => 0,
        Template => 'Test <KIX_COMMENT>',
        Result   => "Test > Line1\n> Line2\n> Line3",
    },

    {
        Name => 'KIX AGENT + CUSTOMER SUBJECT[2]',
        Data => {
            Subject => '0123456789'
        },
        DataAgent => {
            Subject => '987654321'
        },
        RichText => 0,
        Template => 'Test <KIX_AGENT_SUBJECT[2]> - <KIX_CUSTOMER_SUBJECT[2]>',
        Result   => "Test 98 [...] - 01 [...]",
    },
    {
        Name     => 'KIX CUSTOMER REALNAME',
        Data     => {},
        RichText => 0,
        Template => 'Test <KIX_CUSTOMER_REALNAME>',
        Result   => "Test $TestContactUserLogin $TestContactUserLogin",
    },
    {
        Name     => 'KIX CUSTOMER DATA Firstname',
        Data     => {},
        RichText => 0,
        Template => 'Test <KIX_CUSTOMER_DATA_Firstname>',
        Result   => "Test $TestContactUserLogin",
    },
);

for my $Test (@Tests) {
    my $Result = $TemplateGeneratorObject->_Replace(
        Text        => $Test->{Template},
        Data        => $Test->{Data},
        DataAgent   => $Test->{DataAgent},
        RichText    => $Test->{RichText},
        TicketID    => $TicketID,
        UserID      => $TestUser3{UserID},
        RecipientID => $TestUser4{UserID},
    );
    $Self->Is(
        $Result,
        $Test->{Result},
        "$Test->{Name} - _Replace()",
    );
}

# Cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
