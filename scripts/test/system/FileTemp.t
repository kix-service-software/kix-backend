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

use File::Basename;
use File::Copy;

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

my ( $Filename, $FilenameSuffix, $TempDir, $FH, $FHSuffix );

{
    my $FileTempObject = $Kernel::OM->Get('FileTemp');

    ( $FH, $Filename ) = $FileTempObject->TempFile();

    $Self->True(
        $Filename,
        'TempFile()',
    );

    $Self->True(
        ( -e $Filename ),
        'TempFile() -e',
    );

    $Self->Is(
        ( substr( $Filename, -4 ) ),
        '.tmp',
        'TempFile() suffix',
    );

    ( $FHSuffix, $FilenameSuffix ) = $FileTempObject->TempFile( Suffix => '.png' );

    $Self->True(
        $FilenameSuffix,
        'TempFile()',
    );

    $Self->True(
        ( -e $FilenameSuffix ),
        'TempFile() -e',
    );

    $Self->Is(
        ( substr( $FilenameSuffix, -4 ) ),
        '.png',
        'TempFile() custom suffix',
    );

    $TempDir = $FileTempObject->TempDir();

    $Self->True(
        ( -d $TempDir ),
        "TempDir $TempDir exists",
    );

    my $ConfiguredTempDir = $ConfigObject->Get('TempDir');
    $ConfiguredTempDir =~ s{/+}{/}smxg;

    $Self->Is(
        ( dirname $TempDir ),
        $ConfiguredTempDir,
        "$TempDir is relative to defined TempDir",
    );

    $Self->True(
        ( copy( $ConfigObject->Get('Home') . '/scripts/test/system/FileTemp.t', "$TempDir/" ) ),
        'Copy test to tempdir',
    );

    $Self->True(
        ( -e $TempDir . '/FileTemp.t' ),
        'Copied file exists in tempdir',
    );

    # destroy the file temp object
    $Kernel::OM->ObjectsDiscard( Objects => ['FileTemp'] );
}

$Self->False(
    ( -e $Filename ),
    "TempFile() $Filename -e after destroy",
);

$Self->False(
    ( -e $FilenameSuffix ),
    "TempFile() $FilenameSuffix -e after destroy",
);

$Self->False(
    ( -d $TempDir ),
    "TempDir() $TempDir removed after destroy",
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
