# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

# create language object which contains all translations
$Kernel::OM->ObjectParamAdd(
    'Language' => {
        UserLanguage => 'de',
    },
);
my $LanguageObject = $Kernel::OM->Get('Language');

# test cases
my @Tests = (
    {
        OriginalString    => '0',    # test with zero
        TranslationString => '',     # test without a translation string
        TranslationResult => '0',
    },
    {
        OriginalString    => 'KIXLanguageUnitTest::Test1',
        TranslationString => 'Test1',
        TranslationResult => 'Test1',
        Parameters        => ['Hallo'],                       # test with not needed parameter
    },
    {
        OriginalString    => 'KIXLanguageUnitTest::Test2',
        TranslationString => 'Test2 [%s]',
        TranslationResult => 'Test2 [Hallo]',
        Parameters        => ['Hallo'],
    },
    {
        OriginalString    => 'KIXLanguageUnitTest::Test3',
        TranslationString => 'Test3 [%s] (A=%s)',
        TranslationResult => 'Test3 [Hallo] (A=A)',
        Parameters        => [ 'Hallo', 'A' ],
    },
    {
        OriginalString    => 'KIXLanguageUnitTest::Test4',
        TranslationString => 'Test4 [%s] (A=%s;B=%s)',
        TranslationResult => 'Test4 [Hallo] (A=A;B=B)',
        Parameters        => [ 'Hallo', 'A', 'B' ],
    },
    {
        OriginalString    => 'KIXLanguageUnitTest::Test5',
        TranslationString => 'Test5 [%s] (A=%s;B=%s;C=%s)',
        TranslationResult => 'Test5 [Hallo] (A=A;B=B;C=C)',
        Parameters        => [ 'Hallo', 'A', 'B', 'C' ],
    },
    {
        OriginalString    => 'KIXLanguageUnitTest::Test6',
        TranslationString => 'Test6 [%s] (A=%s;B=%s;C=%s;D=%s)',
        TranslationResult => 'Test6 [Hallo] (A=A;B=B;C=C;D=D)',
        Parameters        => [ 'Hallo', 'A', 'B', 'C', 'D' ],
    },
    {
        OriginalString    => 'KIXLanguageUnitTest::Test7 [% test %] {" special characters %s"}',
        TranslationString => 'Test7 [% test %] {" special characters %s"}',
        TranslationResult => 'Test7 [% test %] {" special characters test"}',
        Parameters        => ['test'],
    },
);

for my $Test (@Tests) {

    # add translation string to language object
    $LanguageObject->{Translation}->{ $Test->{OriginalString} } = $Test->{TranslationString};

    # get the translation
    my $TranslatedString;

    # test cases with parameters
    if ( $Test->{Parameters} ) {

        $TranslatedString = $LanguageObject->Translate(
            $Test->{OriginalString},
            @{ $Test->{Parameters} },
        );
    }

    # test cases without a parameter
    else {
        $TranslatedString = $LanguageObject->Translate(
            $Test->{OriginalString},
        );
    }

    # compare with expected translation
    $Self->Is(
        $TranslatedString // '',
        $Test->{TranslationResult},
        'Translation of ' . $Test->{OriginalString},
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
