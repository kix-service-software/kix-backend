#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
        LogPrefix => 'framework_update-to-build-2165',
    },
);

use vars qw(%INC);

_UpdateHTMLToPDF();

sub _UpdateHTMLToPDF {

    my %Template = $Kernel::OM->Get('HTMLToPDF')->TemplateGet(
        Name   => 'Ticket',
        UserID => 1
    );

    if (%Template && $Template{Definition}) {
        if (ref $Template{Definition} ne 'string' ) {
            $Template{Definition} = $Kernel::OM->Get('JSON')->Encode(
                Data => $Template{Definition}
            );
        }

        if ($Template{Definition} =~ m/Responsoble/) {
            $Template{Definition} =~ s/Responsoble/Responsible/;

            $Kernel::OM->Get('HTMLToPDF')->TemplateUpdate(
                %Template,
                UserID => 1
            );

            # delete whole cache
            $Kernel::OM->Get('Cache')->CleanUp();
        }
    }

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
