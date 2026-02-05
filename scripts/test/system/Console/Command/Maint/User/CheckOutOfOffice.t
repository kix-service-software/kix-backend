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

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get command object
my $CommandObject = $Kernel::OM->Get('Console::Command::Maint::User::CheckOutOfOffice');

# silence console output
local *STDOUT;
local *STDERR;
open STDOUT, '>>', "/dev/null";
open STDERR, '>>', "/dev/null";

## prepare user mapping
my $RoleID = $Kernel::OM->Get('Role')->RoleLookup(
    Role => 'Ticket Agent'
);
my $UserID1 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => $Helper->GetRandomID(),
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID1,
    RoleID       => $RoleID,
    UserID       => 1,
);
$Self->True(
    $UserID1,
    'First user created'
);
my $UserID2 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => $Helper->GetRandomID(),
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID2,
    RoleID       => $RoleID,
    UserID       => 1,
);
$Self->True(
    $UserID2,
    'Second user created'
);
my $UserID3 = $Kernel::OM->Get('User')->UserAdd(
    UserLogin     => $Helper->GetRandomID(),
    ValidID       => 1,
    ChangeUserID  => 1,
    IsAgent       => 1
);
$Kernel::OM->Get('Role')->RoleUserAdd(
    AssignUserID => $UserID3,
    RoleID       => $RoleID,
    UserID       => 1,
);
$Self->True(
    $UserID3,
    'Third user created'
);


## prepare times
my $SystemTime = $Kernel::OM->Get('Time')->SystemTime();
my $Today = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
    SystemTime => $SystemTime,
    Type       => 'Short'
);

my @Dates;
my @RelativeTimes = (
    '-3w',
    '-2w',
    '+1M',
    '+1M +2w',
    '+1d',
    '-3d'
);
for my $Time (@RelativeTimes ) {
    my $TmpSystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => $Time,
    );
    my $Date = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
        SystemTime => $TmpSystemTime,
        Type       => 'Short'
    );

    push(@Dates, $Date);
}

my @TestData = (
    {
        Name     => "Check: OutOfOffice / Set Date: NO / Reset: NO",
        Expected => 0
    },
    {
        Data => {
            OutOfOfficeStart => $Dates[5],
            OutOfOfficeEnd   => $Dates[4],
            UserID           => $UserID1
        },
        Expected => 0,
        Name     => "Check: OutOfOffice / Set Date: YES / Reset: NO / Value: [\$Dates[5],\$Dates[4]]/ User: \$UserID1"
    },
    {
        Data => {
            OutOfOfficeStart  => $Dates[2],
            OutOfOfficeEnd    => $Dates[3],
            UserID            => $UserID2
        },
        Expected => 0,
        Name     => "Check: OutOfOffice / Set Date: YES / Reset: NO / Value: [\$Dates[2],\$Dates[3]]/ User: \$UserID2"
    },
    {
        Data => {
            OutOfOfficeStart  => $Dates[0],
            OutOfOfficeEnd    => $Dates[1],
            UserID            => $UserID3
        },
        Expected => 1,
        Name     => "Check: OutOfOffice / Set Date: YES / Reset: YES / Value: [\$Dates[0],\$Dates[1]]/ User: \$UserID3"
    },
    {
        Data => {
            OutOfOfficeStart  => $Dates[4],
            OutOfOfficeEnd    => $Dates[5],
            UserID            => $UserID1
        },
        Expected => 1,
        Name     => "Check: OutOfOffice / Set Date: YES / Reset: YES / Value: [\$Dates[4],\$Dates[5]]/ User: \$UserID1"
    },
    {
        Data => {
            OutOfOfficeStart      => $Dates[4],
            OutOfOfficeEnd        => $Dates[5],
            OutOfOfficeSubstitute => 1,
            UserID                => $UserID1
        },
        Expected => 1,
        Name     => "Check: OutOfOffice / Set Date: YES / Reset: YES / Value: [\$Dates[4],\$Dates[5], 1]/ User: \$UserID1"
    }
);


for my $Test ( @TestData ) {

    if ( $Test->{Data} ) {
        my %User = $Kernel::OM->Get('User')->GetUserData(
            UserID => $Test->{Data}->{UserID}
        );
        my $Success = $Kernel::OM->Get('User')->UserUpdate(
            %User,
            %{$Test->{Data}},
            ChangeUserID => 1
        );

        my $Name = 'Update User | ';
        for my $Key ( qw(OutOfOfficeStart OutOfOfficeEnd OutOfOfficeSubstitute UserID) ){
            $Name .= "$Key: " . (defined $Test->{Data}->{$Key} ? $Test->{Data}->{$Key} : 'None') . q( | );
        }

        $Self->True(
            $Success,
            $Name
        );

        my %Users = $Kernel::OM->Get('User')->UserSearch(
            IsOutOfOfficeEnd => 1
        );
        my @UserIDs = keys %Users;

        $Self->Is(
            scalar( @UserIDs ),
            $Test->{Expected},
            $Test->{Name}
        );
    }

    $CommandObject->Execute();


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
