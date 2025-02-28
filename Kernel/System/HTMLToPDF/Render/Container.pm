# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Render::Container;

use strict;
use warnings;

use base qw(
    Kernel::System::HTMLToPDF::Render::Common
);

our $ObjectManagerDisabled = 1;

sub Run {
    my ($Self, %Param) = @_;
    my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

    return $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Container',
        Data => {
            Value     => $Param{Data}->{Value},
            HasPage   => $Param{Data}->{HasPage} // 0,
            CSS       => $Param{Data}->{CSS} || q{},
            IsContent => $Param{Data}->{IsContent}
        }
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