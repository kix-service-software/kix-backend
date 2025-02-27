# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get DB object
my $DBObject = $Kernel::OM->Get('DB');

my $Version = $DBObject->Version();

$Self->True(
    $Version,
    "DBObject Version() generated version $Version",
);

$Self->IsNot(
    $Version,
    'unknown',
    "DBObject Version() generated version $Version",
);

# extract text string and version number from Version
# just as a sanity check
my ( $Text, $Number ) = $Version =~ /(\w+)\s+([0-9\.]+)/;

$Self->True(
    $Text,
    "DBObject Version() $Version contains a name (found $Text)",
);

$Self->True(
    $Number,
    "DBObject Version() $Version contains a version number (found $Number)",
);

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
