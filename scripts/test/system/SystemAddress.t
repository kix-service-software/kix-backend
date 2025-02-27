# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
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

# get needed objects
my $SystemAddressObject = $Kernel::OM->Get('SystemAddress');

# add SystemAddress
my $SystemAddressEmail    = $Helper->GetRandomID() . '@example.com';
my $SystemAddressRealname = "KIX-Team";

my $SystemAddressID = $SystemAddressObject->SystemAddressAdd(
    Name     => '1' . $SystemAddressEmail,
    Realname => '1' . $SystemAddressRealname,
    Comment  => 'some comment 1',
    ValidID  => 1,
    UserID   => 1,
);

$Self->True(
    $SystemAddressID,
    'SystemAddressAdd()',
);

my %SystemAddress = $SystemAddressObject->SystemAddressGet( ID => $SystemAddressID );

$Self->Is(
    $SystemAddress{Name},
    '1' . $SystemAddressEmail,
    'SystemAddressGet() - Name',
);
$Self->Is(
    $SystemAddress{Realname},
    '1' . $SystemAddressRealname,
    'SystemAddressGet() - Realname',
);
$Self->Is(
    $SystemAddress{Comment},
    'some comment 1',
    'SystemAddressGet() - Comment',
);
$Self->Is(
    $SystemAddress{QueueID},
    undef,
    'SystemAddressGet() - QueueID',
);
$Self->Is(
    $SystemAddress{ValidID},
    1,
    'SystemAddressGet() - ValidID',
);

# update system address - set queue
my $SystemAddressUpdate = $SystemAddressObject->SystemAddressUpdate(
    ID       => $SystemAddressID,
    Name     => '2' . $SystemAddressEmail,
    Realname => '2' . $SystemAddressRealname,
    Comment  => 'some comment 2',
    QueueID  => 1,
    ValidID  => 1,
    UserID   => 1,
);
$Self->True(
    $SystemAddressUpdate,
    'SystemAddressUpdate() - Set Name, Realname, Comment and QueueID',
);

%SystemAddress = $SystemAddressObject->SystemAddressGet( ID => $SystemAddressID );

$Self->Is(
    $SystemAddress{Name},
    '2' . $SystemAddressEmail,
    'SystemAddressGet() - Name',
);
$Self->Is(
    $SystemAddress{Realname},
    '2' . $SystemAddressRealname,
    'SystemAddressGet() - Realname',
);
$Self->Is(
    $SystemAddress{Comment},
    'some comment 2',
    'SystemAddressGet() - Comment',
);
$Self->Is(
    $SystemAddress{QueueID},
    1,
    'SystemAddressGet() - QueueID',
);
$Self->Is(
    $SystemAddress{ValidID},
    1,
    'SystemAddressGet() - ValidID',
);

my %SystemAddressList = $SystemAddressObject->SystemAddressList( Valid => 0 );
my $Hit = 0;
if ( $SystemAddressList{ $SystemAddressID } ) {
    $Hit = 1;
}
$Self->True(
    $Hit eq 1,
    'SystemAddressList() - Valid => 0 (Hit)',
);

%SystemAddressList = $SystemAddressObject->SystemAddressList( Valid => 1 );
$Hit = 0;
if ( $SystemAddressList{ $SystemAddressID } ) {
    $Hit = 1;
}
$Self->True(
    $Hit eq 1,
    'SystemAddressList() - Valid => 1 (Hit)',
);

$SystemAddressUpdate = $SystemAddressObject->SystemAddressUpdate(
    ID       => $SystemAddressID,
    Name     => '3' . $SystemAddressEmail,
    Realname => '3' . $SystemAddressRealname,
    Comment  => 'some comment 3',
    ValidID  => 2,
    UserID   => 1,
);
$Self->True(
    $SystemAddressUpdate,
    'SystemAddressUpdate() - Set Name, Realname, Comment and ValidID; Unset QueueID',
);

%SystemAddress = $SystemAddressObject->SystemAddressGet( ID => $SystemAddressID );

$Self->Is(
    $SystemAddress{Name},
    '3' . $SystemAddressEmail,
    'SystemAddressGet() - Name',
);
$Self->Is(
    $SystemAddress{Realname},
    '3' . $SystemAddressRealname,
    'SystemAddressGet() - Realname',
);
$Self->Is(
    $SystemAddress{Comment},
    'some comment 3',
    'SystemAddressGet() - Comment',
);
$Self->Is(
    $SystemAddress{QueueID},
    undef,
    'SystemAddressGet() - QueueID',
);
$Self->Is(
    $SystemAddress{ValidID},
    2,
    'SystemAddressGet() - ValidID',
);

%SystemAddressList = $SystemAddressObject->SystemAddressList( Valid => 0 );
$Hit = 0;
if ( $SystemAddressList{ $SystemAddressID } ) {
    $Hit = 1;
}
$Self->True(
    $Hit eq 1,
    'SystemAddressList() - Valid => 0 (Hit)',
);

%SystemAddressList = $SystemAddressObject->SystemAddressList( Valid => 1 );
$Hit = 0;
if ( $SystemAddressList{ $SystemAddressID } ) {
    $Hit = 1;
}
$Self->True(
    $Hit eq 0,
    'SystemAddressList() - Valid => 1 (No Hit)',
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
