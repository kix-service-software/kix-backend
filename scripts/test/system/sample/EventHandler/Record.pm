# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package scripts::test::system::sample::EventHandler::Record;

use strict;
use warnings;

# package-level counter (shared by all instances)
our $Called = 0;

sub new {
    my ($Type) = @_;
    return bless { }, $Type;
}

sub Run {
    $Called++;
    return 1;
}

# reset the counter
sub Reset {
    $Called = 0;
    return 1;
}

# read the counter (called from the test via the Get() instance)
sub CalledCount {
    return $Called;
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