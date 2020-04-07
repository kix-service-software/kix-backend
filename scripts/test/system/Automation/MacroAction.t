# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get MacroAction object
my $AutomationObject = $Kernel::OM->Get('Automation');

#
# MacroAction tests
#

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $NameRandom  = $Helper->GetRandomID();
my %MacroActionIDByMacroActionType = (
    'test-macroaction-' . $NameRandom . '-1' => {
        Type => 'TitleSet',
        Parameters => {
            Title => 'test',
        }
    },
    'test-macroaction-' . $NameRandom . '-2' => {
        Type => 'StateSet',
        Parameters => {
            State => 'open',
        }
    },
    'test-macroaction-' . $NameRandom . '-3' => {
        Type => 'PrioritySet',
        Parameters => {
            Priority => '3 normal'
        }
    },
);

# create macro
my $MacroID = $AutomationObject->MacroAdd(
    Name    => 'test-macro-' . $NameRandom,
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroID,
    'MacroAdd() for new macro.',
);

# try to add macroactions
for my $MacroActionType ( sort keys %MacroActionIDByMacroActionType ) {
    my $MacroActionID = $AutomationObject->MacroActionAdd(
        MacroID => $MacroID,
        Type    => $MacroActionIDByMacroActionType{$MacroActionType}->{Type},
        Parameters => $MacroActionIDByMacroActionType{$MacroActionType}->{Parameters},
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $MacroActionID,
        'MacroActionAdd() for new macro action ' . $MacroActionType,
    );

    if ($MacroActionID) {
        $MacroActionIDByMacroActionType{$MacroActionType}->{ID} = $MacroActionID;
    }
}

# try to fetch data of existing MacroActions
for my $MacroActionType ( sort keys %MacroActionIDByMacroActionType ) {
    my $MacroActionID = $MacroActionIDByMacroActionType{$MacroActionType}->{ID};
    my %MacroAction = $AutomationObject->MacroActionGet( ID => $MacroActionID );

    $Self->Is(
        $MacroAction{Type},
        $MacroActionType,
        'MacroActionGet() for macro action ' . $MacroActionType,
    );
}

# list MacroActions
my %MacroActions = $AutomationObject->MacroActionList(
    MacroID => $MacroID
);
for my $MacroActionType ( sort keys %MacroActionIDByMacroActionType ) {
    my $MacroActionID = $MacroActionIDByMacroActionType{$MacroActionType}->{ID};

    $Self->True(
        exists $MacroActions{$MacroActionID} && $MacroActions{$MacroActionID} eq $MacroActionType,
        'MacroActionList() contains macro action ' . $MacroActionType . ' with ID ' . $MacroActionID,
    );
}

# change type of a single MacroAction
my $MacroActionTypeToChange = 'test-macroaction-' . $NameRandom . '-1';
my $ChangedMacroActionType  = $MacroActionTypeToChange . '-changed';
my $MacroActionIDToChange   = $MacroActionIDByMacroActionType{$MacroActionTypeToChange}->{ID};

my $MacroActionUpdateResult = $AutomationObject->MacroActionUpdate(
    ID      => $MacroActionIDToChange,
    Type    => '',
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroActionUpdateResult,
    'MacroActionUpdate() for changing type of macro action ' . $MacroActionTypeToChange . ' to ' . $ChangedMacroActionType,
);

# update parameters of a single MacroAction
$MacroActionUpdateResult = $AutomationObject->MacroActionUpdate(
    ID      => $MacroActionIDToChange,
    Type    => $ChangedMacroActionType,
    Parameters => {
        Test => 123
    },
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroActionUpdateResult,
    'MacroActionUpdate() for changing parameters of macro action.',
);

my %MacroAction = $AutomationObject->MacroActionGet( ID => $MacroActionIDToChange );

$Self->True(
    $MacroAction{Parameters},
    'MacroActionGet() for macro action with parameters.',
);

$MacroActionIDByMacroActionType{$ChangedMacroActionType} = $MacroActionIDToChange;
delete $MacroActionIDByMacroActionType{$MacroActionTypeToChange};

# try to add macro action with previous type
my $MacroActionID1 = $AutomationObject->MacroActionAdd(
    MacroID => $MacroID,
    Type    => $MacroActionTypeToChange,
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroActionID1,
    'MacroActionAdd() for new macro action ' . $MacroActionTypeToChange,
);

if ($MacroActionID1) {
    $MacroActionIDByMacroActionType{$MacroActionTypeToChange} = $MacroActionID1;
}

my $MacroActionType2 = $ChangedMacroActionType . 'update';
my $MacroActionID2   = $AutomationObject->MacroActionAdd(
    MacroID => $MacroID,
    Type    => $MacroActionType2,
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $MacroActionID2,
    'MacroActionAdd() add the second test macro action ' . $MacroActionType2,
);

# delete an existing macroaction
my $MacroActionDelete = $AutomationObject->MacroActionDelete(
    ID      => $MacroActionIDToChange,
    UserID  => 1,
);

$Self->True(
    $MacroActionDelete,
    'MacroActionDelete() delete existing macroaction',
);

# delete a non existent macroaction
$MacroActionDelete = $AutomationObject->MacroActionDelete(
    ID      => 9999,
    UserID  => 1,
);

$Self->False(
    $MacroActionDelete,
    'MacroActionDelete() delete non existent macroaction',
);

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
