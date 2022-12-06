#!/usr/bin/perl
# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1656',
    },
);

use vars qw(%INC);

_UpdateHTMLToPDF();

sub _UpdateHTMLToPDF {

    my $HTMLTOPDFObject = $Kernel::OM->Get('HTMLToPDF');

    my %Template = $HTMLTOPDFObject->DefinitionGet(
        Name   => 'Article',
        UserID => 1
    );

    return 1 if !%Template;

    $HTMLTOPDFObject->DefinitionUpdate(
        %Template,
        Definition => '{"Expands":["DynamicField"],"Page":{"Top":"15","Left":"20","Right":"15","Bottom":"15","SpacingHeader":"10","SpacingFooter":"5"},"Header":[{"ID":"PageLogo","Type":"Image","Value":"agent-portal-logo","TypeOf":"DB","Style":{"Width":"2.5rem","Height":"2.5rem","Float":"left"}}],"Content":[{"ID":"Subject","Type":"Text","Value":"<KIX_ARTICLE_Subject>","Style":{"Size":"1.1rem"}},{"ID":"PrintedBy","Type":"Text","Value":["printed by","<Current_User>","<Current_Time>"],"Join":" ","Translate":true},{"Blocks":[{"ID":"ArticleMeta","Type":"Table","Columns":["<Font_Bold>Key","Value"],"Allow":{"From":"KEY","Subject":"KEY","CreateTime":"KEY","Channel":"KEY"},"Translate":true},{"ID":"ArticleBody","Type":"Richtext","Value":"<KIX_ARTICLE_BodyRichtext>"}]}],"Footer":[{"ID":"Paging","Type":"Page","PageOf":0,"Translate":true,"Style":{"Float":"right"}}]}',
        UserID     => 1
    );

    # delete whole cache
    $Kernel::OM->Get('Cache')->CleanUp();

    return 1;
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
