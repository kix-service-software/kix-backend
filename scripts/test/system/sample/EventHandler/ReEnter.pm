# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package scripts::test::system::sample::EventHandler::ReEnter;

use strict;
use warnings;

# Set by the test before the flush; points to the TestObject
# on which the outer EventHandlerTransaction() is running.
our $TestObject;

sub new {
    my ($Type) = @_;
    return bless { }, $Type;
}

sub Run {
    # Re-entrant call - must be a no-op while the outer flush is running
    $TestObject->EventHandlerTransaction() if $TestObject;
    return 1;
}

# assign the TestObject (called from the test via the Get() instance)
sub SetTestObject {
    my ( $Self, $Object ) = @_;
    $TestObject = $Object;
    return 1;
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