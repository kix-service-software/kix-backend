# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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
    Title          => 'AssembleObject test ticket',
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

# create macro
my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'AssembleObject - Macro',
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
    Type       => 'AssembleObject',
    Parameters => {
        Type       => 'JSON',
        Definition => '{}',
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionID,
    'MacroActionAdd',
);

# update macro - set ExecOrder
my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
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
        Name  => 'JSON - Title as String',
        Input => {
            Type       => 'JSON',
            Definition => '"<KIX_TICKET_Title>"',
        },
        Result => 'AssembleObject test ticket',
    },
    {
        Name  => 'YAML - Title as String',
        Input => {
            Type       => 'YAML',
            Definition => '---
<KIX_TICKET_Title>',
        },
        Result => 'AssembleObject test ticket',
    },
    {
        Name  => 'JSON - Data structure',
        Input => {
            Type       => 'JSON',
            Definition => <<'END',
{
    "TicketID": "<KIX_TICKET_TicketID>",
    "Title": "<KIX_TICKET_Title>",
    "Ticket": {
        "Queue": "<KIX_TICKET_Queue>",
        "Priority": "<KIX_TICKET_Priority>",
        "State": "<KIX_TICKET_State>"
    },
    "Customer": {
        "CustomerUser": "<KIX_CONTACT_Firstname> <KIX_CONTACT_Lastname>"
    }
}
END
        },
        Result => {
            TicketID => $TicketID,
            Title    => 'AssembleObject test ticket',
            Ticket   => {
                Queue    => 'Junk',
                Priority => '3 normal',
                State    => 'closed',
            },
            Customer => {
                CustomerUser => $CustomerContact{Firstname} . ' ' . $CustomerContact{Lastname},
            },
        },
    },
    {
        Name  => 'YAML - Data structure',
        Input => {
            Type       => 'YAML',
            Definition => <<'END',
TicketID: "<KIX_TICKET_TicketID>"
Title: "<KIX_TICKET_Title>"
Ticket:
    Queue: "<KIX_TICKET_Queue>"
    Priority: "<KIX_TICKET_Priority>"
    State: "<KIX_TICKET_State>"
Customer:
    CustomerUser: "<KIX_CONTACT_Firstname> <KIX_CONTACT_Lastname>"
END
        },
        Result => {
            TicketID => $TicketID,
            Title    => 'AssembleObject test ticket',
            Ticket   => {
                Queue    => 'Junk',
                Priority => '3 normal',
                State    => 'closed',
            },
            Customer => {
                CustomerUser => $CustomerContact{Firstname} . ' ' . $CustomerContact{Lastname},
            },
        },
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
        ID      => $MacroActionID,
        Parameters => {
            %{ $Test->{Input} },
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

    $Self->IsDeeply(
        $Kernel::OM->Get('Automation')->{MacroResults}->{Object}->{Object},
        $Test->{Result},
        $Test->{Name} . ': MacroExecute - macro result "Object.Object"',
    );

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
