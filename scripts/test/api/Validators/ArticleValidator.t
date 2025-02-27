# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Validator::ArticleValidator;

# get validator object
my $ValidatorObject = Kernel::API::Validator::ArticleValidator->new();

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
    Title           => 'Testticket Unittest',
    TypeID          => 1,
    StateID         => 1,
    PriorityID      => 1,
    QueueID         => 1,
    OwnerID         => 1,
    UserID          => 1,
    LockID          => 1,
);

$Self->True(
    $TicketID,
    'create test ticket',
);

my $ArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
    TicketID        => $TicketID,
    ChannelID       => 1,
    SenderTypeID    => 1,
    MimeType        => 'text/plain',
    Charset         => 'utf8',
    Subject         => 'unittest',
    Body            => 'unittest',
    HistoryType     => 'AddNote',
    HistoryComment  => '%%',
    NoAgentNotify   => 1,
    UserID          => 1,
);

$Self->True(
    $ArticleID,
    'create test article',
);

my $ValidData = {
    ArticleID => $ArticleID,
};

my %InvalidData = (
    '#01 invalid data type' => {
        ArticleID => 'unknown'
    },
    '#02 invalid ArticleD' => {
        ArticleID => -9999,
    }
);

# validate valid Type
my $Result = $ValidatorObject->Validate(
    Attribute => 'ArticleID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid ArticleID',
);

# validate invalid ArticleID
foreach my $TestID ( sort keys %InvalidData ) {
    # run test for each supported attribute
    $Result = $ValidatorObject->Validate(
        Attribute => 'ArticleID',
        Data      => $InvalidData{$TestID},
    );

    $Self->False(
        $Result->{Success},
        "Validate() - $TestID",
    );
}

# validate invalid attribute
$Result = $ValidatorObject->Validate(
    Attribute => 'InvalidAttribute',
    Data      => {},
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid attribute',
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
