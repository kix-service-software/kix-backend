# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# use ReferenceData ISO list
$Kernel::OM->Get('Config')->Set(
    Key   => 'ReferenceData::OwnCountryList',
    Value => undef,
);

# tests the method to make sure there are at least 100 countries
my $CountryList = $Kernel::OM->Get('ReferenceData')->CountryList();

my $CountryListLength = scalar keys %$CountryList;

$Self->True(
    $CountryListLength > 100,
    "There are $CountryListLength countries registered",
);

# let's assume these countries don't go anywhere
my @CountryList = ( 'Netherlands', 'Germany', 'Switzerland', 'United States of America', 'Japan' );

for my $Country (@CountryList) {
    $Self->True(
        $$CountryList{$Country},
        "Testing existence of country ($Country)",
    );
}

# set configuration to small list
$Kernel::OM->Get('Config')->Set(
    Key   => 'ReferenceData::OwnCountryList',
    Value => {
        'FR' => 'France',
        'NL' => 'Netherlands',
        'DE' => 'Germany'
    },
);

$CountryList = $Kernel::OM->Get('ReferenceData')->CountryList();

@CountryList = ( 'Switzerland', 'United States', 'Japan' );

for my $Country (@CountryList) {
    $Self->False(
        $$CountryList{$Country},
        "OwnCountryList: Testing non-existence of country ($Country)",
    );
}

@CountryList = ( 'France', 'Netherlands', 'Germany' );

for my $Country (@CountryList) {
    $Self->True(
        $$CountryList{$Country},
        "OwnCountryList: Testing existence of country ($Country)",
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
