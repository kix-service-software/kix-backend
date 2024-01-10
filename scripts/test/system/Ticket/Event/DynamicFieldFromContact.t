# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $RandomID = $Helper->GetRandomID();

# don't check email address validity
$Kernel::OM->Get('Config')->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);
$Kernel::OM->Get('Config')->Set(
    Key   => 'DynamicFieldFromContact::Mapping',
    Value => {
        Login     => 'CustomerLogin' . $RandomID,
        Firstname => 'CustomerFirstname' . $RandomID,
        Lastname  => 'CustomerLastname' . $RandomID,
    },
);
$Kernel::OM->Get('Config')->Set(
    Key   => 'Ticket::EventModulePost###950-DynamicFieldFromContact',
    Value => {
        Module => 'Kernel::System::Ticket::Event::DynamicFieldFromContact',
        Event  => '(TicketCreate|TicketCustomerUpdate)',
    },
);

# create the required dynamic fields
my @DynamicFields = (
    {
        Name       => 'CustomerLogin' . $RandomID,
        Label      => 'CustomerLogin',
        FieldOrder => 9991,
    },
    {
        Name       => 'CustomerFirstname' . $RandomID,
        Label      => 'CustomerFirstname',
        FieldOrder => 9992,
    },
    {
        Name       => 'CustomerLastname' . $RandomID,
        Label      => 'CustomerLastname',
        FieldOrder => 9993,
    },
);

my @AddedDynamicFieldNames;
for my $DynamicFieldConfig (@DynamicFields) {

    my $ID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        %{$DynamicFieldConfig},
        Config => {
            DefaultValue => '',
        },
        FieldType     => 'Text',
        ObjectType    => 'Ticket',
        InternalField => 0,
        Reorder       => 0,
        ValidID       => 1,
        UserID        => 1,
    );

    # sanity test
    $Self->IsNot(
        $ID,
        undef,
        "DynamicFieldAdd() for '$DynamicFieldConfig->{Label}' Field ID should be defined",
    );

    # remember the DynamicFieldName
    push @AddedDynamicFieldNames, $DynamicFieldConfig->{Name};
}

# create a customer user
my $TestContactID = $Helper->TestContactCreate();
# get customer user data
my %TestContactData = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $TestContactID,
);

# set customer Firstname and Lastname
$TestContactData{Firstname} = 'FirstName' . $RandomID;
$TestContactData{Lastname}  = 'LastName' . $RandomID;

# update the user manually because First and LastNames are important
$Kernel::OM->Get('Contact')->ContactUpdate(
    %TestContactData,
    Source  => 'Contact',
    ID      => $TestContactID,
    ValidID => 1,
    UserID  => 1,
);

# create a new ticket with the test user information
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Some Ticket Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'new',
    OrganisationID => $TestContactData{PrimaryOrganisationID},
    ContactID      => $TestContactID,
    OwnerID        => 1,
    UserID         => 1,
);

# at this point the information should be already stored in the dynamic fields
# get ticket data (with DynamicFields)
my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
    TicketID      => $TicketID,
    DynamicFields => 1,
    UserID        => 1,
    Silent        => 0,
);

$Self->Is(
    $Ticket{ 'DynamicField_CustomerLogin' . $RandomID },
    undef,
    "DynamicField 'CustomerLogin$RandomID' for Ticket ID:'$TicketID' is undefined (Contact has no login)",
);
$Self->IsDeeply(
    $Ticket{ 'DynamicField_CustomerFirstname' . $RandomID },
    [ $TestContactData{Firstname} ],
    "DynamicField 'CustomerFirstname$RandomID' for Ticket ID:'$TicketID' match TestUser Firstname",
);
$Self->IsDeeply(
    $Ticket{ 'DynamicField_CustomerLastname' . $RandomID },
    [ $TestContactData{Lastname} ],
    "DynamicField 'CustomerLastname$RandomID' for Ticket ID:'$TicketID' match TestUser Lastname",
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
