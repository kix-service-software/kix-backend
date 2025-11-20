# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

use vars qw($Self);

# check supported methods
for my $Method (
    qw(
        Encode Decode
        True False
        Jq
    )
) {
    $Self->True(
        $Kernel::OM->Get('JSON')->can($Method),
        'JSON object can "' . $Method . '"'
    );
}

# tests for JSON encode method
my @Tests = (
    {
        Name   => 'JSON->Encode: undef test',
        Input  => undef,
        Result => 'null',
        Silent => 1,
    },
    {
        Name   => 'JSON->Encode: empty test',
        Input  => '',
        Result => '""',
    },
    {
        Name   => 'JSON->Encode: simple',
        Input  => 'Some Text',
        Result => '"Some Text"',
    },
    {
        Name   => 'JSON->Encode: simple',
        Input  => 42,
        Result => '42',
    },
    {
        Name   => 'JSON->Encode: simple',
        Input  => [ 1, 2, "3", "Foo", 5 ],
        Result => '[1,2,"3","Foo",5]',
    },
    {
        Name   => 'JSON->Encode: simple',
        Input  => {
            Key1   => "Value1",
            Key2   => 42,
            "Key3" => "Another Value"
        },
        Result => '{"Key1":"Value1","Key2":42,"Key3":"Another Value"}',
    },
    {
        Name   => 'JSON->Encode: bool true',
        Input  => Kernel::System::JSON::True(),
        Result => 'true',
    },
    {
        Name   => 'JSON->Encode: bool false',
        Input  => Kernel::System::JSON::False(),
        Result => 'false',
    },
    {
        Name   => 'JSON->Encode: complex structure',
        Input  => [
            [ 1, 2, "Foo", "Bar" ],
            {
                Key1 => 'Something',
                Key2 => [ "Foo", "Bar" ],
                Key3 => {
                    Foo => 'Bar',
                },
                Key4 => {
                    Bar => [ "f", "o", "o" ]
                    }
            },
        ],
        Result =>
            '[[1,2,"Foo","Bar"],{"Key1":"Something","Key2":["Foo","Bar"],"Key3":{"Foo":"Bar"},"Key4":{"Bar":["f","o","o"]}}]',
    },
    {
        Name   => 'JSON->Encode: Unicode Line Terminators are not allowed in JavaScript',
        Input  => "Some Text with Unicode Characters that  are not allowed\x{2029} in JavaScript",
        Result => '"Some Text with Unicode Characters that\u2028 are not allowed\u2029 in JavaScript"',
    }
);
for my $Test (@Tests) {
    my $JSON = $Kernel::OM->Get('JSON')->Encode(
        Data     => $Test->{Input},
        SortKeys => 1,
        Silent   => $Test->{Silent},
    );

    $Self->Is(
        $JSON,
        $Test->{Result},
        $Test->{Name},
    );
}

# tests for JSON decode method
@Tests = (
    {
        Name   => 'JSON->Decode: undef test',
        Data   => undef,
        Result => undef,
        Silent => 1,
    },
    {
        Name   => 'JSON->Decode: malformed data test',
        Data   => '" bla blubb',
        Result => undef,
        Silent => 1,
    },
    {
        Name   => 'JSON->Decode: null',
        Data   => 'null',
        Result => undef,
    },
    {
        Name   => 'JSON->Decode: simple string',
        Data   => '"Some Text"',
        Result => 'Some Text',
    },
    {
        Name   => 'JSON->Decode: simple number',
        Data   => '42',
        Result => 42,
    },
    {
        Name   => 'JSON->Decode: simple array',
        Data   => '[1,2,"3","Foo",5]',
        Result => [ 1, 2, "3", "Foo", 5 ],
    },
    {
        Name   => 'JSON->Decode: simple hash',
        Data   => '{"Key1":"Value1","Key2":42,"Key3":"Another Value"}',
        Result => {
            Key1   => "Value1",
            Key2   => 42,
            "Key3" => "Another Value"
        },
    },
    {
        Name   => 'JSON->Decode: complex structure',
        Data   => '[[1,2,"Foo","Bar"],{"Key1":"Something","Key2":["Foo","Bar"],"Key3":{"Foo":"Bar"},"Key4":{"Bar":["f","o","o"]}}]',
        Result => [
            [ 1, 2, "Foo", "Bar" ],
            {
                Key1 => 'Something',
                Key2 => [ "Foo", "Bar" ],
                Key3 => {
                    Foo => 'Bar',
                },
                Key4 => {
                    Bar => [ "f", "o", "o" ]
                    }
            },
        ],
    },
    {
        Name   => 'JSON->Decode: boolean true',
        Data   => 'true',
        Result => 1,
    },
    {
        Name   => 'JSON->Decode: boolean false',
        Data   => 'false',
        Result => undef,
    },
    {
        Name   => 'JSON->Decode: hash containing boolean true value',
        Data   => '{"Key1" : true}',
        Result => {
            Key1 => 1,
        },
    },
    {
        Name   => 'JSON->Decode: hash containing boolean false value',
        Data   => '{"Key1" : false}',
        Result => {
            Key1 => 0,
        },
    },
    {
        Name   => 'JSON->Decode: array containing booleans',
        Data   => '[1,false,"3","Foo",true]',
        Result => [ 1, 0, "3", "Foo", 1 ],
    },
    {
        Name   => 'JSON->Decode: complex structure containing booleans',
        Data => '[[true,2,"Foo","Bar"],{"Key1":false,"Key2":["Foo","Bar"],"Key3":{"Foo":true},"Key4":{"Bar":[false,"o",true]}}]',
        Result => [
            [ 1, 2, "Foo", "Bar" ],
            {
                Key1 => 0,
                Key2 => [ "Foo", "Bar" ],
                Key3 => {
                    Foo => 1,
                },
                Key4 => {
                    Bar => [ 0, "o", 1 ]
                    }
            },
        ],
    },
);
for my $Test (@Tests) {
    my $JSON = $Kernel::OM->Get('JSON')->Decode(
        Data   => $Test->{Data},
        Silent => $Test->{Silent},
    );

    $Self->IsDeeply(
        $JSON,
        $Test->{Result},
        $Test->{Name},
    );
}

# test for JSON true method
$Self->IsDeeply(
     $Kernel::OM->Get('JSON')->True(),
    \1,
    'JSON->True',
);

# test for JSON false method
$Self->IsDeeply(
     $Kernel::OM->Get('JSON')->False(),
    \0,
    'JSON->False',
);

# tests for JSON jq method
@Tests = (
    {
        Name   => 'JSON->Jq: undef data',
        Data   => undef,
        Filter => '. - map(. | select(.Flag=="b")) | .[] .Key',
        Result => undef,
        Silent => 1,
    },
    {
        Name   => 'JSON->Jq: undef filter',
        Data   => '[
            { "Key": 1, "Value": 1111, "Flag": "a" },
            { "Key": 2, "Value": 2222, "Flag": "b" },
            { "Key": 3, "Value": 3333, "Flag": "a" }
        ]',
        Filter => undef,
        Result => undef,
        Silent => 1,
    },
    {
        Name   => 'JSON->Jq: simple test',
        Data   => '[
            { "Key": 1, "Value": 1111, "Flag": "a" },
            { "Key": 2, "Value": 2222, "Flag": "b" },
            { "Key": 3, "Value": 3333, "Flag": "a" }
        ]',
        Filter => '. - map(. | select(.Flag=="b")) | .[] .Key',
        Result => "1\n3",
    }
);
for my $Test (@Tests) {
    my $JSON = $Kernel::OM->Get('JSON')->Jq(
        Data   => $Test->{Data},
        Filter => $Test->{Filter},
        Silent => $Test->{Silent},
    );

    $Self->IsDeeply(
        $JSON,
        $Test->{Result},
        $Test->{Name},
    );
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