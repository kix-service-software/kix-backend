# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Render::Page;

use strict;
use warnings;

use base qw(
    Kernel::System::HTMLToPDF::Render::Common
);

our $ObjectManagerDisabled = 1;


sub Run {
    my ($Self, %Param) = @_;
    my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

    my $Datas = $Param{Data};
    my $Block = $Param{Block};
    my $Css   = q{};

    if (
        $Block->{ID}
        && !$Self->{CSSIDs}->{$Block->{ID}}
    ) {
        $LayoutObject->Block(
            Name => 'CSS',
            Data => $Block
        );

        $Css = $LayoutObject->Output(
            TemplateFile => 'HTMLToPDF/Page',
        );
        $Self->{CSSIDs}->{$Block->{ID}} = 1;
    }

    $LayoutObject->Block(
        Name => 'HTML',
        Data => {
            Translate => $Block->{Translate},
            PageOf    => $Block->{PageOf},
            ID        => $Block->{ID}
        }
    );

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Page',
    );

    return (
        HTML => $HTML,
        Css  => $Css
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
