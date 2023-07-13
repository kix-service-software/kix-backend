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

use Kernel::System::VariableCheck qw(:all);

use vars (qw($Self));

# get SysConfigLanguage object
my $SysConfigObject = $Kernel::OM->Get('SysConfig');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

########################################################################################################################################
# OptionType handling
########################################################################################################################################

my @TypeList = $SysConfigObject->OptionTypeList();

$Self->True(
    IsArrayRefWithData(\@TypeList),
    'OptionTypeList()',
);

########################################################################################################################################
# Option handling
########################################################################################################################################

# add option
my $Random = 'Option' . $Helper->GetRandomID();

my $Result = $SysConfigObject->OptionAdd(
    Name        => $Random.'String',
    Description => 'some description',
    AccessLevel => 'internal',
    Setting     => {
        "RegEx" => ""
    },
    Type        => 'String',
    UserID      => 1,
);

$Self->True(
    $Result,
    'OptionAdd() - String',
);

$Result = $SysConfigObject->OptionAdd(
    Name        => $Random.'Option',
    Description => 'some description',
    AccessLevel => 'internal',
    Setting     => {
        "0" => "No",
        "1" => "Yes"
    },
    Default     => 0,
    Type        => 'Option',
    UserID      => 1,
);

$Self->True(
    $Result,
    'OptionAdd() - Option',
);

$Result = $SysConfigObject->OptionAdd(
    Name        => $Random.'Array',
    Description => 'some description',
    AccessLevel => 'internal',
    Setting     => [ "Normal", "ParentChild" ],
    Type        => 'Array',
    UserID      => 1,
);

$Self->True(
    $Result,
    'OptionAdd() - Array',
);

$Result = $SysConfigObject->OptionAdd(
    Name        => $Random.'Hash',
    Description => 'some description',
    AccessLevel => 'internal',
    Setting     => {
        "SourceName" => "Parent",
        "TargetName" => "Child"
    },
    Type        => 'Hash',
    UserID      => 1,
);

$Self->True(
    $Result,
    'OptionAdd() - Hash',
);

my @List = $SysConfigObject->OptionList();

$Self->True(
    IsArrayRefWithData(\@List),
    'OptionList() after create',
);

my %AllOptions = $SysConfigObject->OptionGetAll();

$Self->True(
    IsHashRefWithData(\%AllOptions),
    'OptionGetAll()',
);

my %Option = $SysConfigObject->OptionGet(
    Name => $Random.'Hash',
);

$Self->IsDeeply(
    $AllOptions{$Option{Name}}->{Setting},
    $Option{Setting},
    'OptionGetAll() - option match',
);

my $Exists = $SysConfigObject->Exists(
    Name => $Random.'Hash',
);

$Self->True(
    $Exists,
    'Exists()',
);

my %AllValues = $SysConfigObject->ValueGetAll();

$Self->True(
    IsHashRefWithData(\%AllOptions),
    'ValueGetAll()',
);

$Self->Is(
    $AllValues{$Option{Name}},
    $Option{Value},
    'OptionGetAll() - option match',
);

# update option - change description and setting
$Result = $SysConfigObject->OptionUpdate(
    %Option,
    Description => 'some other description',
    Setting     => {
        "SomeUpdateKey" => "some Value",
        "SourceName" => "Parent",
        "TargetName" => "Child"
    },
    UserID      => 1
);

$Self->True(
    $Result,
    'OptionUpdate() - change description and setting',
);

my %UpdatedOption = $SysConfigObject->OptionGet(
    Name => $Random.'Hash',
);

$Self->Is(
    $UpdatedOption{Description},
    'some other description',
    'OptionGet() - updated description',
);

$Self->IsDeeply(
    $UpdatedOption{Setting},
    {
        "SomeUpdateKey" => "some Value",
        "SourceName" => "Parent",
        "TargetName" => "Child"
    },
    'OptionGet() - updated setting',
);

# update option - change value
$Result = $SysConfigObject->OptionUpdate(
    %Option,
    Description => 'some other description',
    Value  => {
        "SourceName" => "Parent",
        "TargetName" => "Child"
    },
    UserID      => 1
);

$Self->True(
    $Result,
    'OptionUpdate() - change value',
);

my %UpdatedOption = $SysConfigObject->OptionGet(
    Name => $Random.'Hash',
);

$Self->Is(
    $UpdatedOption{Description},
    'some other description',
    'OptionGet() - updated value',
);

$Self->IsDeeply(
    $UpdatedOption{Value},
    {
        "SourceName" => "Parent",
        "TargetName" => "Child"
    },
    'OptionGet() - updated value',
);

# update option - set to invalid
$Result = $SysConfigObject->OptionUpdate(
    %Option,
    ValidID => 2,   # invalid
    UserID  => 1
);

$Self->True(
    $Result,
    'OptionUpdate() - set to invalid',
);

# check if invalid values will be returned
%AllValues = $SysConfigObject->ValueGetAll(Valid => 1);

$Self->False(
    exists $AllValues{$Option{Name}},
    'ValueAllGet() - invalid option',
);

$Result = $SysConfigObject->ValueSet(
    Name   => $Random.'String',
    Value  => 'test123',
    UserID => 1
);

$Self->True(
    $Result,
    'ValueSet()',
);

%UpdatedOption = $SysConfigObject->OptionGet(
    Name => $Random.'String',
);

$Self->Is(
    $UpdatedOption{Value},
    'test123',
    'OptionGet() - after value set',
);

my $Value = $SysConfigObject->ValueGet(
    Name => $Random.'String',
);

$Self->Is(
    $Value,
    'test123',
    'ValueGet() - after value set',
);

%AllValues = $SysConfigObject->ValueGetAll();

$Self->True(
    IsHashRefWithData(\%AllOptions),
    'ValueGetAll() - after value set',
);

$Self->Is(
    $AllValues{$Random.'String'},
    'test123',
    'ValueGetAll() - option value after value set',
);

$Result = $SysConfigObject->OptionDelete(
    Name   => $Random.'Hash',
    UserID => 1,
);

$Self->True(
    $Result,
    'OptionDelete()',
);

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
