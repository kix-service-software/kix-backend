# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get Macro object
my $AutomationObject = $Kernel::OM->Get('Automation');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $NameRandom  = $Helper->GetRandomID();
my %MacroIDByMacroName = (
    'test-macro-' . $NameRandom . '-1' => undef,
    'test-macro-' . $NameRandom . '-2' => undef,
    'test-macro-' . $NameRandom . '-3' => undef,
);

# try to add macros
for my $MacroName ( sort keys %MacroIDByMacroName ) {
    my $MacroID = $AutomationObject->MacroAdd(
        Name    => $MacroName,
        Type    => 'Ticket',
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $MacroID,
        'MacroAdd() for new macro ' . $MacroName,
    );

    if ($MacroID) {
        $MacroIDByMacroName{$MacroName} = $MacroID;
    }
}

# try to add already added macros
for my $MacroName ( sort keys %MacroIDByMacroName ) {
    my $MacroID = $AutomationObject->MacroAdd(
        Name    => $MacroName,
        Type    => 'Ticket',
        ValidID => 1,
        UserID  => 1,
        Silent  => 1,
    );

    $Self->False(
        $MacroID,
        'MacroAdd() for already existing Macro ' . $MacroName,
    );
}

# try to fetch data of existing Macros
for my $MacroName ( sort keys %MacroIDByMacroName ) {
    my $MacroID = $MacroIDByMacroName{$MacroName};
    my %Macro = $AutomationObject->MacroGet( ID => $MacroID );

    $Self->Is(
        $Macro{Name},
        $MacroName,
        'MacroGet() for Macro ' . $MacroName,
    );
}

# look up existing Macros
for my $MacroName ( sort keys %MacroIDByMacroName ) {
    my $MacroID = $MacroIDByMacroName{$MacroName};

    my $FetchedMacroID = $AutomationObject->MacroLookup( Name => $MacroName );
    $Self->Is(
        $FetchedMacroID,
        $MacroID,
        'MacroLookup() for macro name ' . $MacroName,
    );

    my $FetchedMacroName = $AutomationObject->MacroLookup( ID => $MacroID );
    $Self->Is(
        $FetchedMacroName,
        $MacroName,
        'MacroLookup() for macro ID ' . $MacroID,
    );
}

# list Macros
my %Macros = $AutomationObject->MacroList();
for my $MacroName ( sort keys %MacroIDByMacroName ) {
    my $MacroID = $MacroIDByMacroName{$MacroName};

    $Self->True(
        exists $Macros{$MacroID} && $Macros{$MacroID} eq $MacroName,
        'MacroList() contains macro ' . $MacroName . ' with ID ' . $MacroID,
    );
}

# change name of a single Macro
my $MacroNameToChange = 'test-macro-' . $NameRandom . '-1';
my $ChangedMacroName  = $MacroNameToChange . '-changed';
my $MacroIDToChange   = $MacroIDByMacroName{$MacroNameToChange};

my $MacroUpdateResult = $AutomationObject->MacroUpdate(
    ID      => $MacroIDToChange,
    Name    => $ChangedMacroName,
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroUpdateResult,
    'MacroUpdate() for changing name of macro ' . $MacroNameToChange . ' to ' . $ChangedMacroName,
);

$MacroIDByMacroName{$ChangedMacroName} = $MacroIDToChange;
delete $MacroIDByMacroName{$MacroNameToChange};

# try to add macro with previous name
my $MacroID1 = $AutomationObject->MacroAdd(
    Name    => $MacroNameToChange,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroID1,
    'MacroAdd() for new macro ' . $MacroNameToChange,
);

if ($MacroID1) {
    $MacroIDByMacroName{$MacroNameToChange} = $MacroID1;
}

# try to add macro with changed name
$MacroID1 = $AutomationObject->MacroAdd(
    Name    => $ChangedMacroName,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
    Silent  => 1,
);

$Self->False(
    $MacroID1,
    'MacroAdd() add macro with existing name ' . $ChangedMacroName,
);

my $MacroName2 = $ChangedMacroName . 'update';
my $MacroID2   = $AutomationObject->MacroAdd(
    Name    => $MacroName2,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroID2,
    'MacroAdd() add the second test macro ' . $MacroName2,
);

# try to update Macro with existing name
my $MacroUpdateWrong = $AutomationObject->MacroUpdate(
    ID      => $MacroID2,
    Name    => $ChangedMacroName,
    ValidID => 2,
    UserID  => 1,
    Silent  => 1,
);

$Self->False(
    $MacroUpdateWrong,
    'MacroUpdate() update macro with existing name ' . $ChangedMacroName,
);

# delete an existing macro
my $MacroDelete = $AutomationObject->MacroDelete(
    ID      => $MacroIDToChange,
    UserID  => 1,
);

$Self->True(
    $MacroDelete,
    'MacroDelete() delete existing macro',
);

# delete a non existent macro
$MacroDelete = $AutomationObject->MacroDelete(
    ID     => 9999,
    UserID => 1,
    Silent => 1,
);

$Self->False(
    $MacroDelete,
    'MacroDelete() delete non existent macro',
);

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
