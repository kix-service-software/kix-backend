#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
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
        LogPrefix => 'framework_update-to-build-2084',
    },
);

use vars qw(%INC);

_UpdateHTMLToPDF();

sub _UpdateHTMLToPDF {

    my $HTMLTOPDFObject = $Kernel::OM->Get('HTMLToPDF');

    for my $TemplateName ( qw(Ticket Article) ) {
        my %Template = $HTMLTOPDFObject->TemplateGet(
            Name   => $TemplateName,
            UserID => 1
        );

        next if ( !%Template );

        if ( $Template{Definition} =~ m/<KIX_ARTICLE_BodyRichtext>/ ) {
            $Template{Definition} =~ s/<KIX_ARTICLE_BodyRichtext>/<KIX_ARTICLE_BodyRichtext_0>/g;

            $HTMLTOPDFObject->TemplateUpdate(
                %Template,
                UserID => 1
            );
        }
    }

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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
