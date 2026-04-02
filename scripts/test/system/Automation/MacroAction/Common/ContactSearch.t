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
## get DF Source
my $DynamicField = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
    Name => 'Source',
);
$Self->True(
    $DynamicField,
    'Check - DynamicFieldGet - Source',
);
## first contact including user
my $ContactUserID1 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin    => 'test',
    ValidID      => 1,
    ChangeUserID => 1,
    IsCustomer   => 1,
);
$Self->True(
    $ContactUserID1,
    'Init - UserAdd - 1',
);
my $ContactID1 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname      => 'Testname',
    Lastname       => 'Junk',
    Email          => 'email1@example.com',
    ValidID        => 2,
    AssignedUserID => $ContactUserID1,
    UserID         => 1,
);
$Self->True(
    $ContactID1,
    'Init - ContactAdd - 1',
);
my $DFValueSet1 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicField,
    ObjectID           => $ContactID1,
    Value              => 'Junk',
    UserID             => 1,
);
$Self->True(
    $DFValueSet1,
    'Init - ValueSet - 1',
);

## second contact without user
my $ContactID2 = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname      => 'Testname',
    Lastname       => 'Junk',
    Email          => 'email2@example.com',
    ValidID        => 1,
    UserID         => 1,
);
$Self->True(
    $ContactID2,
    'Init - ContactAdd - 2',
);
my $DFValueSet2 = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
    DynamicFieldConfig => $DynamicField,
    ObjectID           => $ContactID2,
    Value              => 'Junk',
    UserID             => 1,
);
$Self->True(
    $DFValueSet1,
    'Init - ValueSet - 2',
);

# ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Test',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    ContactID      => $ContactID1,
    OwnerID        => 1,
    UserID         => 1,
);
$Self->True(
    $TicketID,
    'Init - TicketCreate',
);

# create macro
my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
    Name    => 'ContactSearch - Check Macro',
    Type    => 'Ticket',
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $MacroID,
    'Init - MacroAdd',
);
my $MacroActionID = $Kernel::OM->Get('Automation')->MacroActionAdd(
    MacroID    => $MacroID,
    Type       => 'ContactSearch',
    Parameters => {
        Attribute => '<KIX_TICKET_Title>*',
        Pattern   => 'Firstname',
    },
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $MacroActionID,
    'Init - MacroActionAdd',
);
my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
    ID        => $MacroID,
    ExecOrder => [ $MacroActionID ],
    UserID    => 1,
);
$Self->True(
    $Success,
    'Init - MacroUpdate - ExecOrder',
);

my @Tests = (
    {
        Name       => 'ContactSearch - Firstname =~ "<KIX_TICKET_Title>*"',
        Parameters => {
            Attribute => 'Firstname',
            Pattern   => '<KIX_TICKET_Title>*'
        },
        Result     => {
            ResultContactID => $ContactID1,
            ResultUserID    => $ContactUserID1,
        },
    },
    {
        Name       => 'ContactSearch - Lastname =~ "<KIX_TICKET_Queue>"',
        Parameters => {
            Attribute => 'Lastname',
            Pattern   => '<KIX_TICKET_Queue>'
        },
        Result     => {
            ResultContactID => $ContactID1,
            ResultUserID    => $ContactUserID1,
        },
    },
    {
        Name       => 'ContactSearch - DynamicField_Source =~ "<KIX_CONTACT_Lastname>"',
        Parameters => {
            Attribute => 'DynamicField_Source',
            Pattern   => '<KIX_CONTACT_Lastname>'
        },
        Result     => {
            ResultContactID => $ContactID1,
            ResultUserID    => $ContactUserID1,
        },
    },
    {
        Name       => 'ContactSearch - Firstname =~ "<KIX_TICKET_Title>*" - OnlyValid',
        Parameters => {
            Attribute => 'Firstname',
            Pattern   => '<KIX_TICKET_Title>*',
            OnlyValid => 1
        },
        Result     => {
            ResultContactID => $ContactID2,
            ResultUserID    => undef,
        },
    },
    {
        Name       => 'ContactSearch - Lastname =~ "<KIX_TICKET_Queue>" - OnlyValid',
        Parameters => {
            Attribute => 'Lastname',
            Pattern   => '<KIX_TICKET_Queue>',
            OnlyValid => 1
        },
        Result     => {
            ResultContactID => $ContactID2,
            ResultUserID    => undef,
        },
    },
    {
        Name       => 'ContactSearch - DynamicField_Source =~ "<KIX_CONTACT_Lastname>" - OnlyValid',
        Parameters => {
            Attribute => 'DynamicField_Source',
            Pattern   => '<KIX_CONTACT_Lastname>',
            OnlyValid => 1
        },
        Result     => {
            ResultContactID => $ContactID2,
            ResultUserID    => undef,
        },
    }
);

for my $Test ( @Tests ) {
    # update parameters of MacroAction
    $Success = $Kernel::OM->Get('Automation')->MacroActionUpdate(
        ID         => $MacroActionID,
        Parameters => $Test->{Parameters},
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
    $Self->IsDeeply(
        $Kernel::OM->Get('Automation')->{MacroVariables}->{ResultContactID},
        $Test->{Result}->{ResultContactID},
        $Test->{Name} . ': MacroExecute - macro variable "ResultContactID" of check macro',
    );
    $Self->IsDeeply(
        $Kernel::OM->Get('Automation')->{MacroVariables}->{ResultUserID},
        $Test->{Result}->{ResultUserID},
        $Test->{Name} . ': MacroExecute - macro variable "ResultUserID" of check macro',
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
