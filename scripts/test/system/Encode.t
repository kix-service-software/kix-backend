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

use Kernel::System::VariableCheck qw(:all);

# get encode object
my $EncodeObject = $Kernel::OM->Get('Encode');

# convert tests
{
    use utf8;
    my @Tests = (
        {
            Name          => 'Convert()',
            Input         => 'abc123',
            Result        => 'abc123',
            InputCharset  => 'ascii',
            ResultCharset => 'utf8',
            UTF8          => 1,
        },
        {
            Name          => 'Convert()',
            Input         => 'abc123',
            Result        => 'abc123',
            InputCharset  => 'us-ascii',
            ResultCharset => 'utf8',
            UTF8          => 1,
        },
        {
            Name          => 'Convert()',
            Input         => 'abc123���',
            Result        => 'abc123���',
            InputCharset  => 'utf8',
            ResultCharset => 'utf8',
            UTF8          => 1,
        },
        {
            Name          => 'Convert()',
            Input         => 'abc123���',
            Result        => 'abc123���',
            InputCharset  => 'iso-8859-15',
            ResultCharset => 'utf8',
            UTF8          => 1,
        },
        {
            Name          => 'Convert()',
            Input         => 'abc123���',
            Result        => 'abc123���',
            InputCharset  => 'utf8',
            ResultCharset => 'utf-8',
            UTF8          => 1,
        },
        {
            Name          => 'Convert()',
            Input         => 'abc123���',
            Result        => 'abc123���',
            InputCharset  => 'utf8',
            ResultCharset => 'iso-8859-15',
            UTF8          => 1,
        },
        {
            Name          => 'Convert()',
            Input         => 'abc123���',
            Result        => 'abc123???',
            InputCharset  => 'utf8',
            ResultCharset => 'iso-8859-1',
            Force         => 1,
            UTF8          => '',
        },
    );
    for my $Test (@Tests) {
        my $Result = $EncodeObject->Convert(
            Text  => $Test->{Input},
            From  => $Test->{InputCharset},
            To    => $Test->{ResultCharset},
            Force => $Test->{Force},
        );
        my $IsUTF8 = Encode::is_utf8($Result);
        $Self->True(
            $IsUTF8 eq $Test->{UTF8},
            $Test->{Name} . " is_utf8",
        );
        $Self->True(
            $Result eq $Test->{Result},
            $Test->{Name},
        );
    }
}

$Self->True(
    $EncodeObject->EncodingIsAsciiSuperset( Encoding => 'UTF-8' ),
    'UTF-8 is a superset of ASCII',
);
$Self->False(
    $EncodeObject->EncodingIsAsciiSuperset( Encoding => 'UTF-16-LE' ),
    'UTF-16 is a not superset of ASCII',
);

$Self->Is(
    $EncodeObject->FindAsciiSupersetEncoding(
        Encodings => [ 'UTF-7', 'UTF-16-LE', 'ISO-8859-1' ],
    ),
    'ISO-8859-1',
    'FindAsciiSupersetEncoding',
);

$Self->Is(
    $EncodeObject->FindAsciiSupersetEncoding(
        Encodings => ['UTF-7'],
    ),
    'ASCII',
    'FindAsciiSupersetEncoding falls back to ASCII',
);

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
