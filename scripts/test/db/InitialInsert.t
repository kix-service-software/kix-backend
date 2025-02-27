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

use XML::Simple;

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# check initial inserts

# read schema file
my $XMLFile = $Kernel::OM->Get('Config')->Get('Home').'/scripts/database/kix-schema.xml';

$Self->True(
    (-f $XMLFile),
    'Schema file exists',
);

my $Content = $Kernel::OM->Get('Main')->FileRead(
    Location => $XMLFile,
);

$Self->True(
    ref $Content eq 'SCALAR',
    'Schema file can be read',
);

$Content = ${$Content};

my $XMLObject = XML::Simple->new( KeepRoot => 0 );

$Self->True(
    $XMLObject,
    'XMLObject is created',
);

my $XMLRef = $XMLObject->XMLin($Content, KeyAttr => 'Name');

$Self->True(
    IsHashRefWithData($XMLRef),
    'XML schema content can be parsed',
);

$Self->True(
    IsHashRefWithData($XMLRef->{Table}),
    'XML schema contains table definitions',
);

my %Tables = %{$XMLRef->{Table}};

# read insert file
$XMLFile = $Kernel::OM->Get('Config')->Get('Home').'/scripts/database/kix-initial_insert.xml';

$Self->True(
    (-f $XMLFile),
    'Initial insert file exists',
);

$Content = $Kernel::OM->Get('Main')->FileRead(
    Location => $XMLFile,
);

$Self->True(
    ref $Content eq 'SCALAR',
    'Initial insert file can be read',
);

$Content = ${$Content};

$XMLRef = $XMLObject->XMLin($Content, ForceArray => [ 'Insert' ]);

$Self->True(
    IsHashRefWithData($XMLRef),
    'XML content can be parsed',
);

$Self->True(
    IsArrayRefWithData($XMLRef->{Insert}),
    'XML contains insert definitions',
);

foreach my $Insert ( @{$XMLRef->{Insert}} ) {

    # check if the given table exists in schema
    $Self->True(
        $Tables{$Insert->{Table}},
        'Insert uses existing table "'.$Insert->{Table}.'"',
    );

    # check if insert is empty
    $Self->True(
        IsArrayRefWithData($Insert->{Data}),
        'Insert into "'.$Insert->{Table}.'" contains data',
    );

    # check if all columns exist in the table
    if ( IsArrayRefWithData($Insert->{Data}) ) {
        foreach my $Data ( @{$Insert->{Data}} ) {
            $Self->True(
                $Tables{$Insert->{Table}}->{Column}->{$Data->{Key}},
                'Insert into "'.$Insert->{Table}.'" uses an existing column "'.$Data->{Key}.'"',
            );
        }
    }
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
