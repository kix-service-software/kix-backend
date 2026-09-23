# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
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
    Title          => 'TitleSet test ticket',
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
    Name    => 'TitleSet - Macro',
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
    Type       => 'TitleSet',
    Parameters => {
        Title => 'Title',
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
        Name  => 'Static title',
        Input => {
            Title => 'Test',
        },
        Result => 'Test',
    },
    {
        Name  => 'Not translated placeholder',
        Input => {
            Title => '<KIX_TICKET_Type!>',
        },
        Result => 'Unclassified',
    },
    {
        Name  => 'Translated placeholder',
        Input => {
            Title => '<KIX_TICKET_Type>',
        },
        Result => 'Unklassifiziert',
    }
);

for my $Test ( @Tests ) {
    # update parameters of MacroAction
    $Success = $Kernel::OM->Get('Automation')->MacroActionUpdate(
        ID         => $MacroActionID,
        Parameters => {
            %{ $Test->{Input} },
        },
        UserID     => 1,
        ValidID    => 1,
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

    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 0,
        UserID        => 1,
    );
    $Self->IsDeeply(
        $Ticket{Title},
        $Test->{Result},
        $Test->{Name} . ': MacroExecute - ticket title',
    );
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
