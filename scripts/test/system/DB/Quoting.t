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

# get DB object
my $DBObject = $Kernel::OM->Get('DB');

# ------------------------------------------------------------ #
# quoting tests
# ------------------------------------------------------------ #
$Self->Is(
    $DBObject->Quote( 0, 'Integer' ),
    0,
    'Quote() Integer - 0',
);
$Self->Is(
    $DBObject->Quote( 1, 'Integer' ),
    1,
    'Quote() Integer - 1',
);
$Self->Is(
    $DBObject->Quote( 123, 'Integer' ),
    123,
    'Quote() Integer - 123',
);
$Self->Is(
    $DBObject->Quote( 61712, 'Integer' ),
    61712,
    'Quote() Integer - 61712',
);
$Self->Is(
    $DBObject->Quote( -61712, 'Integer' ),
    -61712,
    'Quote() Integer - -61712',
);
$Self->Is(
    $DBObject->Quote( '+61712', 'Integer' ),
    '+61712',
    'Quote() Integer - +61712',
);
$Self->Is(
    $DBObject->Quote( '02', 'Integer' ),
    '02',
    'Quote() Integer - 02',
);
$Self->Is(
    $DBObject->Quote( '0000123', 'Integer' ),
    '0000123',
    'Quote() Integer - 0000123',
);

$Self->Is(
    $DBObject->Quote( 123.23, 'Number' ),
    123.23,
    'Quote() Number - 123.23',
);
$Self->Is(
    $DBObject->Quote( 0.23, 'Number' ),
    0.23,
    'Quote() Number - 0.23',
);
$Self->Is(
    $DBObject->Quote( '+123.23', 'Number' ),
    '+123.23',
    'Quote() Number - +123.23',
);
$Self->Is(
    $DBObject->Quote( '+0.23132', 'Number' ),
    '+0.23132',
    'Quote() Number - +0.23132',
);
$Self->Is(
    $DBObject->Quote( '+12323', 'Number' ),
    '+12323',
    'Quote() Number - +12323',
);
$Self->Is(
    $DBObject->Quote( -123.23, 'Number' ),
    -123.23,
    'Quote() Number - -123.23',
);
$Self->Is(
    $DBObject->Quote( -123, 'Number' ),
    -123,
    'Quote() Number - -123',
);
$Self->Is(
    $DBObject->Quote( -0.23, 'Number' ),
    -0.23,
    'Quote() Number - -0.23',
);

if (
    $DBObject->GetDatabaseFunction('Type') eq 'postgresql' ||
    $DBObject->GetDatabaseFunction('Type') eq 'oracle'     ||
    $DBObject->GetDatabaseFunction('Type') eq 'db2'        ||
    $DBObject->GetDatabaseFunction('Type') eq 'ingres'
    )
{
    $Self->Is(
        $DBObject->Quote("Test'l"),
        'Test\'\'l',
        'Quote() String - Test\'l',
    );

    $Self->Is(
        $DBObject->Quote("Test'l;"),
        'Test\'\'l;',
        "Quote() String - Test\'l;",
    );

    $Self->Is(
        $DBObject->Quote( "Block[12]Block[12]", 'Like' ),
        'Block[12]Block[12]',
        'Quote() Like-String - Block[12]Block[12]',
    );
}
elsif ( $DBObject->GetDatabaseFunction('Type') eq 'mssql' ) {
    $Self->Is(
        $DBObject->Quote("Test'l"),
        'Test\'\'l',
        'Quote() String - Test\'l',
    );

    $Self->Is(
        $DBObject->Quote("Test'l;"),
        'Test\'\'l;',
        'Quote() String - Test\'l;',
    );

    $Self->Is(
        $DBObject->Quote( "Block[12]Block[12]", 'Like' ),
        'Block[[]12]Block[[]12]',
        'Quote() Like-String - Block[12]Block[12]',
    );
}
else {
    $Self->Is(
        $DBObject->Quote("Test'l"),
        'Test\\\'l',
        'Quote() String - Test\'l',
    );

    $Self->Is(
        $DBObject->Quote("Test'l;"),
        'Test\\\'l\\;',
        'Quote() String - Test\'l;',
    );

    $Self->Is(
        $DBObject->Quote( "Block[12]Block[12]", 'Like' ),
        'Block[12]Block[12]',
        'Quote() Like-String - Block[12]Block[12]',
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
