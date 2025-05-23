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

use vars qw( $Self %Param );

# get needed objects
my $JSONObject = $Kernel::OM->Get('JSON');

# Tests for JSON encode method
my @Tests = (
    {
        Input  => undef,
        Result => 'null',
        Name   => 'JSON - undef test',
        Silent => 1,
    },
    {
        Input  => '',
        Result => '""',
        Name   => 'JSON - empty test',
    },
    {
        Input  => 'Some Text',
        Result => '"Some Text"',
        Name   => 'JSON - simple'
    },
    {
        Input  => 42,
        Result => '42',
        Name   => 'JSON - simple'
    },
    {
        Input  => [ 1, 2, "3", "Foo", 5 ],
        Result => '[1,2,"3","Foo",5]',
        Name   => 'JSON - simple'
    },
    {
        Input => {
            Key1   => "Value1",
            Key2   => 42,
            "Key3" => "Another Value"
        },
        Result => '{"Key1":"Value1","Key2":42,"Key3":"Another Value"}',
        Name   => 'JSON - simple'
    },
    {
        Input  => Kernel::System::JSON::True(),
        Result => 'true',
        Name   => 'JSON - bool true'
    },
    {
        Input  => Kernel::System::JSON::False(),
        Result => 'false',
        Name   => 'JSON - bool false'
    },
    {
        Input => [
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
        Name => 'JSON - complex structure'
    },
    {
        Input  => "Some Text with Unicode Characters that  are not allowed\x{2029} in JavaScript",
        Result => '"Some Text with Unicode Characters that\u2028 are not allowed\u2029 in JavaScript"',
        Name   => 'JSON - Unicode Line Terminators are not allowed in JavaScript',
    }
);

for my $Test (@Tests) {

    my $JSON = $JSONObject->Encode(
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

@Tests = (
    {
        Result      => undef,
        InputDecode => undef,
        Name        => 'JSON - undef test',
        Silent      => 1,
    },
    {
        Result      => undef,
        InputDecode => '" bla blubb',
        Name        => 'JSON - malformed data test',
        Silent      => 1,
    },
    {
        Result      => 'Some Text',
        InputDecode => '"Some Text"',
        Name        => 'JSON - simple'
    },
    {
        Result      => 42,
        InputDecode => '42',
        Name        => 'JSON - simple'
    },
    {
        Result      => [ 1, 2, "3", "Foo", 5 ],
        InputDecode => '[1,2,"3","Foo",5]',
        Name        => 'JSON - simple'
    },
    {
        Result => {
            Key1   => "Value1",
            Key2   => 42,
            "Key3" => "Another Value"
        },
        InputDecode => '{"Key1":"Value1","Key2":42,"Key3":"Another Value"}',
        Name        => 'JSON - simple'
    },
    {
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
        InputDecode =>
            '[[1,2,"Foo","Bar"],{"Key1":"Something","Key2":["Foo","Bar"],"Key3":{"Foo":"Bar"},"Key4":{"Bar":["f","o","o"]}}]',
        Name => 'JSON - complex structure'
    },
    {
        Result => {'Test' => 1},
        InputDecode =>
            '{"Test":true}',
        Name => 'JSON - booleans'
    },
    {
        Result => {'Test' => 0},
        InputDecode =>
            '{"Test":false}',
        Name => 'JSON - booleans2'
    },
    {
        Result => {
            Key1 => 1,
        },
        InputDecode =>
            '{"Key1" : true}',
        Name => 'JSON - hash containing booleans'
    },
    {
        Result => {
            Key1 => 0,
        },
        InputDecode =>
            '{"Key1" : false}',
        Name => 'JSON - hash containing booleans2'
    },
    {
        Result      => [ 1, 0, "3", "Foo", 1 ],
        InputDecode => '[1,false,"3","Foo",true]',
        Name        => 'JSON - array containing booleans'
    },
    {
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
        InputDecode =>
            '[[true,2,"Foo","Bar"],{"Key1":false,"Key2":["Foo","Bar"],"Key3":{"Foo":true},"Key4":{"Bar":[false,"o",true]}}]',
        Name => 'JSON - complex structure containing booleans'
    },
);

for my $Test (@Tests) {

    my $JSON = $JSONObject->Decode(
        Data   => $Test->{InputDecode},
        Silent => $Test->{Silent},
    );

    if ( defined( $Test->{Result} ) ) {
        $Self->IsDeeply(
            $JSON,
            $Test->{Result},
            $Test->{Name},
        );
    }
    else {
        $Self->Is(
            $JSON,
            $Test->{Result},
            $Test->{Name},
        );
    }
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
