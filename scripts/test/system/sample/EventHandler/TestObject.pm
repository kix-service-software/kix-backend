# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package scripts::test::system::sample::EventHandler::TestObject;

use strict;
use warnings;

use base qw(Kernel::System::EventHandler);

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {};
    bless $Self, $Type;
    return $Self;
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