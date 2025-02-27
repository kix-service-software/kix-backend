# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $TimeObject = $Kernel::OM->Get('Time');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get module
if ( !$Kernel::OM->Get('Main')->Require('Kernel::System::Automation::VariableFilter::XMLUtil') ) {
        $Self->True(
        0,
        'Cannot find XMLUtil module!',
    );
    return;

}
my $Module = Kernel::System::Automation::VariableFilter::XMLUtil->new();
if ( !$Module ) {
        $Self->True(
        0,
        'Get module instance failed!',
    );
    return;
}

# get handler
if ( !$Module->can('GetFilterHandler') ) {
    $Self->True(
        0,
        "Module cannot \"GetFilterHandler\"!"
    );
    return;
}
my %Handler = $Module->GetFilterHandler();
$Self->True(
    IsHashRefWithData(\%Handler) || 0,
    'GetFilterHandler()',
);
if (!IsHashRefWithData(\%Handler)) {
    $Self->True(
        0,
        'GetFilterHandler()',
    );
}
$Self->True(
    (keys %Handler) == 1,
    'GetFilterHandler() returns  1 handler',
);

my $TestDate     = "2022-04-20 12:00:00";
my $TestDateUnix = $TimeObject->TimeStamp2SystemTime( String => $TestDate );

# check FromXML
if (!$Handler{'XMLUtil.FromXML'}) {
    $Self->True(
        0,
        '"FromXML" handler is missing',
    );
} else {
    my @FromXMLTests = (
        {
            Name     => 'Undefined value',
            Value    => undef,
            Expected => undef,
            Silent   => 1
        },
        {
            Name     => 'Empty string',
            Value    => '',
            Expected => '',
            Silent   => 1
        },
        {
            Name     => 'Invalid XML',
            Value    => <<'END',
<root>
    <Data>Test</data>
</root>
END
            Expected => '',
            Silent   => 1
        },
        {
            Name     => 'Empty root element',
            Value    => <<'END',
<root></root>
END
            Expected => '',
            Silent   => 0
        },,
        {
            Name     => 'Root element with content',
            Value    => <<'END',
<root>Test</root>
END
            Expected => 'Test',
            Silent   => 0
        },
        {
            Name     => 'Tag "Data" without content',
            Value    => <<'END',
<root>
    <Data></Data>
</root>
END
            Expected => {
                Data => ''
            },
            Silent   => 0
        },
        {
            Name     => 'Tag "Data" with content',
            Value    => <<'END',
<root>
    <Data>Test</Data>
</root>
END
            Expected => {
                Data => 'Test'
            },
            Silent   => 0
        },
        {
            Name     => 'Tag "Data" twice with content',
            Value    => <<'END',
<root>
    <Data>Test1</Data>
    <Data>Test2</Data>
</root>
END
            Expected => {
                Data => [
                    'Test1',
                    'Test2'
                ]
            },
            Silent   => 0
        },
        {
            Name     => 'Data with sub child',
            Value    => <<'END',
<root>
    <child>
        <subchild>Test</subchild>
    </child>
</root>
END
            Expected => {
                child => {
                    subchild => 'Test'
                }
            },
            Silent   => 0
        },
        {
            Name     => 'Data with header',
            Value    => <<'END',
<?xml version="1.0" encoding="UTF-8"?>
<note>
    <to>Tove</to>
    <from>Jani</from>
    <heading>Reminder</heading>
    <body>Don't forget me this weekend!</body>
</note>
END
            Expected => {
                to      => 'Tove',
                from    => 'Jani',
                heading => 'Reminder',
                body    => 'Don\'t forget me this weekend!'
            },
            Silent   => 0
        },
        {
            Name     => 'Data with attributes',
            Value    => <<'END',
<bookstore>
    <book category="children">
        <title>Harry Potter</title>
        <author>J K. Rowling</author>
        <year>2005</year>
        <price>29.99</price>
    </book>
    <book category="web">
        <title>Learning XML</title>
        <author>Erik T. Ray</author>
        <year>2003</year>
        <price>39.95</price>
    </book>
</bookstore>
END
            Expected => {
                book => [
                    {
                        category => 'children',
                        title    => 'Harry Potter',
                        author   => 'J K. Rowling',
                        year     => '2005',
                        price    => '29.99'
                    },
                    {
                        category => 'web',
                        title    => 'Learning XML',
                        author   => 'Erik T. Ray',
                        year     => '2003',
                        price    => '39.95'
                    }
                ]
            },
            Silent   => 0
        },
        {
            Name     => 'Data with namespaces',
            Value    => <<'END',
<root>
    <h:table xmlns:h="http://www.w3.org/TR/html4/">
    <h:tr>
        <h:td>Apples</h:td>
        <h:td>Bananas</h:td>
    </h:tr>
    </h:table>

    <f:table xmlns:f="https://www.w3schools.com/furniture">
        <f:name>African Coffee Table</f:name>
        <f:width>80</f:width>
        <f:length>120</f:length>
    </f:table>
</root>
END
            Expected => {
                'h_table' => {
                    'h_tr' => {
                        'h_td' => [
                            'Apples',
                            'Bananas'
                        ]
                    },
                    'xmlns_h' => 'http://www.w3.org/TR/html4/'
                },
                'f_table' => {
                    'f_name' => 'African Coffee Table',
                    'f_width' => '80',
                    'f_length' => '120',
                    'xmlns_f' => 'https://www.w3schools.com/furniture'
                }
            },
            Silent   => 0
        },
        {
            Name     => 'Tag with namespace, without child',
            Value    => <<'END',
<root>
    <h:p xmlns:h="http://www.w3.org/TR/html4/">Test</h:p>
</root>
END
            Expected => {
                'h_p' => {
                    'content' => 'Test',
                    'xmlns_h' => 'http://www.w3.org/TR/html4/'
                }
            },
            Silent   => 0
        }
    );
    for my $Test ( @FromXMLTests ) {
        my $Result = $Handler{'XMLUtil.FromXML'}->(
            {},
            Value  => $Test->{Value},
            Silent => $Test->{Silent}
        );

        $Self->IsDeeply(
            $Result,
            $Test->{Expected},
            $Test->{Name}
        );
    }
}

# check if filter is used in macro execution
my $AutomationObject = $Kernel::OM->Get('Automation');
my $MacroID          = $AutomationObject->MacroAdd(
    Name    => 'test-macro-for-filter-check',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroID || 0,
    'MacroAdd()',
);
my $MacroActionID_1 = $AutomationObject->MacroActionAdd(
    MacroID => $MacroID,
    Type    => 'VariableSet',
    Parameters      => { Value => '<root><h:p xmlns:h="http://www.w3.org/TR/html4/">Test</h:p></root>' },
    ResultVariables => { Variable => 'Set_A'},
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroActionID_1 || 0,
    'MacroActionAdd() 1',
);
my $MacroActionID_2 = $AutomationObject->MacroActionAdd(
    MacroID => $MacroID,
    Type    => 'VariableSet',
    # check also if camelcase is irrelevant (FromXML "=" fromxml)
    Parameters      => { Value => '${Set_A|XMLUtil.fromxml}' },
    ResultVariables => { Variable => 'Set_B'},
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroActionID_2 || 0,
    'MacroActionAdd() 2',
);
my $MacroActionID_3 = $AutomationObject->MacroActionAdd(
    MacroID => $MacroID,
    Type    => 'VariableSet',
    # check with unknown filter (no change should be done)
    Parameters      => { Value => '${Set_A|XMLUtil.unknown}' },
    ResultVariables => { Variable => 'Set_C'},
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroActionID_3 || 0,
    'MacroActionAdd() 3',
);
my $MacroUpdateResult = $AutomationObject->MacroUpdate(
    ID        => $MacroID,
    ExecOrder => [$MacroActionID_1, $MacroActionID_2, $MacroActionID_3],
    UserID    => 1
);
$Self->True(
    $MacroUpdateResult || 0,
    'MacroUpdate()',
);
my $Success = $AutomationObject->MacroExecute(
    ID       => $MacroID,
    ObjectID => 9999,
    UserID   => 1
);
$Self->True(
    $Success || 0,
    'MacroExecute()',
);
$Self->True(
    IsHashRefWithData($AutomationObject->{MacroVariables}) || 0,
    'MacroVariables is hash ref',
);
$Self->IsDeeply(
    $AutomationObject->{MacroVariables}->{Set_B},
    {
        'h_p' => {
            'content' => 'Test',
            'xmlns_h' => 'http://www.w3.org/TR/html4/'
        }
    },
    'Result of 2nd action',
);
$Self->IsDeeply(
    $AutomationObject->{MacroVariables}->{Set_C},
    '<root><h:p xmlns:h="http://www.w3.org/TR/html4/">Test</h:p></root>',
    "Result of 3nd action",
);

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
