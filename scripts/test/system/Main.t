# --
# Modified version of the work: Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

use File::Path;
use Unicode::Normalize;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# FilenameCleanUp - tests
my @Tests = (
    {
        Name         => 'FilenameCleanUp() - Local',
        FilenameOrig => 'me_t o/alal.xml',
        FilenameNew  => 'me_t o_alal.xml',
        Type         => 'Local',
    },
    {
        Name         => 'FilenameCleanUp() - Local',
        FilenameOrig => 'me_to/al?al"l.xml',
        FilenameNew  => 'me_to_al_al_l.xml',
        Type         => 'Local',
    },
    {
        Name         => 'FilenameCleanUp() - Local',
        FilenameOrig => 'me_to/a\/\\lal.xml',
        FilenameNew  => 'me_to_a___lal.xml',
        Type         => 'Local',
    },
    {
        Name         => 'FilenameCleanUp() - Local',
        FilenameOrig => 'me_to/al[al].xml',
        FilenameNew  => 'me_to_al_al_.xml',
        Type         => 'Local',
    },
    {
        Name         => 'FilenameCleanUp() - Local',
        FilenameOrig => 'me_to/alal.xml',
        FilenameNew  => 'me_to_alal.xml',
        Type         => 'Local',
    },
    {
        Name         => 'FilenameCleanUp() - Attachment',
        FilenameOrig => 'me_to/a+la l.xml',
        FilenameNew  => 'me_to_a+la_l.xml',
        Type         => 'Attachment',
    },
    {
        Name         => 'FilenameCleanUp() - Local',
        FilenameOrig => 'me_to/a+lal Grüße 0.xml',
        FilenameNew  => 'me_to_a+lal Grüße 0.xml',
        Type         => 'Local',
    },
    {
        Name => 'FilenameCleanUp() - Attachment',
        FilenameOrig =>
            'me_to/a+lal123456789012345678901234567890Liebe Grüße aus Straubing123456789012345678901234567890123456789012345678901234567890.xml',
        FilenameNew =>
            'me_to_a+lal123456789012345678901234567890Liebe_Gruesse_aus_Straubing123456789012345678901234567.xml',
        Type => 'Attachment',
    },
    {
        Name         => 'FilenameCleanUp() - md5',
        FilenameOrig => 'some file.xml',
        FilenameNew  => '6b9e62f9a8c56a0c06c66cc716e30c45',
        Type         => 'md5',
    },
    {
        Name         => 'FilenameCleanUp() - md5',
        FilenameOrig => 'me_to/a+lal Grüße 0öäüßカスタマ.xml',
        FilenameNew  => 'c235a9eabe8494b5f90ffd1330af3407',
        Type         => 'md5',
    },
);

for my $Test (@Tests) {
    my $Filename = $Kernel::OM->Get('Main')->FilenameCleanUp(
        Filename => $Test->{FilenameOrig},
        Type     => $Test->{Type},
    );
    $Self->Is(
        $Filename || '',
        $Test->{FilenameNew},
        $Test->{Name},
    );
}

# md5sum tests
my $String = 'abc1234567890';
my $MD5Sum = $Kernel::OM->Get('Main')->MD5sum( String => \$String );
$Self->Is(
    $MD5Sum || '',
    '57041f8f7dff9b67e3f97d7facbaf8d3',
    "MD5sum() - String - abc1234567890",
);

# test charset specific situations
$String = 'abc1234567890äöüß-カスタマ';
$MD5Sum = $Kernel::OM->Get('Main')->MD5sum( String => \$String );

$Self->Is(
    $MD5Sum || '',
    '56a681e0c46b1f156020182cdf62e825',
    "MD5sum() - String - $String",
);

my %MD5SumOf = (
    doc => '2e520036a0cda6a806a8838b1000d9d7',
    pdf => '5ee767f3b68f24a9213e0bef82dc53e5',
    png => 'e908214e672ed20c9c3f417b82e4e637',
    txt => '0596f2939525c6bd50fc2b649e40fbb6',
    xls => '39fae660239f62bb0e4a29fe14ff5663',
);

my $Home = $Kernel::OM->Get('Config')->Get('Home');

for my $Extension (qw(doc pdf png txt xls)) {
    my $MD5Sum = $Kernel::OM->Get('Main')->MD5sum(
        Filename => $Home . "/scripts/test/system/sample/Main/Main-Test1.$Extension",
    );
    $Self->Is(
        $MD5Sum || '',
        $MD5SumOf{$Extension},
        "MD5sum() - Filename - Main-Test1.$Extension",
    );
}

my $Path = $Kernel::OM->Get('Config')->Get('TempDir');

# write & read some files via Directory/Filename
for my $Extension (qw(doc pdf png txt xls)) {
    my $MD5Sum = $Kernel::OM->Get('Main')->MD5sum(
        Filename => $Home . "/scripts/test/system/sample/Main/Main-Test1.$Extension",
    );
    my $Content = $Kernel::OM->Get('Main')->FileRead(
        Directory => $Home . '/scripts/test/system/sample/Main/',
        Filename  => "Main-Test1.$Extension",
    );
    $Self->True(
        ${$Content} || '',
        "FileRead() - Main-Test1.$Extension",
    );
    my $FileLocation = $Kernel::OM->Get('Main')->FileWrite(
        Directory => $Path,
        Filename  => "me_öüto/al<>?Main-Test1.$Extension",
        Content   => $Content,
    );
    $Self->True(
        $FileLocation || '',
        "FileWrite() - $FileLocation",
    );
    my $MD5Sum2 = $Kernel::OM->Get('Main')->MD5sum(
        Filename => $Path . '/' . $FileLocation,
    );
    $Self->Is(
        $MD5Sum2 || '',
        $MD5Sum  || '',
        "MD5sum()>FileWrite()>MD5sum() - $FileLocation",
    );
    my $Success = $Kernel::OM->Get('Main')->FileDelete(
        Directory => $Path,
        Filename  => $FileLocation,
    );
    $Self->True(
        $Success || '',
        "FileDelete() - $FileLocation",
    );
}

# write & read some files via Location
for my $Extension (qw(doc pdf png txt xls)) {
    my $MD5Sum = $Kernel::OM->Get('Main')->MD5sum(
        Filename => $Home . "/scripts/test/system/sample/Main/Main-Test1.$Extension",
    );
    my $Content = $Kernel::OM->Get('Main')->FileRead(
        Location => $Home . '/scripts/test/system/sample/Main/' . "Main-Test1.$Extension",
    );
    $Self->True(
        ${$Content} || '',
        "FileRead() - Main-Test1.$Extension",
    );
    my $FileLocation = $Kernel::OM->Get('Main')->FileWrite(
        Location => $Path . "Main-Test1.$Extension",
        Content  => $Content,
    );
    $Self->True(
        $FileLocation || '',
        "FileWrite() - $FileLocation",
    );
    my $MD5Sum2 = $Kernel::OM->Get('Main')->MD5sum( Filename => $FileLocation );
    $Self->Is(
        $MD5Sum2 || '',
        $MD5Sum  || '',
        "MD5sum()>FileWrite()>MD5sum() - $FileLocation",
    );
    my $Success = $Kernel::OM->Get('Main')->FileDelete( Location => $FileLocation );
    $Self->True(
        $Success || '',
        "FileDelete() - $FileLocation",
    );
}

# write / read ARRAYREF test
my $Content      = "some\ntest\nöäüßカスタマ";
my $FileLocation = $Kernel::OM->Get('Main')->FileWrite(
    Directory => $Path,
    Filename  => "some-test.txt",
    Mode      => 'utf8',
    Content   => \$Content,
);
$Self->True(
    $FileLocation || '',
    "FileWrite() - $FileLocation",
);

my $ContentARRAYRef = $Kernel::OM->Get('Main')->FileRead(
    Directory => $Path,
    Filename  => $FileLocation,
    Mode      => 'utf8',
    Result    => 'ARRAY',         # optional - SCALAR|ARRAY
);
$Self->True(
    $ContentARRAYRef || '',
    "FileRead() - $FileLocation $ContentARRAYRef",
);
$Self->Is(
    $ContentARRAYRef->[0] || '',
    "some\n",
    "FileRead() [0] - $FileLocation",
);
$Self->Is(
    $ContentARRAYRef->[1] || '',
    "test\n",
    "FileRead() [1] - $FileLocation",
);
$Self->Is(
    $ContentARRAYRef->[2] || '',
    "öäüßカスタマ",
    "FileRead() [2] - $FileLocation",
);

my $Success = $Kernel::OM->Get('Main')->FileDelete(
    Directory => $Path,
    Filename  => $FileLocation,
);
$Self->True(
    $Success || '',
    "FileDelete() - $FileLocation",
);

# check if the file have the correct charset
my $ContentSCALARRef = $Kernel::OM->Get('Main')->FileRead(
    Location => $Home . '/scripts/test/system/sample/Main/PDF-test2-utf-8.txt',
    Mode     => 'utf8',
    Result   => 'SCALAR',
);

my $Text = ${$ContentSCALARRef};

$Self->True(
    Encode::is_utf8($Text),
    "FileRead() - Check a utf8 file - exists the utf8 flag ( $Text )",
);

$Self->True(
    Encode::is_utf8( $Text, 1 ),
    "FileRead() - Check a utf8 file - is the utf8 content wellformed ( $Text )",
);

my $FileMTime = $Kernel::OM->Get('Main')->FileGetMTime(
    Location => $Home . '/Kernel/Config.pm',
);

$Self->True(
    int $FileMTime > 1_000_000,
    'FileGetMTime()',
);

my $FileMTimeNonexisting = $Kernel::OM->Get('Main')->FileGetMTime(
    Location        => $Home . '/Kernel/some.nonexisting.file',
    DisableWarnings => 1,
);

$Self->False(
    defined $FileMTimeNonexisting,
    'FileGetMTime() for nonexisting file',
);

# testing DirectoryRead function
my $DirectoryWithFiles    = "$Path/WithFiles";
my $DirectoryWithoutFiles = "$Path/WithoutFiles";
my $SubDirA               = "$DirectoryWithFiles/a";
my $SubDirB               = "$DirectoryWithFiles/b";

# create needed test directories
for my $Directory ( $DirectoryWithFiles, $DirectoryWithoutFiles, $SubDirA, $SubDirB, ) {
    if ( !mkdir $Directory ) {
        $Self->True(
            0,
            "DirectoryRead() - create '$Directory': $!",
        );
    }
}

# create test files
for my $Directory ( $DirectoryWithFiles, $SubDirA, $SubDirB, ) {

    for my $Suffix (
        0 .. 5,
        'öäüßカスタマ',         # Unicode NFC
        'Второй_файл',    # Unicode NFD
        )
    {
        my $Success = $Kernel::OM->Get('Main')->FileWrite(
            Directory => $Directory,
            Filename  => "Example_File_$Suffix",
            Content   => \'',
        );
        $Self->True(
            $Success,
            "DirectoryRead() - create '$Directory/Example_File_$Suffix'!",
        );
    }
}

@Tests = (
    {
        Name      => 'Read directory with files, \'Example_File*\' Filter',
        Filter    => 'Example_File*',
        Directory => $DirectoryWithFiles,
        Results   => [
            "$DirectoryWithFiles/Example_File_0",
            "$DirectoryWithFiles/Example_File_1",
            "$DirectoryWithFiles/Example_File_2",
            "$DirectoryWithFiles/Example_File_3",
            "$DirectoryWithFiles/Example_File_4",
            "$DirectoryWithFiles/Example_File_5",
            "$DirectoryWithFiles/Example_File_öäüßカスタマ",
            "$DirectoryWithFiles/Example_File_Второй_файл",
        ],
    },
    {
        Name      => 'Read directory with files, \'Example_File*\' Filter, recursive',
        Filter    => 'Example_File*',
        Directory => $DirectoryWithFiles,
        Recursive => 1,
        Results   => [
            "$DirectoryWithFiles/Example_File_0",
            "$DirectoryWithFiles/Example_File_1",
            "$DirectoryWithFiles/Example_File_2",
            "$DirectoryWithFiles/Example_File_3",
            "$DirectoryWithFiles/Example_File_4",
            "$DirectoryWithFiles/Example_File_5",
            "$DirectoryWithFiles/Example_File_öäüßカスタマ",
            "$DirectoryWithFiles/Example_File_Второй_файл",
            "$SubDirA/Example_File_0",
            "$SubDirA/Example_File_1",
            "$SubDirA/Example_File_2",
            "$SubDirA/Example_File_3",
            "$SubDirA/Example_File_4",
            "$SubDirA/Example_File_5",
            "$SubDirA/Example_File_öäüßカスタマ",
            "$SubDirA/Example_File_Второй_файл",
            "$SubDirB/Example_File_0",
            "$SubDirB/Example_File_1",
            "$SubDirB/Example_File_2",
            "$SubDirB/Example_File_3",
            "$SubDirB/Example_File_4",
            "$SubDirB/Example_File_5",
            "$SubDirB/Example_File_öäüßカスタマ",
            "$SubDirB/Example_File_Второй_файл",

        ],
    },
    {
        Name      => 'Read directory with files, \'XX_NOTEXIST_XX\' Filter',
        Filter    => 'XX_NOTEXIST_XX',
        Directory => $DirectoryWithFiles,
        Results   => [],
    },
    {
        Name      => 'Read directory with files, \'XX_NOTEXIST_XX\' Filter, recursive',
        Filter    => 'XX_NOTEXIST_XX',
        Directory => $DirectoryWithFiles,
        Recursive => 1,
        Results   => [],
    },
    {
        Name      => 'Read directory with files, *0 *1 *2 Filters',
        Filter    => [ '*0', '*1', '*2' ],
        Directory => $DirectoryWithFiles,
        Results   => [
            "$DirectoryWithFiles/Example_File_0",
            "$DirectoryWithFiles/Example_File_1",
            "$DirectoryWithFiles/Example_File_2",
        ],
    },
    {
        Name      => 'Read directory with files, *0 *1 *2 Filters, recursive',
        Filter    => [ '*0', '*1', '*2' ],
        Directory => $DirectoryWithFiles,
        Recursive => 1,
        Results   => [
            "$DirectoryWithFiles/Example_File_0",
            "$DirectoryWithFiles/Example_File_1",
            "$DirectoryWithFiles/Example_File_2",
            "$SubDirA/Example_File_0",
            "$SubDirA/Example_File_1",
            "$SubDirA/Example_File_2",
            "$SubDirB/Example_File_0",
            "$SubDirB/Example_File_1",
            "$SubDirB/Example_File_2",
        ],
    },
    {
        Name      => 'Read directory with files, *0 *1 *2 Filters',
        Filter    => [ '*0', '*2', '*1', '*1', '*0', '*2' ],
        Directory => $DirectoryWithFiles,
        Results   => [
            "$DirectoryWithFiles/Example_File_0",
            "$DirectoryWithFiles/Example_File_2",
            "$DirectoryWithFiles/Example_File_1",
        ],
    },
    {
        Name      => 'Read directory with files, no Filter',
        Filter    => '*',
        Directory => $DirectoryWithFiles,
        Results   => [
            "$DirectoryWithFiles/Example_File_0",
            "$DirectoryWithFiles/Example_File_1",
            "$DirectoryWithFiles/Example_File_2",
            "$DirectoryWithFiles/Example_File_3",
            "$DirectoryWithFiles/Example_File_4",
            "$DirectoryWithFiles/Example_File_5",
            "$DirectoryWithFiles/Example_File_öäüßカスタマ",
            "$DirectoryWithFiles/Example_File_Второй_файл",
            "$DirectoryWithFiles/a",
            "$DirectoryWithFiles/b",
        ],
    },
    {
        Name      => 'Read directory with files, no Filter (multiple)',
        Filter    => [ '*', '*', '*' ],
        Directory => $DirectoryWithFiles,
        Results   => [
            "$DirectoryWithFiles/Example_File_0",
            "$DirectoryWithFiles/Example_File_1",
            "$DirectoryWithFiles/Example_File_2",
            "$DirectoryWithFiles/Example_File_3",
            "$DirectoryWithFiles/Example_File_4",
            "$DirectoryWithFiles/Example_File_5",
            "$DirectoryWithFiles/Example_File_öäüßカスタマ",
            "$DirectoryWithFiles/Example_File_Второй_файл",
            "$DirectoryWithFiles/a",
            "$DirectoryWithFiles/b",
        ],
    },
    {
        Name      => 'Read directory with files, no Filter (multiple), recursive',
        Filter    => [ '*', '*', '*' ],
        Directory => $DirectoryWithFiles,
        Recursive => 1,
        Results   => [
            "$DirectoryWithFiles/Example_File_0",
            "$DirectoryWithFiles/Example_File_1",
            "$DirectoryWithFiles/Example_File_2",
            "$DirectoryWithFiles/Example_File_3",
            "$DirectoryWithFiles/Example_File_4",
            "$DirectoryWithFiles/Example_File_5",
            "$DirectoryWithFiles/Example_File_öäüßカスタマ",
            "$DirectoryWithFiles/Example_File_Второй_файл",
            "$DirectoryWithFiles/a",
            "$DirectoryWithFiles/b",
            "$SubDirA/Example_File_0",
            "$SubDirA/Example_File_1",
            "$SubDirA/Example_File_2",
            "$SubDirA/Example_File_3",
            "$SubDirA/Example_File_4",
            "$SubDirA/Example_File_5",
            "$SubDirA/Example_File_öäüßカスタマ",
            "$SubDirA/Example_File_Второй_файл",
            "$SubDirB/Example_File_0",
            "$SubDirB/Example_File_1",
            "$SubDirB/Example_File_2",
            "$SubDirB/Example_File_3",
            "$SubDirB/Example_File_4",
            "$SubDirB/Example_File_5",
            "$SubDirB/Example_File_öäüßカスタマ",
            "$SubDirB/Example_File_Второй_файл",
        ],
    },
    {
        Name      => 'Read directory without files, * Filter',
        Filter    => '*',
        Directory => $DirectoryWithoutFiles,
        Results   => [],
    },
    {
        Name      => 'Read directory without files, no Filter',
        Filter    => '*',
        Directory => $DirectoryWithoutFiles,
        Results   => [],
    },
    {
        Name      => 'Directory doesn\'t exists!',
        Directory => 'THIS',
        Filter    => '*',
        Results   => [],
        Silent    => 1,
    },
);

for my $Test (@Tests) {

    my @UnicodeResults;
    for my $Result ( @{ $Test->{Results} } ) {
        push @UnicodeResults, $Kernel::OM->Get('Encode')->Convert2CharsetInternal(
            Text => $Result,
            From => 'utf-8',
        );
    }
    @UnicodeResults = sort @UnicodeResults;

    my @Results = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => $Test->{Directory},
        Filter    => $Test->{Filter},
        Recursive => $Test->{Recursive},
        Silent    => $Test->{Silent},
    );

    # Mac OS will store all filenames as NFD internally.
    if ( $^O eq 'darwin' ) {
        for my $Index ( 0 .. $#UnicodeResults ) {
            $UnicodeResults[$Index] = Unicode::Normalize::NFD( $UnicodeResults[$Index] );
        }
    }

    $Self->IsDeeply( \@Results, \@UnicodeResults, $Test->{Name} );
}

# delete needed test directories
for my $Directory ( $DirectoryWithFiles, $DirectoryWithoutFiles ) {
    if ( !File::Path::rmtree( [$Directory] ) ) {
        $Self->True(
            0,
            "DirectoryRead() - delete '$Directory'",
        );
    }
}

#
# Dump()
#
@Tests = (
    {
        Name             => 'Unicode dump 1',
        Source           => 'é',
        ResultDumpBinary => "\$VAR1 = 'é';\n",
        ResultDumpAscii  => '$VAR1 = "\x{e9}";' . "\n",
    },
    {
        Name             => 'Unicode dump 2',
        Source           => 'äöüßÄÖÜ€ис é í  ó',
        ResultDumpBinary => "\$VAR1 = 'äöüßÄÖÜ€ис é í  ó';\n",
        ResultDumpAscii =>
            '$VAR1 = "\x{e4}\x{f6}\x{fc}\x{df}\x{c4}\x{d6}\x{dc}\x{20ac}\x{438}\x{441} \x{e9} \x{ed}  \x{f3}";' . "\n",
    },
    {
        Name => 'Unicode dump 3',
        Source =>
            "\x{e4}\x{f6}\x{fc}\x{df}\x{c4}\x{d6}\x{dc}\x{20ac}\x{438}\x{441} \x{e9} \x{ed}  \x{f3}",
        ResultDumpBinary => "\$VAR1 = 'äöüßÄÖÜ€ис é í  ó';\n",
        ResultDumpAscii =>
            '$VAR1 = "\x{e4}\x{f6}\x{fc}\x{df}\x{c4}\x{d6}\x{dc}\x{20ac}\x{438}\x{441} \x{e9} \x{ed}  \x{f3}";' . "\n",
    },
    {
        Name             => 'Unicode dump 4',
        Source           => "Mus\x{e9}e royal de l\x{2019}Arm\x{e9}e et d\x{2019}histoire militaire",
        ResultDumpBinary => "\$VAR1 = 'Musée royal de l’Armée et d’histoire militaire';\n",
        ResultDumpAscii  => '$VAR1 = "Mus\x{e9}e royal de l\x{2019}Arm\x{e9}e et d\x{2019}histoire militaire";' . "\n",
    },
    {
        Name             => 'Unicode dump 5',
        Source           => "Antonín Dvořák",
        ResultDumpBinary => "\$VAR1 = 'Antonín Dvořák';\n",
        ResultDumpAscii  => '$VAR1 = "Anton\x{ed}n Dvo\x{159}\x{e1}k";' . "\n",
    },
);

for my $Test (@Tests) {
    $Self->Is(
        $Kernel::OM->Get('Main')->Dump( $Test->{Source} ),
        $Test->{ResultDumpBinary},
        "$Test->{Name} - Dump() result (binary)"
    );
    $Self->Is(
        $Kernel::OM->Get('Main')->Dump( $Test->{Source}, 'ascii' ),
        $Test->{ResultDumpAscii},
        "$Test->{Name} - Dump() result (ascii)"
    );
}

# Generate Random string test

my $Token  = $Kernel::OM->Get('Main')->GenerateRandomString();
my $Length = length($Token);

$Self->True(
    $Token,
    "GenerateRandomString - generated",
);

$Self->Is(
    $Length,
    16,
    "GenerateRandomString - standard size is 16",
);

$Token = $Kernel::OM->Get('Main')->GenerateRandomString(
    Length => 8,
);
$Length = length($Token);

$Self->True(
    $Token,
    "GenerateRandomString - 8 - generated",
);

$Self->Is(
    $Length,
    8,
    "GenerateRandomString - 8 - correct length",
);

my %Values;
my $Seen = 0;
COUNTER:
for my $Counter ( 1 .. 100_000 ) {
    my $Random = $Kernel::OM->Get('Main')->GenerateRandomString( Length => 16 );
    if ( $Values{$Random}++ ) {
        $Seen = 1;
        last COUNTER;
    }
}

$Self->Is(
    $Seen,
    0,
    "GenerateRandomString - no duplicates in 100k iterations",
);

# test with custom alphabet
my $NoHexChar;
COUNTER:
for my $Counter ( 1 .. 1000 ) {
    my $HexString = $Kernel::OM->Get('Main')->GenerateRandomString(
        Length     => 32,
        Dictionary => [ 0 .. 9, 'a' .. 'f' ],
    );
    if ( $HexString =~ m{[^0-9a-f]}xms ) {
        $NoHexChar = $HexString;
        last COUNTER;
    }
}

$Self->Is(
    $NoHexChar,
    undef,
    'Test output for hex chars in 1000 generated random strings with hex dictionary',
);

my $Data = [
    {
        "ChangeBy" => 1,
        "ChangeTime" => "2025-06-16 14:31:26",
        "Comment" => undef,
        "CreateBy" => 1,
        "CreateTime" => "2025-06-16 14:31:26",
        "ID" => 1,
        "Name" => "5 very low",
        "ObjectIcon" => 25,
        "ValidID" => 1
    },
    {
        "ChangeBy" => 1,
        "ChangeTime" => "2025-06-16 14:31:26",
        "Comment" => undef,
        "CreateBy" => 1,
        "CreateTime" => "2025-06-16 14:31:26",
        "ID" => 2,
        "Name" => "4 low",
        "ObjectIcon" => 24,
        "ValidID" => 1
    },
    {
        "ChangeBy" => 1,
        "ChangeTime" => "2025-06-16 14:31:26",
        "Comment" => 'äöüß',
        "CreateBy" => 1,
        "CreateTime" => "2025-06-16 14:31:26",
        "ID" => 3,
        "Name" => "3 normal",
        "ObjectIcon" => 23,
        "ValidID" => 1
    },
    {
        "ChangeBy" => 1,
        "ChangeTime" => "2025-06-16 14:31:26",
        "Comment" => undef,
        "CreateBy" => 1,
        "CreateTime" => "2025-06-16 14:31:26",
        "ID" => 4,
        "Name" => "2 high",
        "ObjectIcon" => 22,
        "ValidID" => 1
    },
    {
        "ChangeBy" => 1,
        "ChangeTime" => "2025-06-16 14:31:26",
        "Comment" => undef,
        "CreateBy" => 1,
        "CreateTime" => "2025-06-16 14:31:26",
        "ID" => 5,
        "Name" => "1 very high",
        "ObjectIcon" => 21,
        "ValidID" => 1
    }
];

# test object listing filtering
@Tests = (
    {
        Name     => 'no data',
        Strict   => 0,
        Data     => undef,
        Filter   => {
        },
        Expected => []
    },
    {
        Name     => 'data is not an array ref',
        Strict   => 0,
        Data     => {},
        Filter   => {
        },
        Expected => []
    },
    {
        Name     => 'no filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => undef,
        Expected => $Data
    },
    {
        Name     => 'simple AND filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'EQ',
                    Value => '2 high'
                }
            ]
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'simple OR filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            OR => [
                {
                    Field => 'Name',
                    Operator => 'EQ',
                    Value => '2 high'
                }
            ]
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'extended AND filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'EQ',
                    Value => '2 high'
                },
                {
                    Field => 'ID',
                    Operator => 'EQ',
                    Value => 4,
                    Type => 'NUMERIC'
                }
            ]
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'extended AND filter (no match)',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'EQ',
                    Value => '2 high'
                },
                {
                    Field => 'ID',
                    Operator => 'EQ',
                    Value => 5,
                    Type => 'NUMERIC'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'extended OR filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            OR => [
                {
                    Field => 'Name',
                    Operator => 'EQ',
                    Value => '2 high'
                },
                {
                    Field => 'ID',
                    Operator => 'EQ',
                    Value => 3,
                    Type => 'NUMERIC'
                }
            ]
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'extended OR filter (no match)',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            OR => [
                {
                    Field => 'Name',
                    Operator => 'EQ',
                    Value => '2 higher'
                },
                {
                    Field => 'ID',
                    Operator => 'EQ',
                    Value => 99,
                    Type => 'NUMERIC'
                }
            ]
        },
        Expected => []
    },
    {
        Name     => 'combined AND/OR filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'ObjectIcon',
                    Operator => 'IN',
                    Value => [23,24]
                }
            ],
            OR => [
                {
                    Field => 'Name',
                    Operator => 'EQ',
                    Value => '2 high'
                },
                {
                    Field => 'ID',
                    Operator => 'EQ',
                    Value => 3,
                    Type => 'NUMERIC'
                }
            ]
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'EQ filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'EQ',
                    Value => '2 high',
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'NE filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'NE',
                    Value => '2 high',
                },
                {
                    Field => 'Name',
                    Operator => 'NE',
                    Value => '3 normal',
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            }
        ]
    },
    {
        Name     => 'LT filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'ObjectIcon',
                    Operator => 'LT',
                    Value => 22,
                    Type => 'NUMERIC'
                },
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            }
        ]
    },
    {
        Name     => 'LTE filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'ObjectIcon',
                    Operator => 'LTE',
                    Value => 22,
                    Type => 'NUMERIC'
                },
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'GT filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'ObjectIcon',
                    Operator => 'GT',
                    Value => 22,
                    Type => 'NUMERIC'
                },
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'GTE filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'ObjectIcon',
                    Operator => 'GTE',
                    Value => 22,
                    Type => 'NUMERIC'
                },
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
                {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'IN filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'IN',
                    Value => ['2 high', '4 low']
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'STARTSWITH filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'STARTSWITH',
                    Value => '2 ',
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'ENDSWITH filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'ENDSWITH',
                    Value => 'high',
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            }
        ]
    },
    {
        Name     => 'CONTAINS filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'CONTAINS',
                    Value => 'er',
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            }
        ]
    },
    {
        Name     => 'LIKE filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'LIKE',
                    Value => '*ow*',
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
        ]
    },
    ### NOT FILTER TESTS ###
    {
        Name     => 'NOT EQ filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'EQ',
                    Value => '2 high',
                    Not => 1
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            }
        ]
    },
    {
        Name     => 'NOT NE filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'NE',
                    Value => '2 high',
                    Not => 1,
                },
                {
                    Field => 'Name',
                    Operator => 'NE',
                    Value => '3 normal',
                    Not => 1,
                }
            ],
        },
        Expected => []
    },
    {
        Name     => 'NOT LT filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'ObjectIcon',
                    Operator => 'LT',
                    Value => 22,
                    Not => 1,
                    Type => 'NUMERIC'
                },
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'NOT LTE filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'ObjectIcon',
                    Operator => 'LTE',
                    Value => 22,
                    Not => 1,
                    Type => 'NUMERIC'
                },
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'NOT GT filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'ObjectIcon',
                    Operator => 'GT',
                    Value => 22,
                    Not => 1,
                    Type => 'NUMERIC'
                },
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            }
        ]
    },
    {
        Name     => 'NOT GTE filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'ObjectIcon',
                    Operator => 'GTE',
                    Value => 22,
                    Not => 1,
                    Type => 'NUMERIC'
                },
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            }
        ]
    },
    {
        Name     => 'NOT IN filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'IN',
                    Value => ['2 high', '4 low'],
                    Not => 1,
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            }
        ]
    },
    {
        Name     => 'NOT STARTSWITH filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'STARTSWITH',
                    Value => '2 ',
                    Not => 1,
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            }
        ]
    },
    {
        Name     => 'NOT ENDSWITH filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'ENDSWITH',
                    Value => 'high',
                    Not => 1,
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 1,
                "Name" => "5 very low",
                "ObjectIcon" => 25,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'NOT CONTAINS filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'CONTAINS',
                    Value => 'er',
                    Not => 1,
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 2,
                "Name" => "4 low",
                "ObjectIcon" => 24,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
        ]
    },
    {
        Name     => 'NOT LIKE filter',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Name',
                    Operator => 'LIKE',
                    Value => '*ow*',
                    Not => 1
                }
            ],
        },
        Expected => [
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => 'äöüß',
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 3,
                "Name" => "3 normal",
                "ObjectIcon" => 23,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 4,
                "Name" => "2 high",
                "ObjectIcon" => 22,
                "ValidID" => 1
            },
            {
                "ChangeBy" => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment" => undef,
                "CreateBy" => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID" => 5,
                "Name" => "1 very high",
                "ObjectIcon" => 21,
                "ValidID" => 1
            }
        ]
    },
    {
        Name     => 'filter with non-existing property (without strict mode)',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Test',
                    Operator => 'LIKE',
                    Value => '*ow*',
                }
            ],
        },
        Expected => []
    },
    {
        Name     => 'filter with non-existing property (with strict mode)',
        Strict   => 1,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field => 'Test',
                    Operator => 'LIKE',
                    Value => '*ow*',
                    Not => 1
                }
            ],
        },
        Expected => undef
    },
    ### UMLAUT TEST (KIX2018-7119) ###
    {
        Name     => 'STARTSWITH filter - Umlaut value',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field    => 'Comment',
                    Operator => 'STARTSWITH',
                    Value    => 'ä',
                }
            ],
        },
        Expected => [
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => 'äöüß',
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 3,
                "Name"       => "3 normal",
                "ObjectIcon" => 23,
                "ValidID"    => 1
            }
        ]
    },
    {
        Name     => 'ENDSWITH filter - Umlaut value',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field    => 'Comment',
                    Operator => 'ENDSWITH',
                    Value    => 'ß',
                }
            ],
        },
        Expected => [
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => 'äöüß',
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 3,
                "Name"       => "3 normal",
                "ObjectIcon" => 23,
                "ValidID"    => 1
            }
        ]
    },
    {
        Name     => 'CONTAINS filter - Umlaut value',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field    => 'Comment',
                    Operator => 'CONTAINS',
                    Value    => 'ö',
                }
            ],
        },
        Expected => [
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => 'äöüß',
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 3,
                "Name"       => "3 normal",
                "ObjectIcon" => 23,
                "ValidID"    => 1
            }
        ]
    },
    {
        Name     => 'LIKE filter - Umlaut value',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field    => 'Comment',
                    Operator => 'LIKE',
                    Value    => '*ü*',
                }
            ],
        },
        Expected => [
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => 'äöüß',
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 3,
                "Name"       => "3 normal",
                "ObjectIcon" => 23,
                "ValidID"    => 1
            }
        ]
    },
    {
        Name     => 'NOT STARTSWITH filter - Umlaut value',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field    => 'Comment',
                    Operator => 'STARTSWITH',
                    Value    => 'ä',
                    Not      => 1
                }
            ],
        },
        Expected => [
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 1,
                "Name"       => "5 very low",
                "ObjectIcon" => 25,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 2,
                "Name"       => "4 low",
                "ObjectIcon" => 24,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 4,
                "Name"       => "2 high",
                "ObjectIcon" => 22,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 5,
                "Name"       => "1 very high",
                "ObjectIcon" => 21,
                "ValidID"    => 1
            }
        ]
    },
    {
        Name     => 'NOT ENDSWITH filter - Umlaut value',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field    => 'Comment',
                    Operator => 'ENDSWITH',
                    Value    => 'ß',
                    Not      => 1
                }
            ],
        },
        Expected => [
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 1,
                "Name"       => "5 very low",
                "ObjectIcon" => 25,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 2,
                "Name"       => "4 low",
                "ObjectIcon" => 24,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 4,
                "Name"       => "2 high",
                "ObjectIcon" => 22,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 5,
                "Name"       => "1 very high",
                "ObjectIcon" => 21,
                "ValidID"    => 1
            }
        ]
    },
    {
        Name     => 'NOT CONTAINS filter - Umlaut value',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field    => 'Comment',
                    Operator => 'CONTAINS',
                    Value    => 'ö',
                    Not      => 1
                }
            ],
        },
        Expected => [
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 1,
                "Name"       => "5 very low",
                "ObjectIcon" => 25,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 2,
                "Name"       => "4 low",
                "ObjectIcon" => 24,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 4,
                "Name"       => "2 high",
                "ObjectIcon" => 22,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 5,
                "Name"       => "1 very high",
                "ObjectIcon" => 21,
                "ValidID"    => 1
            }
        ]
    },
    {
        Name     => 'NOT LIKE filter - Umlaut value',
        Strict   => 0,
        Data     => $Data,
        Filter   => {
            AND => [
                {
                    Field    => 'Comment',
                    Operator => 'LIKE',
                    Value    => '*ü*',
                    Not      => 1
                }
            ],
        },
        Expected => [
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 1,
                "Name"       => "5 very low",
                "ObjectIcon" => 25,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 2,
                "Name"       => "4 low",
                "ObjectIcon" => 24,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 4,
                "Name"       => "2 high",
                "ObjectIcon" => 22,
                "ValidID"    => 1
            },
            {
                "ChangeBy"   => 1,
                "ChangeTime" => "2025-06-16 14:31:26",
                "Comment"    => undef,
                "CreateBy"   => 1,
                "CreateTime" => "2025-06-16 14:31:26",
                "ID"         => 5,
                "Name"       => "1 very high",
                "ObjectIcon" => 21,
                "ValidID"    => 1
            }
        ]
    },
);

my $TestCount = 0;
foreach my $Test ( @Tests ) {
    $TestCount++;

    my $FilteredData = $Kernel::OM->Get('Main')->FilterObjectList(
        %{$Test},
    );

    $Self->IsDeeply(
        $FilteredData,
        $Test->{Expected},
        'FilterObjectList() Test "'.$Test->{Name}.'"',
    );
}

# check variable replacement
my $TextContent = $Kernel::OM->Get('Main')->FileRead(
    Location => $Kernel::OM->Get('Config')->Get('Home') . '/scripts/test/system/sample/Main/Variable-Test.txt',
    Mode     => 'binmode'
);
$Self->True(
    $TextContent,
    'load test.txt',
);
my $TestPNGBase64 = ${$TextContent};
my $PNGContent = $Kernel::OM->Get('Main')->FileRead(
    Location => $Kernel::OM->Get('Config')->Get('Home') . '/scripts/test/system/sample/Main/Variable-Test.png',
    Mode     => 'binmode'
);
$Self->True(
    $PNGContent,
    'load test.png',
);
my $TestPNGBin = ${$PNGContent};
my $TestPNGBinJSON = $Kernel::OM->Get('JSON')->Encode(
    Data => $TestPNGBin
);

# test variable filters
@Tests = (
    {
        Name => 'simple',
        Variables => {
            Test1 => 'test1_value',
        },
        Data => {
            Dummy => '${Test1}',
        },
        Expected => {
            Dummy => 'test1_value',
        }
    },
    {
        Name => 'simple with whitespace before name',
        Variables => {
            Test1 => 'test1_value',
        },
        Data => {
            Dummy => '${ Test1}',
        },
        Expected => {
            Dummy => 'test1_value',
        }
    },
    {
        Name => 'simple with whitespace after name',
        Variables => {
            Test1 => 'test1_value',
        },
        Data => {
            Dummy => '${Test1 }',
        },
        Expected => {
            Dummy => 'test1_value',
        }
    },
    {
        Name => 'simple with complex name',
        Variables => {
            'test_123-count' => '123',
        },
        Data => {
            Dummy => '${test_123-count}',
        },
        Expected => {
            Dummy => '123',
        }
    },
    {
        Name => 'simple as part of a string',
        Variables => {
            Test1 => 'test1_value',
        },
        Data => {
            Dummy => '${Test1}/dummy',
        },
        Expected => {
            Dummy => 'test1_value/dummy',
        }
    },
    {
        Name => 'array',
        Variables => {
            Test1 => [
                1,2,3
            ]
        },
        Data => {
            Dummy => '${Test1:1}',
        },
        Expected => {
            Dummy => '2',
        }
    },
    {
        Name => 'hash',
        Variables => {
            Test1 => {
                Test2 => 'test2'
            }
        },
        Data => {
            Dummy => '${Test1.Test2}',
        },
        Expected => {
            Dummy => 'test2',
        }
    },
    {
        Name => 'array of hashes with arrays of hashes',
        Variables => {
            Test1 => [
                {},
                {
                    Test2 => [
                        {
                            Test3 => 'test3'
                        }
                    ]
                }
            ]
        },
        Data => {
            Dummy => '${Test1:1.Test2:0.Test3}',
        },
        Expected => {
            Dummy => 'test3',
        }
    },
    {
        Name => 'array of hashes with arrays of hashes in text',
        Variables => {
            Test1 => [
                {},
                {
                    Test2 => [
                        {
                            Test3 => 'test'
                        }
                    ]
                }
            ]
        },
        Data => {
            Dummy => 'this is a ${Test1:1.Test2:0.Test3}. a good one',
        },
        Expected => {
            Dummy => 'this is a test. a good one',
        }
    },
    {
        Name => 'array of hashes with arrays of hashes direct assignment of structure',
        Variables => {
            Test1 => [
                {},
                {
                    Test2 => [
                        {
                            Test3 => 'test'
                        }
                    ]
                }
            ]
        },
        Data => {
            Dummy => '${Test1:1.Test2}',
        },
        Expected => {
            Dummy => [
                {
                    Test3 => 'test'
                }
            ]
        }
    },
    {
        Name => 'nested variables (2 levels)',
        Variables => {
            Test1 => {
                Test2 => {
                    Test3 => 'found!'
                }
            },
            Indexes => {
                '1st' => 'Test2',
                '2nd' => 'Test3'
            }
        },
        Data => {
            Dummy => '${Test1.${Indexes.1st}.${Indexes.2nd}}',
        },
        Expected => {
            Dummy => 'found!'
        }
    },
    {
        Name => 'nested variables (4 levels)',
        Variables => {
            Test1 => {
                Test2 => {
                    Test3 => 'found!'
                }
            },
            Indexes => {
                '1st' => 'Test2',
                '2nd' => 'Test3'
            },
            Which => {
                'the first one' => '1st',
                Index => {
                    Should => {
                        I => {
                            Use => [
                                'none',
                                '2nd',
                                'the first one',
                                '3rd'
                            ]
                        }
                    }
                }
            },
        },
        Data => {
            Dummy => '${Test1.${Indexes.${Which.${Which.Index.Should.I.Use:2}}}.${Indexes.2nd}}',
        },
        Expected => {
            Dummy => 'found!'
        }
    },
    {
        Name => 'nested variable in filter',
        Variables => {
            Variable1 => '2022-10-01 12:22:33',
            Variable2 => 3,
            Variable3 => 'TimeStamp'
        },
        Data => {
            Result => '${Variable1|DateUtil.Calc(+${Variable2}M)|DateUtil.UnixTime|DateUtil.${Variable3}}',
        },
        Expected => {
            Result => '2023-01-01 12:22:33'
        }
    },
    {
        Name => 'base64 filter',
        Variables => {
            Variable1 => 'test123',
        },
        Data => {
            Result => '
1: ${Variable1|base64}
2: ${Variable1|ToBase64}
3: ${Variable1|ToBase64|FromBase64}
',
        },
        Expected => {
            Result => '
1: dGVzdDEyMw==
2: dGVzdDEyMw==
3: test123
'
        }
    },
    {
        Name => 'base64 filter with whitespaces ',
        Variables => {
            Variable1 => 'test123',
        },
        Data => {
            Result => '
1: ${Variable1 |base64}
2: ${Variable1| ToBase64}
3: ${Variable1 | ToBase64|FromBase64 }
',
        },
        Expected => {
            Result => '
1: dGVzdDEyMw==
2: dGVzdDEyMw==
3: test123
'
        }
    },
    {
        Name => 'base64 filter with binary content containing pipe characters',
        Variables => {
            Variable1 => $TestPNGBase64,
        },
        Data => {
            Result => '${Variable1|FromBase64}',
        },
        Expected => {
            Result => $TestPNGBin,
        }
    },
    {
        Name => 'base64 filter with binary content containing pipe characters in json-text',
        Variables => {
            Article => {
                Attachments => [
                    {
                        Filename    => 'test.png',
                        ContentType => 'image/png',
                        Content     => $TestPNGBase64,
                    }
                ]
            },
        },
        Data => {
            Result => <<'END'
[
    {
        "file": [
            undef,
            "${Article.Attachments:0.Filename}",
            {
                "content-type": "${Article.Attachments:0.ContentType}"
            },
            {
                "content": "${Article.Attachments:0.Content|FromBase64|ToJSON}"
            }
        ]
    }
]
END
        },
        Expected => {
            Result => <<"END"
[
    {
        "file": [
            undef,
            "test.png",
            {
                "content-type": "image/png"
            },
            {
                "content": $TestPNGBinJSON
            }
        ]
    }
]
END
        }
    },
    {
        Name => 'JSON filter in text',
        Variables => {
            Variable1 => {
                key => 'test123',
            }
        },
        Data => {
            Result => '
1: ${Variable1|JSON}
2: ${Variable1|ToJSON}
',
        },
        Expected => {
            Result => '
1: {"key":"test123"}
2: {"key":"test123"}
'
        }
    },
    {
        Name => 'JSON filter as object assignment',
        Variables => {
            Variable1 => {
                key => 'test123',
            }
        },
        Data => {
            Result => '${Variable1|ToJSON|FromJSON}',
        },
        Expected => {
            Result => {
                key => 'test123',
            }
        }
    },
    {
        Name => 'jq filter',
        Variables => {
            Variable1 => '[
                { "Key": 1, "Value": 1111, "Flag": "a" },
                { "Key": 2, "Value": 2222, "Flag": "b" },
                { "Key": 3, "Value": 3333, "Flag": "a" }
            ]'
        },
        Data => {
            Result => '${Variable1|jq(. - map(. :: select(.Flag=="b")) :: .[] .Key)}',
        },
        Expected => {
            Result => '1
3',
        }
    },
    {
        Name => 'Combine variables as array',
        Variables => {
            Test1 => 'Test1',
            Test2 => 'Test2',
        },
        Data => {
            Dummy => '${Test1,Test2}',
        },
        Expected => {
            Dummy => ['Test1','Test2'],
        }
    },
    {
        Name => 'Combine variables as array with whitespace after comma',
        Variables => {
            Test1 => 'Test1',
            Test2 => 'Test2',
        },
        Data => {
            Dummy => '${Test1, Test2}',
        },
        Expected => {
            Dummy => ['Test1','Test2'],
        }
    },
    {
        Name => 'Combine variables containing arrays as array',
        Variables => {
            Test1 => [
                'Test1.1',
                'Test1.2'
            ],
            Test2 => [
                'Test2.1',
                'Test2.2'
            ],
        },
        Data => {
            Dummy => '${Test1,Test2}',
        },
        Expected => {
            Dummy => ['Test1.1','Test1.2','Test2.1','Test2.2'],
        }
    },
    {
        Name => 'Combine variables containing arrays as array with whitespace after comma',
        Variables => {
            Test1 => [
                'Test1.1',
                'Test1.2'
            ],
            Test2 => [
                'Test2.1',
                'Test2.2'
            ],
        },
        Data => {
            Dummy => '${Test1, Test2}',
        },
        Expected => {
            Dummy => ['Test1.1','Test1.2','Test2.1','Test2.2'],
        }
    },
    {
        Name => 'Multiple line data without leading or trailing content on line with variable',
        Variables => {
            Test1 => 'Variable: 1',
        },
        Data => {
            Dummy => 'Static: 1
${Test1}
Static: 2'
        },
        Expected => {
            Dummy => 'Static: 1
Variable: 1
Static: 2',
        }
    },
);

$TestCount = 0;
foreach my $Test ( @Tests ) {
    $TestCount++;

    my %Data      = %{$Test->{Data}};
    my %Variables = %{$Test->{Variables}};

    $Kernel::OM->Get('Main')->ReplaceVariables(
        Data      => \%Data,
        Variables => \%Variables
    );

    $Self->IsDeeply(
        \%Data,
        $Test->{Expected},
        'ReplaceVariables() Test "'.$Test->{Name}.'"',
    );
}

my @GetAssignedSearchAttributesTests = (
    {
        Name         => 'Missing parameter "AssignedObjectType"',
        ConfigSet    => '',
        Parameter    => {
            ObjectType => 'Contact',
            Silent     => 1
        },
        Expected     => undef,
        InfoMessage  => undef,
        ErrorMessage => 'Need AssignedObjectType!'
    },
    {
        Name         => 'Missing parameter "ObjectType"',
        ConfigSet    => '',
        Parameter    => {
            AssignedObjectType => 'Ticket',
            Silent             => 1
        },
        Expected     => undef,
        InfoMessage  => undef,
        ErrorMessage => 'Need ObjectType!'
    },
    {
        Name         => 'Unset SysConfig "AssignedObjectsMapping"',
        ConfigSet    => '',
        Parameter    => {
            AssignedObjectType => 'Ticket',
            ObjectType         => 'Contact',
            Silent             => 1
        },
        Expected     => {},
        InfoMessage  => 'SysConfig "AssignedObjectsMapping" not set',
        ErrorMessage => undef
    },
    {
        Name         => 'SysConfig "AssignedObjectsMapping" without matching ObjectType/AssignedObjectType',
        ConfigSet    => '{"Ticket":{"Contact":{"OrganisationID":{"SearchAttributes":["RelevantOrganisationID"]},"ContactID":{"SearchAttributes":["ID"]}}}}',
        Parameter    => {
            AssignedObjectType => 'Ticket',
            ObjectType         => 'Contact',
            Silent             => 1
        },
        Expected     => {},
        InfoMessage  => 'ObjectType "Contact" or AssignedObjectType "Ticket" not contained in SysConfig "AssignedObjectsMapping"',
        ErrorMessage => undef
    },
    {
        Name         => 'SysConfig "AssignedObjectsMapping" with matching ObjectType/AssignedObjectType',
        ConfigSet    => '{"Contact":{"Ticket":{"OrganisationID":{"SearchAttributes":["RelevantOrganisationID"]},"ContactID":{"SearchAttributes":["ID"]}}}}',
        Parameter    => {
            AssignedObjectType => 'Ticket',
            ObjectType         => 'Contact',
            Silent             => 1
        },
        Expected     => {
            ContactID => {
                SearchAttributes => ['ID']
            },
            OrganisationID => {
                SearchAttributes => ['RelevantOrganisationID']
            }
        },
        InfoMessage  => undef,
        ErrorMessage => undef
    }
);
for my $Test ( @GetAssignedSearchAttributesTests ) {
    $Helper->ConfigSettingChange(
        Key   => 'AssignedObjectsMapping',
        Value => $Test->{ConfigSet}
    );

    # clear logstack
    $Kernel::OM->Get('Log')->{LogStack}->{4} = [];
    $Kernel::OM->Get('Log')->{LogStack}->{16} = [];

    my $SearchAttributes = $Kernel::OM->Get('Main')->GetAssignedSearchAttributes(
        %{ $Test->{Parameter} }
    );
    $Self->IsDeeply(
        $SearchAttributes,
        $Test->{Expected},
        'GetAssignedSearchAttributes: ' . $Test->{Name} . ': Result',
    );

    my $InfoMessage = $Kernel::OM->Get('Log')->GetLogEntry(
        Type => 'info',
        What => 'Message',
    );
    $Self->IsDeeply(
        $InfoMessage,
        $Test->{InfoMessage},
        'GetAssignedSearchAttributes: ' . $Test->{Name} . ': InfoMessage'
    );

    my $ErrorMessage = $Kernel::OM->Get('Log')->GetLogEntry(
        Type => 'error',
        What => 'Message',
    );
    $Self->IsDeeply(
        $ErrorMessage,
        $Test->{ErrorMessage},
        'GetAssignedSearchAttributes: ' . $Test->{Name} . ': ErrorMessage'
    );
}

my @GetAssignedSearchParamsTests = (
    {
        Name         => 'Missing parameter "AssignedObjectType"',
        ConfigSet    => '',
        Parameter    => {
            ObjectType => 'Contact',
            Silent     => 1
        },
        Expected     => {},
        InfoMessage  => undef,
        ErrorMessage => 'Need AssignedObjectType!'
    },
    {
        Name         => 'Missing parameter "ObjectType"',
        ConfigSet    => '',
        Parameter    => {
            AssignedObjectType => 'Ticket',
            Silent             => 1
        },
        Expected     => {},
        InfoMessage  => undef,
        ErrorMessage => 'Need ObjectType!'
    },
    {
        Name         => 'Unset SysConfig "AssignedObjectsMapping"',
        ConfigSet    => '',
        Parameter    => {
            AssignedObjectType => 'Ticket',
            ObjectType         => 'Contact',
            Silent             => 1
        },
        Expected     => {},
        InfoMessage  => 'SysConfig "AssignedObjectsMapping" not set',
        ErrorMessage => undef
    },
    {
        Name         => 'SysConfig "AssignedObjectsMapping" without matching ObjectType/AssignedObjectType',
        ConfigSet    => '{"Ticket":{"Contact":{"OrganisationID":{"SearchAttributes":["RelevantOrganisationID"]},"QueueID":{"SearchStatic":["1"]}}}}',
        Parameter    => {
            AssignedObjectType => 'Ticket',
            ObjectType         => 'Contact',
            Silent             => 1
        },
        Expected     => {},
        InfoMessage  => 'ObjectType "Contact" or AssignedObjectType "Ticket" not contained in SysConfig "AssignedObjectsMapping"',
        ErrorMessage => undef
    },
    {
        Name         => 'SysConfig "AssignedObjectsMapping" with matching ObjectType/AssignedObjectType, without Object',
        ConfigSet    => '{"Contact":{"Ticket":{"OrganisationID":{"SearchAttributes":["RelevantOrganisationID"]},"QueueID":{"SearchStatic":["1"]}}}}',
        Parameter    => {
            AssignedObjectType => 'Ticket',
            ObjectType         => 'Contact'
        },
        Expected     => {
            QueueID => [1]
        },
        InfoMessage  => undef,
        ErrorMessage => undef
    },
    {
        Name         => 'SysConfig "AssignedObjectsMapping" with matching ObjectType/AssignedObjectType, with Object',
        ConfigSet    => '{"Contact":{"Ticket":{"OrganisationID":{"SearchAttributes":["RelevantOrganisationID"]},"QueueID":{"SearchStatic":["1"]}}}}',
        Parameter    => {
            AssignedObjectType => 'Ticket',
            ObjectType         => 'Contact',
            Object             => {
                RelevantOrganisationID => 2
            }
        },
        Expected     => {
            QueueID        => [1],
            OrganisationID => [2]
        },
        InfoMessage  => undef,
        ErrorMessage => undef
    }
);
for my $Test ( @GetAssignedSearchParamsTests ) {
    $Helper->ConfigSettingChange(
        Key   => 'AssignedObjectsMapping',
        Value => $Test->{ConfigSet}
    );

    # clear logstack
    $Kernel::OM->Get('Log')->{LogStack}->{4} = [];
    $Kernel::OM->Get('Log')->{LogStack}->{16} = [];

    my %SearchData = $Kernel::OM->Get('Main')->GetAssignedSearchParams(
        %{ $Test->{Parameter} }
    );
    $Self->IsDeeply(
        \%SearchData,
        $Test->{Expected},
        'GetAssignedSearchParams: ' . $Test->{Name} . ': Result',
    );

    my $InfoMessage = $Kernel::OM->Get('Log')->GetLogEntry(
        Type => 'info',
        What => 'Message',
    );
    $Self->IsDeeply(
        $InfoMessage,
        $Test->{InfoMessage},
        'GetAssignedSearchParams: ' . $Test->{Name} . ': InfoMessage'
    );

    my $ErrorMessage = $Kernel::OM->Get('Log')->GetLogEntry(
        Type => 'error',
        What => 'Message',
    );
    $Self->IsDeeply(
        $ErrorMessage,
        $Test->{ErrorMessage},
        'GetAssignedSearchParams: ' . $Test->{Name} . ': ErrorMessage'
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
