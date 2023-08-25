# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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
my $MainObject       = $Kernel::OM->Get('Main');
my $SystemDataObject = $Kernel::OM->Get('SystemData');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# add system data
my $SystemDataNameRand0 = 'systemdata' . $Helper->GetRandomID();

my $Success = $SystemDataObject->SystemDataSet(
    Key    => $SystemDataNameRand0,
    Value  => $SystemDataNameRand0,
    UserID => 1,
);

$Self->True(
    $Success,
    "SystemDataSet() - set '$SystemDataNameRand0'",
);

# another time, it should fail
$Success = $SystemDataObject->SystemDataSet(
    Key    => $SystemDataNameRand0,
    Value  => $SystemDataNameRand0,
    UserID => 1,
);

$Self->True(
    $Success,
    "SystemDataSet() - override '$SystemDataNameRand0'",
);

my $SystemData = $SystemDataObject->SystemDataGet( Key => $SystemDataNameRand0 );

$Self->True(
    $SystemData eq $SystemDataNameRand0,
    'SystemDataGet() - value',
);

my $SystemDataSet = $SystemDataObject->SystemDataSet(
    Key    => $SystemDataNameRand0,
    Value  => 'update' . $SystemDataNameRand0,
    UserID => 1,
);

$Self->True(
    $SystemDataSet,
    'SystemDataSet() - update',
);

$SystemData = $SystemDataObject->SystemDataGet( Key => $SystemDataNameRand0 );

$Self->Is(
    $SystemData,
    'update' . $SystemDataNameRand0,
    'SystemDataGet() - after update',
);

my $SystemDataDelete = $SystemDataObject->SystemDataDelete(
    Key    => $SystemDataNameRand0,
    UserID => 1,
);

$Self->True(
    $SystemDataDelete,
    'SystemDataDelete() - removed key',
);

$SystemData = $SystemDataObject->SystemDataGet( Key => $SystemDataNameRand0 );

$Self->False(
    $SystemData,
    'SystemDataGet() - data is gone after delete',
);

# test setting value to empty string
# add system data 1
my $SystemDataNameRand1 = 'systemdata' . $Helper->GetRandomID();

$Success = $SystemDataObject->SystemDataSet(
    Key    => $SystemDataNameRand1,
    Value  => '',
    UserID => 1,
);

$Self->True(
    $Success,
    "SystemDataSet() - set '$SystemDataNameRand1' value empty string",
);

$SystemData = $SystemDataObject->SystemDataGet( Key => $SystemDataNameRand1 );

$Self->Is(
    $SystemData,
    '',
    'SystemDataGet() - value - empty string',
);

# set to 0
$Success = $SystemDataObject->SystemDataSet(
    Key    => $SystemDataNameRand1,
    Value  => 0,
    UserID => 1,
);

$Self->True(
    $Success,
    "SystemDataSet() - set '$SystemDataNameRand1' value 0",
);

$SystemData = $SystemDataObject->SystemDataGet( Key => $SystemDataNameRand1 );

$Self->IsDeeply(
    $SystemData,
    0,
    'SystemDataGet() - value - 0',
);

$SystemDataSet = $SystemDataObject->SystemDataSet(
    Key    => $SystemDataNameRand1,
    Value  => 'update',
    UserID => 1,
);

$Self->True(
    $SystemDataSet,
    'SystemDataUpdate()',
);

$SystemData = $SystemDataObject->SystemDataGet( Key => $SystemDataNameRand1 );

$Self->Is(
    $SystemData,
    'update',
    'SystemDataGet() - after update',
);

$SystemDataDelete = $SystemDataObject->SystemDataDelete(
    Key    => $SystemDataNameRand1,
    UserID => 1,
);

$Self->True(
    $SystemDataDelete,
    'SystemDataDelete() - removed key',
);

my $SystemDataGroupRand = 'systemdata' . $Helper->GetRandomID();

my %Hash = (
    Foo  => 'bar',
    Bar  => 'baz',
    Beef => {
        Alias => 'spam'
    },
);

my $Result = $SystemDataObject->SystemDataSet(
    Key    => $SystemDataGroupRand,
    Value  => \%Hash,
    UserID => 1,
);
$Self->True(
    $Result,
    "SystemDataSet: set hash value",
);

$SystemData = $SystemDataObject->SystemDataGet( Key => $SystemDataGroupRand );

$Self->IsDeeply(
    $SystemData,
    \%Hash,
    'SystemDataGet() - hash value',
);

my @Array = (
    'bar',
    'baz',
    {
        Alias => 'spam'
    }
);

$Result = $SystemDataObject->SystemDataSet(
    Key    => $SystemDataGroupRand,
    Value  => \@Array,
    UserID => 1,
);
$Self->True(
    $Result,
    "SystemDataSet: set array value",
);

$SystemData = $SystemDataObject->SystemDataGet( Key => $SystemDataGroupRand );

$Self->IsDeeply(
    $SystemData,
    \@Array,
    'SystemDataGet() - array value',
);

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
