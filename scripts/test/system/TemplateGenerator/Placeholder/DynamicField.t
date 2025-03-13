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

my $TestContactID = $Helper->TestContactCreate(
    NoUser => 1,
);

my $TestUser = $Helper->TestUserCreate(
    Roles => [
        'Ticket Agent'
    ]
);
my %User = $Kernel::OM->Get('User')->GetUserData(
    User => $TestUser
);

my $TestOwner = $Helper->TestUserCreate(
    Roles => [
        'Ticket Agent'
    ]
);
my %Owner = $Kernel::OM->Get('User')->GetUserData(
    User  => $TestOwner
);

my $TestResponsible = $Helper->TestUserCreate(
    Roles => [
        'Ticket Agent'
    ]
);
my %Responsible = $Kernel::OM->Get('User')->GetUserData(
    User  => $TestResponsible
);

my $TestContactID = $Helper->TestContactCreate();

my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $TestContactID
);

my $TicketID = _CreateTicket(
    Contact     => \%Contact,
    User        => \%User,
    Owner       => \%Owner,
    Responsible => \%Responsible,
    TestName    => '_CreateTicket(): ticket create'
);

my $CIID = _CreateAsset();

my %DFFields = _CreateTicketDynamicField(
    TicketID     => $TicketID,
    ConfigItemID => $CIID,
);

my %ContactDFFields = _CreateContactDynamicField(
    User        => \%User,
    Owner       => \%Owner,
    Responsible => \%Responsible,
);

my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID     => $TicketID,
    DynamicField => 1,
    UserID       => 1
);

my @UnitTests;
# placeholder of KIX_TICKET_DynamicField_
for my $Field ( sort keys %DFFields ) {

    my %Expection = %{$DFFields{$Field}};
    $Expection{q{}}   = $Expection{q{}}   // $Expection{All};
    $Expection{Short} = $Expection{Short} // $Expection{All};
    $Expection{Key}   = $Expection{Key}   // $Expection{All};
    $Expection{Value} = $Expection{Value} // $Expection{All};
    $Expection{HTML}  = $Expection{HTML}  // $Expection{All};

    push(
        @UnitTests,
        {
            TestName  => "Placeholder: <KIX_TICKET_DynamicField_$Field>",
            TicketID  => $TicketID,
            Test      => "<KIX_TICKET_DynamicField_$Field>",
            Expection => $Expection{q{}},
        },
        {
            TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_Value>",
            TicketID  => $TicketID,
            Test      => "<KIX_TICKET_DynamicField_" . $Field . "_Value>",
            Expection => $Expection{Value},
        },
        {
            TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_Key>",
            TicketID  => $TicketID,
            Test      => "<KIX_TICKET_DynamicField_" . $Field . "_Key>",
            Expection => $Expection{Key},
        },
        {
            TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_HTML>",
            TicketID  => $TicketID,
            Test      => "<KIX_TICKET_DynamicField_" . $Field . "_HTML>",
            Expection => $Expection{HTML},
        },
        {
            TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_Short>",
            TicketID  => $TicketID,
            Test      => "<KIX_TICKET_DynamicField_" . $Field . "_Short>",
            Expection => $Expection{Short},
        }
    );
    if ($Expection{'Value!'}) {
        push(
            @UnitTests,
            {
                TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_Value!>",
                TicketID  => $TicketID,
                Test      => "<KIX_TICKET_DynamicField_" . $Field . "_Value!>",
                Expection => $Expection{'Value!'},
            }
        );
    }
    if ($Expection{'HTML!'}) {
        push(
            @UnitTests,
            {
                TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_HTML!>",
                TicketID  => $TicketID,
                Test      => "<KIX_TICKET_DynamicField_" . $Field . "_HTML!>",
                Expection => $Expection{'HTML!'},
            }
        );
    }
    if ($Expection{'Short!'}) {
        push(
            @UnitTests,
            {
                TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_Short!>",
                TicketID  => $TicketID,
                Test      => "<KIX_TICKET_DynamicField_" . $Field . "_Short!>",
                Expection => $Expection{'Short!'},
            }
        );
    }
    if ($Expection{'Key!'}) {
        push(
            @UnitTests,
            {
                TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_Key!>",
                TicketID  => $TicketID,
                Test      => "<KIX_TICKET_DynamicField_" . $Field . "_Key!>",
                Expection => $Expection{'Key!'},
            }
        );
    }
    if ($Expection{'! with text'}) {
        push(
            @UnitTests,
            {
                TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "!> with text",
                TicketID  => $TicketID,
                Test      => "<KIX_TICKET_DynamicField_" . $Field . "!> with text",
                Expection => $Expection{'! with text'} . ' with text',
            },
            {
                TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_ObjectValue> with text",
                TicketID  => $TicketID,
                Test      => "<KIX_TICKET_DynamicField_" . $Field . "_ObjectValue> with text",
                Expection => $Expection{'! with text'} . ' with text',
            }
        );
    }

    if (
        $Expection{All}
        && !$Expection{ObjectValue}
    ) {
        push (
            @UnitTests,
            {
                TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_ObjectValue>",
                TicketID  => $TicketID,
                Test      => "<KIX_TICKET_DynamicField_" . $Field . "_ObjectValue>",
                Expection => $Expection{All},
            },
            {
                TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_ObjectValue_0>",
                TicketID  => $TicketID,
                Test      => "<KIX_TICKET_DynamicField_" . $Field . "_ObjectValue_0>",
                Expection => $Expection{All},
            },
            {
                TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "!>",
                TicketID  => $TicketID,
                Test      => "<KIX_TICKET_DynamicField_" . $Field . "!>",
                Expection => $Expection{All},
            },
        )
    }
    else {
        for my $Index ( sort keys %{$Expection{ObjectValue}} ) {
            my $Suffix = q{};
            $Suffix .= "_$Index" if $Index ne 'undef';

            push (
                @UnitTests,
                {
                    TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "_ObjectValue$Suffix>",
                    TicketID  => $TicketID,
                    Test      => "<KIX_TICKET_DynamicField_" . $Field . "_ObjectValue$Suffix>",
                    Expection => $Expection{ObjectValue}->{$Index},
                }
            )
        }
        # simple ! should also return object value
        push (
            @UnitTests,
            {
                TestName  => "Placeholder: <KIX_TICKET_DynamicField_" . $Field . "!>",
                TicketID  => $TicketID,
                Test      => "<KIX_TICKET_DynamicField_" . $Field . "!>",
                Expection => $Expection{ObjectValue}->{undef},
            }
        )
    }
}

# test owner, responsible and current placeholder
for my $Field ( sort keys %ContactDFFields ) {
    for my $Placeholder ( qw(TICKETOWNER TICKET_OWNER OWNER) ) {
        push(
            @UnitTests,
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '>',
                UserID    => $User{UserID},
                Expection => $Owner{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Value>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Value>',
                UserID    => $User{UserID},
                Expection => $Owner{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Key>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Key>',
                UserID    => $User{UserID},
                Expection => $Owner{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_HTML>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_HTML>',
                UserID    => $User{UserID},
                Expection => $Owner{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Short>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Short>',
                UserID    => $User{UserID},
                Expection => $Owner{UserID},
            }
        );
    }

    for my $Placeholder ( qw(TICKETRESPONSIBLE TICKET_RESPONSIBLE RESPONSIBLE) ) {
        push(
            @UnitTests,
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '>',
                UserID    => $User{UserID},
                Expection => $Responsible{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Value>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Value>',
                UserID    => $User{UserID},
                Expection => $Responsible{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Key>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Key>',
                UserID    => $User{UserID},
                Expection => $Responsible{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_HTML>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_HTML>',
                UserID    => $User{UserID},
                Expection => $Responsible{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Short>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Short>',
                UserID    => $User{UserID},
                Expection => $Responsible{UserID},
            }
        );
    }

    for my $Placeholder ( qw(CURRENT) ) {
        push(
            @UnitTests,
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '>',
                UserID    => $User{UserID},
                Expection => $User{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Value>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Value>',
                UserID    => $User{UserID},
                Expection => $User{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Key>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Key>',
                UserID    => $User{UserID},
                Expection => $User{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_HTML>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_HTML>',
                UserID    => $User{UserID},
                Expection => $User{UserID},
            },
            {
                TestName  => 'Placeholder: <KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Short>',
                TicketID  => $TicketID,
                Test      => '<KIX_' . $Placeholder . '_DynamicField_' . $Field . '_Short>',
                UserID    => $User{UserID},
                Expection => $User{UserID},
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
            Text      => $Test->{Test},
            Data      => {},
            TicketID  => $Test->{TicketID} || undef,
            Translate => 0,
            UserID    => $Test->{UserID} || 1,

        );

        if ( IsStringWithData($Test->{Expection}) ) {
            $Self->Is(
                $Result,
                $Test->{Expection},
                $Test->{TestName}
            );
        }
        else {
            $Self->IsDeeply(
                $Result,
                $Test->{Expection},
                $Test->{TestName}
            );
        }
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
        OwnerID         => $Owner{UserID},
        ResponsibleID   => $Responsible{UserID},
        UserID          => $User{UserID},
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

sub _CreateAsset {
    my (%Param) = @_;

    my $ClassID = $Kernel::OM->Get('GeneralCatalog')->ItemLookup(
        Class => 'ITSM::ConfigItem::Class',
        Name  => 'Computer'
    );

    # get state list
    my $ProductionID = $Kernel::OM->Get('GeneralCatalog')->ItemLookup(
        Class => 'ITSM::ConfigItem::DeploymentState',
        Name  => 'Production'
    );
    my $OperationalID = $Kernel::OM->Get('GeneralCatalog')->ItemLookup(
        Class => 'ITSM::Core::IncidentState',
        Name  => 'Operational'
    );

    my $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemAdd(
        ClassID => $ClassID,
        UserID  => 1,
    );

    $Self->True(
        $ConfigItemID,
        "ConfigItemAdd(): Create ConfigItem for DynamicField"
    );

    my $DefinitionRef = $Kernel::OM->Get('ITSMConfigItem')->DefinitionGet(
        ClassID => $ClassID,
    );

    my $VersionID = $Kernel::OM->Get('ITSMConfigItem')->VersionAdd(
        ConfigItemID => $ConfigItemID,
        Name         => $Helper->GetRandomID(),
        DefinitionID => $DefinitionRef->{DefinitionID},
        DeplStateID  => $ProductionID,
        InciStateID  => $OperationalID,
        UserID       => 1,
    );

    $Self->True(
        $ConfigItemID,
        "VersionAdd(): Create Version to ConfigItem for DynamicField"
    );

    return $ConfigItemID;
}

sub _CreateTicketDynamicField {
    my (%Param) = @_;

    my $Number     = $Helper->GetRandomNumber();
    my $SystemTime = $Kernel::OM->Get('Time')->SystemTime();
    my $CurrTime   = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
        SystemTime => $SystemTime
    );
    my @Time = $Kernel::OM->Get('Time')->SystemTime2Date(
        SystemTime => $SystemTime
    );
    my $DateTime = "$Time[3].$Time[4].$Time[5], $Time[2]:$Time[1]";
    my $Date     = "$Time[3].$Time[4].$Time[5], 00:00";
    my $CurrDate = "$Time[5]-$Time[4]-$Time[3] 00:00:00";

    my $Version = $Kernel::OM->Get('ITSMConfigItem')->VersionGet(
        ConfigItemID => $Param{ConfigItemID},
        XMLDataGet   => 0
    );

    my %DynamicFields;
    my @DynamicFieldConfigs = (
        {
            FieldType  => 'Text',
            ObjectType => 'Ticket',
            Config     => {},
            Value      => 'Unit Test Text',
            Expection  => {
                All         => 'Unit Test Text',
                ObjectValue => {
                    undef => [
                        'Unit Test Text',
                    ]
                },
            }
        },
        {
            FieldType  => 'TextArea',
            ObjectType => 'Ticket',
            Config     => {
                CountDefault => 1,
                CountMax     => 1,
                CountMin     => 1,
                DefaultValue => undef
            },
            Value      => <<'END',
Unit
Test
TextArea
END
            Expection  => {
                All         => <<'END',
Unit
Test
TextArea
END
                HTML        => 'Unit<br>Test<br>TextArea<br>',
                ObjectValue => {
                    undef => [
<<'END',
Unit
Test
TextArea
END
                    ],
                }
            }
        },
        {
            FieldType  => 'Multiselect',
            ObjectType => 'Ticket',
            Config     => {
                CountDefault        => 1,
                CountMax            => 2,
                CountMin            => 1,
                DefaultValue        => undef,
                PossibleNone        => 1,
                PossibleValues      => {
                    'customer'                    => 'customer',
                    'service provider'            => 'service provider',
                    'supplier/partner (external)' => 'supplier/partner (external)',
                    'supplier/partner (internal)' => 'supplier/partner (internal)'
                },
                TranslatableValues => 1
            },
            Value      => [
                'customer',
                'service provider'
            ],
            Expection  => {
                q{}         => 'Kunde, Service Provider',
                Short       => 'Kunde, Service Provider',
                Key         => 'customer, service provider',
                Value       => 'Kunde, Service Provider',
                HTML        => 'Kunde, Service Provider',
                ObjectValue => {
                    undef => [
                        'customer',
                        'service provider'
                    ],
                    0     => 'customer',
                    1     => 'service provider'
                },
                '! with text' => 'customer,service provider',
                'Value!'      => 'customer, service provider',
                'Key!'        => 'customer, service provider',
                'HTML!'       => 'customer, service provider',
                'Short!'      => 'customer, service provider',
            }
        },
        {
            FieldType  => 'CheckList',
            ObjectType => 'Ticket',
            Config     => {},
            Value      => '[{"id":"100","title":"task 1","description":"","input":"ChecklistState","value":"-"},{"id":"200","title":"task 2","description":"","input":"ChecklistState","value":"-"},{"id":"300","title":"task 3","description":"","input":"ChecklistState","value":"-"}]',
            Expection  => {
                All         => <<"END",
TicketCheckList$Number
- task 1: -
- task 2: -
- task 3: -

END
                Short       => '0/3',
                Key         => "TicketCheckList$Number<br />- task 1: -<br />- task 2: -<br />- task 3: -<br /><br />",
                HTML        => "<h3>TicketCheckList$Number</h3><table style=\"border:none; width:90%\"><thead><tr><th style=\"padding:10px 15px;\">Action</th><th style=\"padding:10px 15px;\">State</th><tr></thead><tbody><tr><td style=\"padding:10px 15px;\">task 1</td><td style=\"padding:10px 15px;\">-</td></tr><tr><td style=\"padding:10px 15px;\">task 2</td><td style=\"padding:10px 15px;\">-</td></tr><tr><td style=\"padding:10px 15px;\">task 3</td><td style=\"padding:10px 15px;\">-</td></tr></tbody></table>",
                ObjectValue => {
                    undef => [
                        '[{"id":"100","title":"task 1","description":"","input":"ChecklistState","value":"-"},{"id":"200","title":"task 2","description":"","input":"ChecklistState","value":"-"},{"id":"300","title":"task 3","description":"","input":"ChecklistState","value":"-"}]',
                    ],
                    0     => '[{"id":"100","title":"task 1","description":"","input":"ChecklistState","value":"-"},{"id":"200","title":"task 2","description":"","input":"ChecklistState","value":"-"},{"id":"300","title":"task 3","description":"","input":"ChecklistState","value":"-"}]',
                }
            }
        },
        {
            FieldType  => 'DateTime',
            ObjectType => 'Ticket',
            Config     => {
                CountDefault    => 1,
                CountMax        => 1,
                CountMin        => 1,
                DateRestriction => 'none',
                DefaultValue    => 0,
                ItemSeparator   =>  q{},
                YearsInFuture   => 0,
                YearsInPast     => 0
            },
            Value      => $CurrTime,
            Expection  => {
                All         => $DateTime,
                ObjectValue => {
                    undef => [
                        $CurrTime
                    ]
                }
            }
        },
        {
            FieldType  => 'Date',
            ObjectType => 'Ticket',
            Config     => {
                CountDefault    => 1,
                CountMax        => 1,
                CountMin        => 1,
                DateRestriction => 'none',
                DefaultValue    => q{},
                ItemSeparator   => q{},
                YearsInFuture   => 0,
                YearsInPast     => 0
            },
            Value      => $CurrTime,
            Expection  => {
                All         => $Date,
                ObjectValue => {
                    undef => [
                        $CurrDate
                    ]
                }
            }
        },
        {
            ObjectType => 'Ticket',
            FieldType  => 'ITSMConfigItemReference',
            Config     => {
                CountDefault          =>  1,
                CountMax              =>  15,
                CountMin              =>  1,
                DefaultValue          => q{},
                DeploymentStates      => [],
                ITSMConfigItemClasses => [

                ],
                ItemSeparator         =>  q{, }
            },
            Value      => [
                $Param{ConfigItemID}
            ],
            Expection  => {
                All         => $Kernel::OM->Get('Config')->Get('ITSMConfigItem::Hook') . $Version->{Number} . ' - ' . $Version->{Name},
                Key         => $Param{ConfigItemID},
                Short       => $Version->{Name},
                ObjectValue => {
                    undef => [
                        $Param{ConfigItemID},
                    ],
                    0     => $Param{ConfigItemID},
                }
            }
        },
        {
            FieldType  => 'Table',
            ObjectType => 'Ticket',
            Config     => {
                Columns => [
                    'Column A',
                    'Column B',
                    'Column C'
                ],
                RowsInit           => 1,
                RowsMax            => 1,
                RowsMin            => 1,
                TranslatableColumn => 0
            },
            Value      => '[["Value 1.0","","Value 3.0"],["Value 1.1","Value 2.1",""],["","Value 2.2",""]]',
            Expection  => {
                All         => 'Function:DisplayValueRender',
                Short       => '3 Zeilen',
                HTML        => <<'END',
<table border="1" cellspacing="0" cellpadding="2">
    <thead>
        <tr>
            <th>Column A</th>
            <th>Column B</th>
            <th>Column C</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Value 1.0</td>
            <td></td>
            <td>Value 3.0</td>
        </tr>
        <tr>
            <td>Value 1.1</td>
            <td>Value 2.1</td>
            <td></td>
        </tr>
        <tr>
            <td></td>
            <td>Value 2.2</td>
            <td></td>
        </tr>
    </tbody>
</table>
END
                ObjectValue => {
                    undef => [
                        '[["Value 1.0","","Value 3.0"],["Value 1.1","Value 2.1",""],["","Value 2.2",""]]',
                    ],
                    0     => '[["Value 1.0","","Value 3.0"],["Value 1.1","Value 2.1",""],["","Value 2.2",""]]',
                }
            }
        },
    );

    for my $Field ( @DynamicFieldConfigs ) {
        my $Name = $Field->{ObjectType}.$Field->{FieldType}.$Number;

        my $ID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
            InternalField        => 0,
            Name                 => $Name,
            Label                => $Name,
            FieldType            => $Field->{FieldType},
            ObjectType           => $Field->{ObjectType},
            Config               => $Field->{Config},
            ValidID              => 1,
            UserID               => 1,
        );

        $Kernel::OM->ObjectsDiscard(
            Objects => [
                'DynamicField'
            ]
        );

        $Self->True(
            $ID,
            "DynamicField ($Name) Add: ObjectType - $Field->{ObjectType} / FieldType - $Field->{FieldType}"
        );

        my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
            Name   => $Name,
            UserID => 1
        );

        if ( $Field->{ObjectType} eq 'Ticket' ) {
            my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
                DynamicFieldConfig => $DynamicFieldConfig,
                ObjectID           => $Param{TicketID},
                Value              => $Field->{Value},
                UserID             => 1,
            );

            for my $Index ( keys %{$Field->{Expection}} ) {
                if ( $Field->{Expection}->{$Index} =~ /^Function:(.*)$/sm ) {
                    my $Function = $1;
                    my $Result = $Kernel::OM->Get('DynamicField::Backend')->$Function(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        ObjectID           => $Param{TicketID},
                        Value              => $Field->{Value},
                        UserID             => 1,
                    );

                    $Field->{Expection}->{$Index} = $Result->{Value} // q{};
                }
            }

            $Self->True(
                $Success,
                "DynamicField Set Value: $Name"
            );

            $DynamicFields{$Name} = $Field->{Expection};
        }
    }

    return %DynamicFields;
}

sub _CreateContactDynamicField {
    my (%Param) = @_;

    my $Number = $Helper->GetRandomNumber();

    my %DynamicFields;
    my @DynamicFieldConfigs = (
        {
            FieldType  => 'Text',
            ObjectType => 'Contact',
            Config     => {},
        },
    );

    for my $Field ( @DynamicFieldConfigs ) {
        my $Name = $Field->{ObjectType}.$Field->{FieldType}.$Number;

        my $ID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
            InternalField        => 0,
            Name                 => $Name,
            Label                => $Name,
            FieldType            => $Field->{FieldType},
            ObjectType           => $Field->{ObjectType},
            Config               => $Field->{Config},
            ValidID              => 1,
            UserID               => 1,
        );

        $Kernel::OM->ObjectsDiscard(
            Objects => [
                'DynamicField'
            ]
        );

        $Self->True(
            $ID,
            "DynamicField ($Name) Add: ObjectType - $Field->{ObjectType} / FieldType - $Field->{FieldType}"
        );

        my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
            Name   => $Name,
            UserID => 1
        );

        if ( $Field->{ObjectType} eq 'Contact' ) {
            for my $Object ( qw( Owner Responsible User ) ) {
                my $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                    UserID  => $Param{ $Object }->{UserID},
                );

                my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
                    DynamicFieldConfig => $DynamicFieldConfig,
                    ObjectID           => $ContactID,
                    Value              => $Param{ $Object }->{UserID},
                    UserID             => 1,
                );

                $Self->True(
                    $Success,
                    "DynamicField Set Value: $Name for $Object"
                );

                $DynamicFields{ $Name } = 1;
            }
        }
    }

    return %DynamicFields;
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