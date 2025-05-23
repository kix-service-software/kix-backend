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

# get type object
my $TypeObject = $Kernel::OM->Get('Type');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# add type
my $TypeName = 'Type' . $Helper->GetRandomID();

my $TypeID = $TypeObject->TypeAdd(
    Name    => $TypeName,
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $TypeID,
    'TypeAdd()',
);

# add type with existing name
my $TypeIDWrong = $TypeObject->TypeAdd(
    Name    => $TypeName,
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);

$Self->False(
    $TypeIDWrong,
    'TypeAdd( - Try to add type with existing name',
);

# get the type by using the type id
my %Type = $TypeObject->TypeGet( ID => $TypeID );

$Self->Is(
    $Type{Name} || '',
    $TypeName,
    'TypeGet() - Name (using the type id)',
);
$Self->Is(
    $Type{ValidID} || '',
    1,
    'TypeGet() - ValidID',
);

# get the type by using the type name
%Type = $TypeObject->TypeGet( Name => $TypeName );

$Self->Is(
    $Type{Name} || '',
    $TypeName,
    'TypeGet() - Name (using the type name)',
);

my %TypeList = $TypeObject->TypeList();

$Self->True(
    exists $TypeList{$TypeID} && $TypeList{$TypeID} eq $TypeName,
    'TypeList() contains the type ' . $TypeName . ' with ID ' . $TypeID,
);

my $TypeUpdateName = $TypeName . 'update';
my $TypeUpdate     = $TypeObject->TypeUpdate(
    ID      => $TypeID,
    Name    => $TypeUpdateName,
    ValidID => 2,
    UserID  => 1,
);

$Self->True(
    $TypeUpdate,
    'TypeUpdate()',
);

%Type = $TypeObject->TypeGet( ID => $TypeID );

$Self->Is(
    $Type{Name} || '',
    $TypeUpdateName,
    'TypeGet() - Name',
);

$Self->Is(
    $Type{ValidID} || '',
    2,
    'TypeGet() - ValidID',
);

my $TypeLookup = $TypeObject->TypeLookup( TypeID => $TypeID );

$Self->Is(
    $TypeLookup || '',
    $TypeUpdateName,
    'TypeLookup() - TypeID',
);

my $TypeIDLookup = $TypeObject->TypeLookup( Type => $TypeLookup );

$Self->Is(
    $TypeIDLookup || '',
    $TypeID,
    'TypeLookup() - Type',
);

# add another type
my $TypeSecondName = $TypeName . 'second';
my $TypeIDSecond   = $TypeObject->TypeAdd(
    Name    => $TypeSecondName,
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $TypeIDSecond,
    "TypeAdd() - Name: \'$TypeSecondName\' ID: \'$TypeIDSecond\'",
);

# update with existing name
my $TypeUpdateWrong = $TypeObject->TypeUpdate(
    ID      => $TypeIDSecond,
    Name    => $TypeUpdateName,
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);

$Self->False(
    $TypeUpdateWrong,
    "TypeUpdate() - Try to update the type with existing name",
);

# check function NameExistsCheck()
# check does it exist a type with certain Name or
# check is it possible to set Name for type with certain ID
my $Exist = $TypeObject->NameExistsCheck(
    Name => $TypeSecondName,
);
$Self->True(
    $Exist,
    "NameExistsCheck() - A type with \'$TypeSecondName\' already exists!",
);

# there is a type with certain name, now check if there is another one
$Exist = $TypeObject->NameExistsCheck(
    Name => $TypeSecondName,
    ID   => $TypeIDSecond,
);
$Self->False(
    $Exist,
    "NameExistsCheck() - Another type \'$TypeSecondName\' for ID=$TypeIDSecond does not exists!",
);
$Exist = $TypeObject->NameExistsCheck(
    Name => $TypeSecondName,
    ID   => $TypeID,
);
$Self->True(
    $Exist,
    "NameExistsCheck() - Another type \'$TypeSecondName\' for ID=$TypeID already exists!",
);

# check is there a type whose name has been updated in the meantime
$Exist = $TypeObject->NameExistsCheck(
    Name => $TypeName,
);
$Self->False(
    $Exist,
    "NameExistsCheck() - A type with \'$TypeName\' does not exists!",
);
$Exist = $TypeObject->NameExistsCheck(
    Name => $TypeName,
    ID   => $TypeID,
);
$Self->False(
    $Exist,
    "NameExistsCheck() - Another type \'$TypeName\' for ID=$TypeID does not exists!",
);

# set Ticket::Type::Default config item
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::Type::Default',
    Value => $TypeSecondName,
);

# update the default ticket type
$TypeUpdateWrong = $TypeObject->TypeUpdate(
    ID      => $TypeIDSecond,
    Name    => $TypeSecondName,
    ValidID => 2,
    UserID  => 1,
    Silent  => 1,
);

$Self->False(
    $TypeUpdateWrong,
    "The ticket type is set as a default ticket type, so it cannot be changed! - $TypeSecondName",
);

# get all types
my %TypeListAll = $TypeObject->TypeList( Valid => 0 );
$Self->True(
    exists $TypeListAll{$TypeID} && $TypeListAll{$TypeID} eq $TypeUpdateName,
    'TypeList() contains the type ' . $TypeUpdateName . ' with ID ' . $TypeID,
);

# get valid types
my %TypeListValid = $TypeObject->TypeList( Valid => 1 );
$Self->False(
    exists $TypeListValid{$TypeID},
    'TypeList() does not contain the type ' . $TypeUpdateName . ' with ID ' . $TypeID,
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
