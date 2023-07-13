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

use vars (qw($Self));

# get needed objects
my $ConfigObject       = $Kernel::OM->Get('Config');
my $TicketObject       = $Kernel::OM->Get('Ticket');
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');
my $ContactObject = $Kernel::OM->Get('Contact');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $RandomID = $Helper->GetRandomID();

# don't check email address validity
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);
$ConfigObject->Set(
    Key   => 'DynamicFieldFromContact::Mapping',
    Value => {
        UserLogin     => 'CustomerLogin' . $RandomID,
        Firstname => 'CustomerFirstname' . $RandomID,
        Lastname  => 'CustomerLastname' . $RandomID,
    },
);
$ConfigObject->Set(
    Key   => 'Ticket::EventModulePost###950-DynamicFieldFromContact',
    Value => {
        Module => 'Ticket::Event::DynamicFieldFromContact',
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

    my $ID = $DynamicFieldObject->DynamicFieldAdd(
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
my %TestContactData = $ContactObject->ContactGet(
    ID => $TestContactID,
);

# set customer Firstname and Lastname
$TestContactData{Firstname} = 'FirstName' . $RandomID;
$TestContactData{Lastname}  = 'LastName' . $RandomID;

# update the user manually because First and LastNames are important
$ContactObject->ContactUpdate(
    %TestUserData,
    Source  => 'Contact',
    ID      => $TestContactID,
    ValidID => 1,
    UserID  => 1,
);

# create a new ticket with the test user information
my $TicketID = $TicketObject->TicketCreate(
    Title          => 'Some Ticket Title',
    Queue          => 'Raw',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'new',
    OrganisationID => $TestContactData{PrimaryOrganisationID},
    Contact        => $TestContactID,
    OwnerID        => 1,
    UserID         => 1,
);

# at this point the information should be already stored in the dynamic fields
# get ticket data (with DynamicFields)
my %Ticket = $TicketObject->TicketGet(
    TicketID      => $TicketID,
    DynamicFields => 1,
    UserID        => 1,
    Silent        => 0,
);

# test actual results with expected ones
for my $DynamicFieldName (@AddedDynamicFieldNames) {
    $Self->IsNot(
        $Ticket{ 'DynamicField_' . $DynamicFieldName },
        undef,
        "DynamicField $DynamicFieldName for Ticket ID:'$TicketID' should not be undef",
    );
}

$Self->Is(
    $Ticket{ 'DynamicField_CustomerFirstname' . $RandomID },
    $TestContactData{Firstname},
    "DynamicField 'CustomerFirstname$RandomID' for Ticket ID:'$TicketID' match TestUser Firstname",
);
$Self->Is(
    $Ticket{ 'DynamicField_CustomerLastname' . $RandomID },
    $TestContactData{Lastname},
    "DynamicField 'CustomerLastname$RandomID' for Ticket ID:'$TicketID' match TestUser Lastname",
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
