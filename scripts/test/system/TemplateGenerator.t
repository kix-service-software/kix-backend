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

# prepare test contact
my $ContactID = $Helper->TestContactCreate();
my %Contact   = $Kernel::OM->Get('Contact')->ContactGet(
    ID => $ContactID
);

# prepare test user
my $TestUserLogin = $Helper->TestUserCreate(
    Roles => ['Ticket Agent'],
);
my $TestUserID = $Kernel::OM->Get('User')->UserLookup(
    UserLogin => $TestUserLogin,
);

# prepare test ticket
my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title          => 'Some Ticket_Title',
    Queue          => 'Junk',
    Lock           => 'unlock',
    Priority       => '3 normal',
    State          => 'closed',
    OrganisationID => $Contact{PrimaryOrganisationID},
    ContactID      => $ContactID,
    OwnerID        => $TestUserID,
    UserID         => 1,
);
$Self->True(
    $TicketID,
    'TicketCreate()',
);

# prepare binary data
my $BinaryData = MIME::Base64::decode_base64('iVBORw0KGgoAAAANSUhEUgAAABAAAAAPCAQAAABHeoekAAAAwUlEQVQYGQXBsUmDYRAA0HdyAzhQJhCsxQGUQEBIZWspElBEwQlcIHbW9k7gBmIj+f/D5Dvfy8ZVA/AYAECy6gfDkQFW/RwAkMveKIQGx5YdoPESORSAFtYgtMBl594EAMI1AMiDGaGFxo0LC8Cne9km4RbAmYV3AOTBbOPUOYBXoQF/cm+nfHtCCwDQSg6z8iPQQiNACyWHMvsFAABM8qDM7gAAwNaHHJgAAABMctgpWwAAQMm3OOmyRgBaANpX/AN65E9FAfBrYAAAAABJRU5ErkJggg==');

# test ReplacePlaceHolder
my @TestCases = (
    {
        Name     => 'Replace empty string',
        Input    => {
            Text            => '',
            Data            => {},
            RichText        => 0,
            Translate       => 0,
            TicketID        => $TicketID,
            ObjectID        => $TicketID,
            ObjectType      => 'Ticket',
            ReplaceNotFound => '',
            UserID          => 1
        },
        Expected => ''
    },
    {
        Name     => 'Replace string without placeholder',
        Input    => {
            Text            => 'This is a test',
            Data            => {},
            RichText        => 0,
            Translate       => 0,
            TicketID        => $TicketID,
            ObjectID        => $TicketID,
            ObjectType      => 'Ticket',
            ReplaceNotFound => '',
            UserID          => 1
        },
        Expected => 'This is a test'
    },
    {
        Name     => 'Replace string with simple placeholder',
        Input    => {
            Text            => '<KIX_TICKET_ID>',
            Data            => {},
            RichText        => 0,
            Translate       => 0,
            TicketID        => $TicketID,
            ObjectID        => $TicketID,
            ObjectType      => 'Ticket',
            ReplaceNotFound => '',
            UserID          => 1
        },
        Expected => $TicketID
    },
    {
        Name     => 'Handle binary data, return without change',
        Input    => {
            Text            => $BinaryData,
            Data            => {},
            RichText        => 0,
            Translate       => 0,
            TicketID        => $TicketID,
            ObjectID        => $TicketID,
            ObjectType      => 'Ticket',
            ReplaceNotFound => '',
            UserID          => 1
        },
        Expected => $BinaryData
    },
    {
        Name     => 'Handle array, return without change',
        Input    => {
            Text            => ['Test1','Test2','<KIX_TICKET_ID>'],
            Data            => {},
            RichText        => 0,
            Translate       => 0,
            TicketID        => $TicketID,
            ObjectID        => $TicketID,
            ObjectType      => 'Ticket',
            ReplaceNotFound => '',
            UserID          => 1
        },
        Expected => ['Test1','Test2','<KIX_TICKET_ID>']
    },
    {
        Name     => 'Handle hash, return without change',
        Input    => {
            Text            => { 'Test1' => 'Test1', 'Test2' => '<KIX_TICKET_ID>' },
            Data            => {},
            RichText        => 0,
            Translate       => 0,
            TicketID        => $TicketID,
            ObjectID        => $TicketID,
            ObjectType      => 'Ticket',
            ReplaceNotFound => '',
            UserID          => 1
        },
        Expected => { 'Test1' => 'Test1', 'Test2' => '<KIX_TICKET_ID>' }
    }
);
for my $Test ( @TestCases ) {
    my $ReplacedString = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        %{ $Test->{Input} }
    );
    $Self->IsDeeply(
        $ReplacedString,
        $Test->{Expected},
        $Test->{Name}
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
