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

use vars qw( $Self %Param );

# get YAML object
my $YAMLObject = $Kernel::OM->Get('YAML');

my @Tests = (
    {
        Input  => undef,
        Result => undef,
        Name   => 'YAML - undef test',
        Silent => 1,
    },
    {
        Input  => '',
        Result => "--- ''\n",
        Name   => 'YAML - empty test',
    },
    {
        Input  => 'Some Text',
        Result => "--- Some Text\n",
        Name   => 'YAML - simple',
    },
    {
        Input  => 42,
        Result => "--- 42\n",
        Name   => 'YAML - simple',
    },
    {
        Input  => [ 1, 2, "3", "Foo", 5 ],
        Result => "---\n- 1\n- 2\n- '3'\n- Foo\n- 5\n",
        Name   => 'YAML - simple',
    },
    {
        Input => {
            Key1   => "Value1",
            Key2   => 42,
            "Key3" => "Another Value"
        },
        Result => "---\nKey1: Value1\nKey2: 42\nKey3: Another Value\n",
        Name   => 'YAML - simple',
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
            "---\n"
            . "- - 1\n"
            . "  - 2\n"
            . "  - Foo\n"
            . "  - Bar\n"
            . "- Key1: Something\n"
            . "  Key2:\n"
            . "  - Foo\n"
            . "  - Bar\n"
            . "  Key3:\n"
            . "    Foo: Bar\n"
            . "  Key4:\n"
            . "    Bar:\n"
            . "    - f\n"
            . "    - o\n"
            . "    - o\n",
        Name => 'YAM - complex structure',
    },
);

for my $Test (@Tests) {

    my $YAML = $YAMLObject->Dump(
        Data   => $Test->{Input},
        Silent => $Test->{Silent},
    );

    if ( defined( $Test->{Result} ) ) {
        $Self->IsDeeply(
            $YAML,
            $Test->{Result},
            $Test->{Name},
        );
    }
    else {
        $Self->False(
            $YAML,
            $Test->{Name},
        );
    }
}

@Tests = (
    {
        Result    => undef,
        InputLoad => undef,
        Name      => 'YAML - undef test',
        Silent    => 1,
    },
    {
        Result    => undef,
        InputLoad => "--- Key: malformed\n - 1\n",
        Name      => 'YAML - malformed data test',
        Silent    => 1,
    },
    {
        Result    => 'Some Text',
        InputLoad => "--- Some Text\n",
        Name      => 'YAML - simple'
    },
    {
        Result    => 42,
        InputLoad => "--- 42\n",
        Name      => 'YAML - simple'
    },
    {
        Result    => [ 1, 2, "3", "Foo", 5 ],
        InputLoad => "---\n- 1\n- 2\n- '3'\n- Foo\n- 5\n",
        Name      => 'YAML - simple'
    },
    {
        Result => {
            Key1   => "Value1",
            Key2   => 42,
            "Key3" => "Another Value"
        },
        InputLoad => "---\nKey1: Value1\nKey2: 42\nKey3: Another Value\n",
        Name      => 'YAML - simple'
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
        InputLoad =>
            "---\n"
            . "- - 1\n"
            . "  - 2\n"
            . "  - Foo\n"
            . "  - Bar\n"
            . "- Key1: Something\n"
            . "  Key2:\n"
            . "  - Foo\n"
            . "  - Bar\n"
            . "  Key3:\n"
            . "    Foo: Bar\n"
            . "  Key4:\n"
            . "    Bar:\n"
            . "    - f\n"
            . "    - o\n"
            . "    - o\n",
        Name => 'YAML - complex structure'
    },
);

for my $Test (@Tests) {
    my $Perl = $YAMLObject->Load(
        Data   => $Test->{InputLoad},
        Silent => $Test->{Silent},
    );

    if ( defined( $Test->{Result} ) ) {
        $Self->IsDeeply(
            $Perl,
            $Test->{Result},
            $Test->{Name},
        );
    }
    else {
        $Self->False(
            $Perl,
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
