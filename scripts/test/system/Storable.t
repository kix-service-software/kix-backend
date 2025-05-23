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

use vars (qw($Self));

my @Tests = (
    {
        Name    => 'Simple string',
        Data    => 'Teststring <tag> äß@ø " \\" \' \'\'',
        Success => 0,
        Silent  => 1,
    },
    {
        Name    => 'Simple string reference',
        Data    => \'Teststring <tag> äß@ø " \\" \' \'\'',
        Success => 1,
    },
    {
        Name    => 'Simple hash reference',
        Data    => { Test => 1 },
        Success => 1,
    },
    {
        Name => 'Complex data',
        Data => {
            Key   => 'Teststring <tag> äß@ø " \\" \' \'\'',
            Value => [
                {
                    Subkey  => 'Value',
                    Subkey2 => undef,
                },
                1234,
                0,
                undef,
                'Teststring <tag> äß@ø " \\" \' \'\'',
            ],
        },
        Success => 1,
    },
    {
        Name => 'Complex data 2',
        Data => {
            Key1 => [
                'one',
                2,
                3 => {
                    Key   => 'Key',
                    Value => 'Value',
                },
            ],
            Key2 => 'Teststring <tag> äß@ø " \\" \' \'\'',
            Key3 => {
                Key   => 'Key',
                Value => 'Value',
            },
        },
        Success => 1,
    },
    {
        Name    => 'UTF8 string reference',
        Data    => \'kéy',
        Success => 1,
    },
    {
        Name    => 'UTF8 string reference without UTF8-Flag',
        Data    => \'k\x{e9}y',
        Success => 1,
    },
    {
        Name    => 'Very long string reference',
        Data    => \( ' äø<>"\'' x 40_000 ),
        Success => 1,
    },
);

my $StorableObject = $Kernel::OM->Get('Storable');

for my $Test (@Tests) {

    my $StorableString = $StorableObject->Serialize(
        Data   => $Test->{Data},
        Silent => $Test->{Silent},
    );
    my $StorableData   = $StorableObject->Deserialize(
        Data   => $StorableString,
        Silent => $Test->{Silent},
    );
    my $StorableClone  = $StorableObject->Clone(
        Data   => $Test->{Data},
        Silent => $Test->{Silent},
    );

    if ( $Test->{Success} ) {
        $Self->IsDeeply(
            $StorableData,
            $Test->{Data},
            "$Test->{Name} Serialize / Deserialize",
        );
        $Self->IsDeeply(
            $StorableClone,
            $Test->{Data},
            "$Test->{Name} Clone",
        );
    }
    else {
        $Self->False(
            $StorableData,
            "$Test->{Name} Serialize / Deserialize (with false)",
        );
        $Self->False(
            $StorableClone,
            "$Test->{Name} Clone (with false)",
        );
    }
}

# deserialize failure tests
@Tests = (
    {
        Name => 'None serialized data',
        Data => {
            Test => 1,
        },
        Silent => 1,
    },
);

for my $Test (@Tests) {

    my $StorableData = $StorableObject->Deserialize(
        Data   => $Test->{Data},
        Silent => $Test->{Silent},
    );

    $Self->Is(
        $StorableData,
        undef,
        "$Test->{Name} Deserialize() should be undef",
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
