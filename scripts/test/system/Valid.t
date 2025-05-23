# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
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

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
my $ValidObject  = $Kernel::OM->Get('Valid');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# tests the method to make sure there is at least 2 registries: valid - invalid
my %ValidList = $ValidObject->ValidList();

my $ValidListLength = keys %ValidList;

$Self->True(
    $ValidListLength > 1,
    'Valid length.',
);

# tests ValidIDsGet. At least 1 valid registry
my @ValidIDsList = $ValidObject->ValidIDsGet();

$Self->True(
    scalar @ValidIDsList >= 1,
    'Valid registry exists.',
);

my $Counter;
for my $ValidID (@ValidIDsList) {
    $Counter++;
    $Self->True(
        $ValidList{$ValidID},
        "Test ValidIDsGet $Counter with array exists.",
    );
}

# makes sure that all ValidIDs in the array are also in the hash containing all IDs
$Counter = 0;
for my $ValidIDKey ( sort keys %ValidList ) {
    my $Number = scalar grep /^\Q$ValidIDKey\E$/, @ValidIDsList;
    $Counter++;
    if ( $ValidList{$ValidIDKey} eq 'valid' ) {
        $Self->True(
            $Number,
            "Test ValidIDsGet $Counter with hash exists.",
        );
    }
    else {
        $Self->False(
            $Number,
            "Test ValidIDsGet $Counter with hash doesn't exists.",
        );
    }

    # tests ValidLookup to verify the values of the hash
    my $ValidLookupName = $ValidObject->ValidLookup( ValidID => $ValidIDKey );
    $Self->Is(
        $ValidLookupName,
        $ValidList{$ValidIDKey},
        "Test ValidLookup $Counter - both names are equivalent.",
    );

    $ValidLookupName = $ValidList{$ValidIDKey};
    my $ValidLookupID = $ValidObject->ValidLookup( Valid => $ValidLookupName );
    $Self->Is(
        $ValidLookupID,
        $ValidIDKey,
        "Test ValidLookup $Counter - both IDs are equivalent.",
    );
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
