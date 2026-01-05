# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get module
if ( !$Kernel::OM->Get('Main')->Require('Kernel::System::Automation::VariableFilter::BaseUtil') ) {
        $Self->True(
        0,
        'Cannot find BaseUtil module!',
    );
    return;
}
my $Module = Kernel::System::Automation::VariableFilter::BaseUtil->new();
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
if (!IsHashRefWithData(\%Handler)) {
    $Self->True(
        0,
        'GetFilterHandler()',
    );
}
else {
    my @HandlerList = keys( %Handler );
    $Self->IsDeeply(
        \@HandlerList,
        [
            'JSON',
            'ToJSON',
            'FromJSON',
            'JQ',
            'Base64',
            'ToBase64',
            'FromBase64',
            'AsConditionString',
        ],
        'GetFilterHandler()',
        1
    );
}

my @Tests = (
    {
        Name      => 'JSON: undef value',
        Handler   => 'JSON',
        Value     => undef,
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'JSON: empty string',
        Handler   => 'JSON',
        Value     => '',
        Parameter => undef,
        Expected  => ''
    },
    {
        Name      => 'JSON: simple string',
        Handler   => 'JSON',
        Value     => 'abcäöüß!"§$%&/()=?\\\'123*',
        Parameter => undef,
        Expected  => 'abcäöüß!\\"§$%\\u0026/()=?\\\\\'123*'
    },
    {
        Name      => 'JSON: multiline string',
        Handler   => 'JSON',
        Value     => "abcäöüß!\"\n§\$\%&/()=?\\'123*",
        Parameter => undef,
        Expected  => 'abcäöüß!\\"\\n§$%\\u0026/()=?\\\\\'123*'
    },
    {
        Name      => 'JSON: empty hash',
        Handler   => 'JSON',
        Value     => {},
        Parameter => undef,
        Expected  => '{}'
    },
    {
        Name      => 'JSON: simple hash',
        Handler   => 'JSON',
        Value     => {
            key => 'value'
        },
        Parameter => undef,
        Expected  => '{"key":"value"}'
    },
    {
        Name      => 'JSON: empty array',
        Handler   => 'JSON',
        Value     => [],
        Parameter => undef,
        Expected  => '[]'
    },
    {
        Name      => 'JSON: simple array',
        Handler   => 'JSON',
        Value     => ['value'],
        Parameter => undef,
        Expected  => '["value"]'
    },
    {
        Name      => 'JSON: array of hashes',
        Handler   => 'JSON',
        Value     => [
            {
                key => 'value'
            },
            {
                key => 'value'
            }
        ],
        Parameter => undef,
        Expected  => '[{"key":"value"},{"key":"value"}]'
    },
    {
        Name      => 'JSON: hash with array value',
        Handler   => 'JSON',
        Value     => {
            key => ['value']
        },
        Parameter => undef,
        Expected  => '{"key":["value"]}'
    },
    {
        Name      => 'ToJSON: undef value',
        Handler   => 'ToJSON',
        Value     => undef,
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'ToJSON: empty string',
        Handler   => 'ToJSON',
        Value     => '',
        Parameter => undef,
        Expected  => ''
    },
    {
        Name      => 'ToJSON: simple string',
        Handler   => 'ToJSON',
        Value     => 'abcäöüß!"§$%&/()=?\\\'123*',
        Parameter => undef,
        Expected  => 'abcäöüß!\\"§$%\\u0026/()=?\\\\\'123*'
    },
    {
        Name      => 'ToJSON: multiline string',
        Handler   => 'ToJSON',
        Value     => "abcäöüß!\"\n§\$\%&/()=?\\'123*",
        Parameter => undef,
        Expected  => 'abcäöüß!\\"\\n§$%\\u0026/()=?\\\\\'123*'
    },
    {
        Name      => 'ToJSON: empty hash',
        Handler   => 'ToJSON',
        Value     => {},
        Parameter => undef,
        Expected  => '{}'
    },
    {
        Name      => 'ToJSON: simple hash',
        Handler   => 'ToJSON',
        Value     => {
            key => 'value'
        },
        Parameter => undef,
        Expected  => '{"key":"value"}'
    },
    {
        Name      => 'ToJSON: empty array',
        Handler   => 'ToJSON',
        Value     => [],
        Parameter => undef,
        Expected  => '[]'
    },
    {
        Name      => 'ToJSON: simple array',
        Handler   => 'ToJSON',
        Value     => ['value'],
        Parameter => undef,
        Expected  => '["value"]'
    },
    {
        Name      => 'ToJSON: array of hashes',
        Handler   => 'ToJSON',
        Value     => [
            {
                key => 'value'
            },
            {
                key => 'value'
            }
        ],
        Parameter => undef,
        Expected  => '[{"key":"value"},{"key":"value"}]'
    },
    {
        Name      => 'ToJSON: hash with array value',
        Handler   => 'ToJSON',
        Value     => {
            key => ['value']
        },
        Parameter => undef,
        Expected  => '{"key":["value"]}'
    },
    {
        Name      => 'FromJSON: undef value',
        Handler   => 'FromJSON',
        Value     => undef,
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'FromJSON: empty string',
        Handler   => 'FromJSON',
        Value     => '',
        Parameter => undef,
        Expected  => ''
    },
    {
        Name      => 'FromJSON: simple string',
        Handler   => 'FromJSON',
        Value     => '"abcäöüß!\\"§$%&/()=?\\\\\'123*"',
        Parameter => undef,
        Expected  => 'abcäöüß!"§$%&/()=?\\\'123*'
    },
    {
        Name      => 'FromJSON: multiline string',
        Handler   => 'FromJSON',
        Value     => '"abcäöüß!\\"\\n§$%&/()=?\\\\\'123*"',
        Parameter => undef,
        Expected  => "abcäöüß!\"\n§\$\%&/()=?\\'123*"
    },
    {
        Name      => 'FromJSON: empty hash',
        Handler   => 'FromJSON',
        Value     => '{}',
        Parameter => undef,
        Expected  => {}
    },
    {
        Name      => 'FromJSON: simple hash',
        Handler   => 'FromJSON',
        Value     => '{"key":"value"}',
        Parameter => undef,
        Expected  => {
            key => 'value'
        }
    },
    {
        Name      => 'FromJSON: empty array',
        Handler   => 'FromJSON',
        Value     => '[]',
        Parameter => undef,
        Expected  => []
    },
    {
        Name      => 'FromJSON: simple array',
        Handler   => 'FromJSON',
        Value     => '["value"]',
        Parameter => undef,
        Expected  => ['value']
    },
    {
        Name      => 'FromJSON: array of hashes',
        Handler   => 'FromJSON',
        Value     => '[{"key":"value"},{"key":"value"}]',
        Parameter => undef,
        Expected  => [
            {
                key => 'value'
            },
            {
                key => 'value'
            }
        ]
    },
    {
        Name      => 'FromJSON: hash with array value',
        Handler   => 'FromJSON',
        Value     => '{"key":["value"]}',
        Parameter => undef,
        Expected  => {
            key => ['value']
        }
    },
    {
        Name      => 'JQ: undef value',
        Handler   => 'JQ',
        Value     => undef,
        Parameter => '. - map(. :: select(.Flag=="b")) :: .[] .Key',
        Expected  => undef
    },
    {
        Name      => 'JQ: undef parameter',
        Handler   => 'JQ',
        Value     => '[
    { "Key": 1, "Value": 1111, "Flag": "a" },
    { "Key": 2, "Value": 2222, "Flag": "b" },
    { "Key": 3, "Value": 3333, "Flag": "a" }
]',
        Parameter => undef,
        Expected  => '[
    { "Key": 1, "Value": 1111, "Flag": "a" },
    { "Key": 2, "Value": 2222, "Flag": "b" },
    { "Key": 3, "Value": 3333, "Flag": "a" }
]'
    },
    {
        Name      => 'JQ: simple test',
        Handler   => 'JQ',
        Value     => '[
    { "Key": 1, "Value": 1111, "Flag": "a" },
    { "Key": 2, "Value": 2222, "Flag": "b" },
    { "Key": 3, "Value": 3333, "Flag": "a" }
]',
        Parameter => '. - map(. :: select(.Flag=="b")) :: .[] .Key',
        Expected  => "1\n3",
    },
    {
        Name      => 'Base64: undef value',
        Handler   => 'Base64',
        Value     => undef,
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'Base64: empty string',
        Handler   => 'Base64',
        Value     => '',
        Parameter => undef,
        Expected  => ''
    },
    {
        Name      => 'Base64: simple string',
        Handler   => 'Base64',
        Value     => 'abcäöüß!"§$%&/()=?\\\'123*',
        Parameter => undef,
        Expected  => 'YWJj5Pb83yEipyQlJi8oKT0/XCcxMjMq'
    },
    {
        Name      => 'Base64: multiline string',
        Handler   => 'Base64',
        Value     => "abcäöüß!\"\n§\$\%&/()=?\\'123*",
        Parameter => undef,
        Expected  => 'YWJj5Pb83yEiCqckJSYvKCk9P1wnMTIzKg=='
    },
    {
        Name      => 'ToBase64: undef value',
        Handler   => 'ToBase64',
        Value     => undef,
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'ToBase64: empty string',
        Handler   => 'ToBase64',
        Value     => '',
        Parameter => undef,
        Expected  => ''
    },
    {
        Name      => 'ToBase64: simple string',
        Handler   => 'ToBase64',
        Value     => 'abcäöüß!"§$%&/()=?\\\'123*',
        Parameter => undef,
        Expected  => 'YWJj5Pb83yEipyQlJi8oKT0/XCcxMjMq'
    },
    {
        Name      => 'ToBase64: multiline string',
        Handler   => 'ToBase64',
        Value     => "abcäöüß!\"\n§\$\%&/()=?\\'123*",
        Parameter => undef,
        Expected  => 'YWJj5Pb83yEiCqckJSYvKCk9P1wnMTIzKg=='
    },
    {
        Name      => 'FromBase64: undef value',
        Handler   => 'FromBase64',
        Value     => undef,
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'FromBase64: empty string',
        Handler   => 'FromBase64',
        Value     => '',
        Parameter => undef,
        Expected  => ''
    },
    {
        Name      => 'FromBase64: simple string',
        Handler   => 'FromBase64',
        Value     => 'YWJj5Pb83yEipyQlJi8oKT0/XCcxMjMq',
        Parameter => undef,
        Expected  => 'abcäöüß!"§$%&/()=?\\\'123*'
    },
    {
        Name      => 'FromBase64: multiline string in base64',
        Handler   => 'FromBase64',
        Value     => 'YWJj5Pb83yEiCqckJSYvKCk9P1wnMTIzKg==',
        Parameter => undef,
        Expected  => "abcäöüß!\"\n§\$\%&/()=?\\'123*"
    },
    {
        Name      => 'FromBase64: multiline string as base64',
        Handler   => 'FromBase64',
        Value     => 'RGFzIGlzdCBlaW4gVGVzdCBtaXQgdW1nZWJyb2NoZW5lbiBCYXNlNjQtQ29kZSwgd2llIGJlaSBN
SU1FLU5hY2hyaWNodGVu',
        Parameter => undef,
        Expected  => "Das ist ein Test mit umgebrochenen Base64-Code, wie bei MIME-Nachrichten"
    },
    {
        Name      => 'AsConditionString: undef value',
        Handler   => 'AsConditionString',
        Value     => undef,
        Parameter => undef,
        Expected  => undef
    },
    {
        Name      => 'AsConditionString: empty string',
        Handler   => 'AsConditionString',
        Value     => '',
        Parameter => undef,
        Expected  => "''"
    },
    {
        Name      => 'AsConditionString: simple string',
        Handler   => 'AsConditionString',
        Value     => '$Test,%Test,@Test,\'Test\'',
        Parameter => undef,
        Expected  => "'\$Test,\%Test,\@Test,\\\'Test\\\''"
    }
);
for my $Test ( @Tests ) {
    my $Result = $Handler{ $Test->{Handler} }->(
        {},
        Filter    => $Test->{Handler},
        Value     => $Test->{Value},
        Parameter => $Test->{Parameter},
    );
    $Self->IsDeeply(
        $Result,
        $Test->{Expected},
        $Test->{Name},
    );
}

# rollback transaction on database
$Helper->Rollback();

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
