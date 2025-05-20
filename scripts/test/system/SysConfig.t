# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));
use File::Basename;

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $SysConfigModule = 'Kernel::System::SysConfig';

# create backend object
my $SysConfigObject = $SysConfigModule->new( %{ $Self } );
$Self->Is(
    ref( $SysConfigObject ),
    $SysConfigModule,
    'SysConfig object has correct module ref'
);

# check supported methods
for my $Method (
    qw(
        OptionTypeList Exists OptionLookup
        OptionGet OptionGetAll OptionAdd
        OptionUpdate OptionList OptionDelete
        ValueGet ValueGetAll ValueSet
        CleanUp Rebuild
    )
) {
    $Self->True(
        $SysConfigObject->can($Method),
        'SysConfig object can "' . $Method . q{"}
    );
}

# begin transaction on database
$Helper->BeginWork();

# ToDo: Revision necessary, as not all functions are covered and only simple

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

%UpdatedOption = $SysConfigObject->OptionGet(
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

# Special handling of the ObjectGet
# if the database table "sysconfig" has different columns

# set fixed time to have predetermined verifiable results
my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
    String => '2025-01-01 12:00:00',
);
$Helper->FixedTimeSet($SystemTime);

# get xml files
my %XMLs;
my $Home = $Kernel::OM->Get('Config')->Get('Home');

my @XMLFiles = $Kernel::OM->Get('Main')->DirectoryRead(
    Directory => $Home . '/scripts/test/system/sample/SysConfig',
    Filter    => '*.xml',
);

foreach my $Filename ( @XMLFiles ) {
    my $XMLName = basename($Filename, '.xml');
    my $Content = $Kernel::OM->Get('Main')->FileRead(
        Location => $Filename,
        Result   => 'SCALAR',
        Mode     => 'utf8'
    );
    $Self->True(
        $Content,
        "Loaded xml content ".$XMLName
    );
    $XMLs{$XMLName} = ${$Content};
}

# Add new Option
my $Option = 'Option' . $Helper->GetRandomID();
$Result = $SysConfigObject->OptionAdd(
    Name        => $Option,
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
    "OptionAdd | $Option | Type: String | Result true"
);

# OptionLookup for ID
my $OptionID = $SysConfigObject->OptionLookup(
    Name  => $Option
);

$Self->True(
    $OptionID,
    "OptionLookup | $Option | Pre | Result ID"
);

# Check current table configuration on ObjectGet
my %Object = $SysConfigObject->OptionGet(
    Name => $Option
);

$Self->IsDeeply(
    \%Object,
    {
        'AccessLevel'     => 'internal',
        'ChangeBy'        => 1,
        'ChangeTime'      => '2025-01-01 12:00:00',
        'Comment'         => undef,
        'Context'         => undef,
        'ContextMetadata' => undef,
        'CreateBy'        => 1,
        'CreateTime'      => '2025-01-01 12:00:00',
        'Default'         => q{},
        'DefaultValidID'  => 1,
        'Description'     => 'some description',
        'ExperienceLevel' => undef,
        'Group'           => undef,
        'ID'              => $OptionID,
        'IsModified'      => 0,
        'IsRequired'      => 0,
        'Name'            => $Option,
        'Setting'         => {
            'RegEx' => q{}
        },
        'Type'            => 'String',
        'ValidID'         => 1,
        'Value'           => q{}
    },
    "OptionGet | $Option | Type: String | Result hash with ID"
);

# drop column id in the table configuration
$Result = _ExecuteXML(
    XML => $XMLs{DropIDColumn}
);

$Self->True(
    $Result,
    "DB-Table Change | Drop Column ID from sysconfig| Result true"
);

# cleanup cache
$Kernel::OM->Get('Cache')->CleanUp(
    Type => 'SysConfig'
);

# Check new table configuration on ObjectGet
%Object = $SysConfigObject->OptionGet(
    Name => $Option
);

$Self->IsDeeply(
    \%Object,
    {
        'AccessLevel'     => 'internal',
        'ChangeBy'        => 1,
        'ChangeTime'      => '2025-01-01 12:00:00',
        'Comment'         => undef,
        'Context'         => undef,
        'ContextMetadata' => undef,
        'CreateBy'        => 1,
        'CreateTime'      => '2025-01-01 12:00:00',
        'Default'         => q{},
        'DefaultValidID'  => 1,
        'Description'     => 'some description',
        'ExperienceLevel' => undef,
        'Group'           => undef,
        'IsModified'      => 0,
        'IsRequired'      => 0,
        'Name'            => $Option,
        'Setting'         => {
            'RegEx' => q{}
        },
        'Type'            => 'String',
        'ValidID'         => 1,
        'Value'           => q{}
    },
    "OptionGet | $Option | Type: String | Result hash without ID"
);

# revert pre changes of the table configuration
$Result = _ExecuteXML(
    XML => $XMLs{RevertDropIDColumn}
);

$Self->True(
    $Result,
    "DB-Table Change | Revert Drop Column ID from sysconfig| Result true"
);

# cleanup cache
$Kernel::OM->Get('Cache')->CleanUp(
    Type => 'SysConfig'
);


# Post OptionLookup for ID
$OptionID = $SysConfigObject->OptionLookup(
    Name  => $Option
);

$Self->True(
    $OptionID,
    "OptionLookup | $Option | Post | Result ID"
);

# Post check of the reverted table configuration on ObjectGet
%Object = $SysConfigObject->OptionGet(
    Name => $Option
);

$Self->IsDeeply(
    \%Object,
    {
        'AccessLevel'     => 'internal',
        'ChangeBy'        => 1,
        'ChangeTime'      => '2025-01-01 12:00:00',
        'Comment'         => undef,
        'Context'         => undef,
        'ContextMetadata' => undef,
        'CreateBy'        => 1,
        'CreateTime'      => '2025-01-01 12:00:00',
        'Default'         => q{},
        'DefaultValidID'  => 1,
        'Description'     => 'some description',
        'ExperienceLevel' => undef,
        'Group'           => undef,
        'ID'              => $OptionID,
        'IsModified'      => 0,
        'IsRequired'      => 0,
        'Name'            => $Option,
        'Setting'         => {
            'RegEx' => q{}
        },
        'Type'            => 'String',
        'ValidID'         => 1,
        'Value'           => q{}
    },
    "OptionGet | $Option | Type: String | Result hash without ID"
);

sub _ExecuteXML {
    my ( %Param ) = @_;

    return 0 if !$Param{XML};

    my @XMLArray = $Kernel::OM->Get('XML')->XMLParse(
        String => $Param{XML}
    );
    my @SQL = $Kernel::OM->Get('DB')->SQLProcessor(
        Database => \@XMLArray,
    );

    return 0 if !@SQL;

    for my $SQL (@SQL) {
        my $Success = $Kernel::OM->Get('DB')->Do( SQL => $SQL );
        return 0 if !$Success;
    }

    return 1;
}

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
