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

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# some preparations
# create customer user
my $ContactID = $Helper->TestContactCreate();
$Self->True(
    $ContactID,
    'ContactCreate',
);
my %CustomerContact = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID,
);

# create ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Conditional test ticket',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => $CustomerContact{PrimaryOrganisationID},
    ContactID      => $ContactID,
    OwnerID        => 1,
    UserID         => 1,
);
$Self->True(
    $TicketID,
    'TicketCreate',
);

# create check macro
my $MacroIDCheck = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'Conditional - Check Macro',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroIDCheck,
    'Check MacroAdd',
);

# create macro action
my $MacroActionIDCheck = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroIDCheck,
    Type       => 'AssembleObject',
    Parameters => {
        Type       => 'JSON',
        Definition => '"True"',
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionIDCheck,
    'Check MacroActionAdd',
);

# update macro - set ExecOrder
my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroIDCheck,
    ExecOrder => [ $MacroActionIDCheck ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'Check MacroUpdate - ExecOrder',
);

# create false check macro
my $MacroIDFalseCheck = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'Conditional - FalseCheck Macro',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroIDFalseCheck,
    'FalseCheck MacroAdd',
);

# create macro action
my $MacroActionIDFalseCheck = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroIDFalseCheck,
    Type       => 'AssembleObject',
    Parameters => {
        Type       => 'JSON',
        Definition => '"False"',
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionIDFalseCheck,
    'FalseCheck MacroActionAdd',
);

# update macro - set ExecOrder
my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroIDFalseCheck,
    ExecOrder => [ $MacroActionIDFalseCheck ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'FalseCheck MacroUpdate - ExecOrder',
);

# create macro
my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'Conditional - Macro',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroID,
    'MacroAdd',
);

# create macro action
my $MacroActionID = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroID,
    Type       => 'Conditional',
    Parameters => {
        If          => '<KIX_TICKET_TicketID> == ' . $TicketID,
        MacroID     => $MacroIDCheck,
        ElseMacroID => $MacroIDFalseCheck,
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionID,
    'MacroActionAdd',
);

# update macro - set ExecOrder
$Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroID,
    ExecOrder => [ $MacroActionID ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'MacroUpdate - ExecOrder',
);

my @Tests = (
    {
        Name   => 'Check TicketID',
        If     => '<KIX_TICKET_TicketID> == ' . $TicketID,
        Result => 'True',
    },
    {
        Name   => 'Negative check TicketID',
        If     => '<KIX_TICKET_TicketID> != ' . $TicketID,
        Result => 'False',
    },
    {
        Name   => 'Check TicketID AND Title',
        If     => '<KIX_TICKET_TicketID> == ' . $TicketID . ' && "<KIX_TICKET_Title>" eq "Conditional test ticket"',
        Result => 'True',
    },
    {
        Name   => 'Negative check TicketID AND Title (TicketID missmatch)',
        If     => '<KIX_TICKET_TicketID> != ' . $TicketID . ' && "<KIX_TICKET_Title>" eq "Conditional test ticket"',
        Result => 'False',
    },
    {
        Name   => 'Negative check TicketID AND Title (Title missmatch)',
        If     => '<KIX_TICKET_TicketID> == ' . $TicketID . ' && "<KIX_TICKET_Title>" ne "Conditional test ticket"',
        Result => 'False',
    },
    {
        Name   => 'Negative check TicketID AND Title (both missmatch)',
        If     => '<KIX_TICKET_TicketID> != ' . $TicketID . ' && "<KIX_TICKET_Title>" ne "Conditional test ticket"',
        Result => 'False',
    },
    {
        Name   => 'Check TicketID OR Title',
        If     => '<KIX_TICKET_TicketID> == ' . $TicketID . ' || "<KIX_TICKET_Title>" eq "Conditional test ticket"',
        Result => 'True',
    },
    {
        Name   => 'Check TicketID OR Title (TicketID missmatch)',
        If     => '<KIX_TICKET_TicketID> != ' . $TicketID . ' || "<KIX_TICKET_Title>" eq "Conditional test ticket"',
        Result => 'True',
    },
    {
        Name   => 'Check TicketID OR Title (Title missmatch)',
        If     => '<KIX_TICKET_TicketID> == ' . $TicketID . ' || "<KIX_TICKET_Title>" ne "Conditional test ticket"',
        Result => 'True',
    },
    {
        Name   => 'Negative check TicketID OR Title (both missmatch)',
        If     => '<KIX_TICKET_TicketID> != ' . $TicketID . ' || "<KIX_TICKET_Title>" ne "Conditional test ticket"',
        Result => 'False',
    },
    {
        Name   => 'Check ( TicketID OR Title ) AND State',
        If     => '( <KIX_TICKET_TicketID> == ' . $TicketID . ' || "<KIX_TICKET_Title>" eq "Conditional test ticket" ) && "<KIX_TICKET_State>" eq "closed"',
        Result => 'True',
    },
    {
        Name   => 'Check ( TicketID OR Title ) AND State (TicketID missmatch)',
        If     => '( <KIX_TICKET_TicketID> != ' . $TicketID . ' || "<KIX_TICKET_Title>" eq "Conditional test ticket" ) && "<KIX_TICKET_State>" eq "closed"',
        Result => 'True',
    },
    {
        Name   => 'Check ( TicketID OR Title ) AND State (Title missmatch)',
        If     => '( <KIX_TICKET_TicketID> == ' . $TicketID . ' || "<KIX_TICKET_Title>" ne "Conditional test ticket" ) && "<KIX_TICKET_State>" eq "closed"',
        Result => 'True',
    },
    {
        Name   => 'Negative check ( TicketID OR Title ) AND State (State missmatch)',
        If     => '( <KIX_TICKET_TicketID> == ' . $TicketID . ' || "<KIX_TICKET_Title>" eq "Conditional test ticket" ) && "<KIX_TICKET_State>" ne "closed"',
        Result => 'False',
    },
    {
        Name   => 'Negative check ( TicketID OR Title ) AND State (TicketID and Title missmatch)',
        If     => '( <KIX_TICKET_TicketID> != ' . $TicketID . ' || "<KIX_TICKET_Title>" ne "Conditional test ticket" ) && "<KIX_TICKET_State>" eq "closed"',
        Result => 'False',
    },
    {
        Name   => 'Negative check ( TicketID OR Title ) AND State (TicketID and State missmatch)',
        If     => '( <KIX_TICKET_TicketID> != ' . $TicketID . ' || "<KIX_TICKET_Title>" eq "Conditional test ticket" ) && "<KIX_TICKET_State>" ne "closed"',
        Result => 'False',
    },
    {
        Name   => 'Negative check ( TicketID OR Title ) AND State (Title and State missmatch)',
        If     => '( <KIX_TICKET_TicketID> == ' . $TicketID . ' || "<KIX_TICKET_Title>" ne "Conditional test ticket" ) && "<KIX_TICKET_State>" ne "closed"',
        Result => 'False',
    },
    {
        Name   => 'Negative check ( TicketID OR Title ) AND State (All missmatch)',
        If     => '( <KIX_TICKET_TicketID> != ' . $TicketID . ' || "<KIX_TICKET_Title>" ne "Conditional test ticket" ) && "<KIX_TICKET_State>" ne "closed"',
        Result => 'False',
    },
    {
        Name   => 'Check ( TicketID AND Title ) OR State',
        If     => '( <KIX_TICKET_TicketID> == ' . $TicketID . ' && "<KIX_TICKET_Title>" eq "Conditional test ticket" ) || "<KIX_TICKET_State>" eq "closed"',
        Result => 'True',
    },
    {
        Name   => 'Check ( TicketID AND Title ) OR State (TicketID missmatch)',
        If     => '( <KIX_TICKET_TicketID> != ' . $TicketID . ' && "<KIX_TICKET_Title>" eq "Conditional test ticket" ) || "<KIX_TICKET_State>" eq "closed"',
        Result => 'True',
    },
    {
        Name   => 'Check ( TicketID AND Title ) OR State (Title missmatch)',
        If     => '( <KIX_TICKET_TicketID> == ' . $TicketID . ' && "<KIX_TICKET_Title>" ne "Conditional test ticket" ) || "<KIX_TICKET_State>" eq "closed"',
        Result => 'True',
    },
    {
        Name   => 'Check ( TicketID AND Title ) OR State (State missmatch)',
        If     => '( <KIX_TICKET_TicketID> == ' . $TicketID . ' && "<KIX_TICKET_Title>" eq "Conditional test ticket" ) || "<KIX_TICKET_State>" ne "closed"',
        Result => 'True',
    },
    {
        Name   => 'Check ( TicketID AND Title ) OR State (TicketID and Title missmatch)',
        If     => '( <KIX_TICKET_TicketID> != ' . $TicketID . ' && "<KIX_TICKET_Title>" ne "Conditional test ticket" ) || "<KIX_TICKET_State>" eq "closed"',
        Result => 'True',
    },
    {
        Name   => 'Negative check ( TicketID AND Title ) OR State (TicketID and State missmatch)',
        If     => '( <KIX_TICKET_TicketID> != ' . $TicketID . ' && "<KIX_TICKET_Title>" eq "Conditional test ticket" ) || "<KIX_TICKET_State>" ne "closed"',
        Result => 'False',
    },
    {
        Name   => 'Negative check ( TicketID AND Title ) OR State (Title and State missmatch)',
        If     => '( <KIX_TICKET_TicketID> == ' . $TicketID . ' && "<KIX_TICKET_Title>" ne "Conditional test ticket" ) || "<KIX_TICKET_State>" ne "closed"',
        Result => 'False',
    },
    {
        Name   => 'Negative check ( TicketID AND Title ) OR State (All missmatch)',
        If     => '( <KIX_TICKET_TicketID> != ' . $TicketID . ' && "<KIX_TICKET_Title>" ne "Conditional test ticket" ) || "<KIX_TICKET_State>" ne "closed"',
        Result => 'False',
    },
);

for my $Test ( @Tests ) {
    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeSet(
            $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                String => $Test->{FixedTimeSet},
            ),
        );
    }

    # update parameters of MacroAction
    $Success = $Kernel::OM->Get('Automation')->MacroActionUpdate(
        ID         => $MacroActionID,
        Parameters => {
            If          => $Test->{If},
            MacroID     => $MacroIDCheck,
            ElseMacroID => $MacroIDFalseCheck,
        },
        UserID  => 1,
        ValidID => 1,
    );
    $Self->True(
        $Success,
        $Test->{Name} . ': MacroActionUpdate',
    );

    # check if placeholder is used
    $Success = $Kernel::OM->Get('Automation')->MacroExecute(
        ID       => $MacroID,
        ObjectID => $TicketID,
        UserID   => 1,
    );
    $Self->True(
        $Success,
        $Test->{Name} . ': MacroExecute',
    );

    if ( ref( $Test->{Result} ) ) {
        $Self->IsDeeply(
            $Kernel::OM->Get('Automation')->{MacroVariables}->{Object}->{Object},
            $Test->{Result},
            $Test->{Name} . ': MacroExecute - macro variable "Object.Object" of check macro',
        );
    }
    else {
        $Self->Is(
            $Kernel::OM->Get('Automation')->{MacroVariables}->{Object}->{Object},
            $Test->{Result},
            $Test->{Name} . ': MacroExecute - macro variable "Object.Object" of check macro',
        );
    }

    if ( $Test->{FixedTimeSet} ) {
        $Helper->FixedTimeUnset();
    }
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
