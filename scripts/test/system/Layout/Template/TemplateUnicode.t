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

use File::Basename qw();

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

# call Output() once so that the TT objects are created.
$LayoutObject->Output( Template => '' );

# now add this directory as include path to be able to use the test templates
my $IncludePaths = $LayoutObject->{TemplateProviderObject}->include_path();
unshift @{$IncludePaths},
    $Kernel::OM->Get('Config')->Get('Home') . '/scripts/test/system/Layout/Template';
$LayoutObject->{TemplateProviderObject}->include_path($IncludePaths);

$Kernel::OM->Get('Cache')->CleanUp();

# uncached and cached
for ( 1 .. 2 ) {
    my $Result = $LayoutObject->Output(
        TemplateFile => 'TemplateUnicode',
    );

    $Self->Is(
        $Result,
        "some unicode content ä ø\n",
        'Template is considered UTF8',
    );
}

# cleanup cache is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
