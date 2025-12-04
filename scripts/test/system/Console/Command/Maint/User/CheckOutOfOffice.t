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
        Name     => "Check: OutOfOffice / SetPreference: NO / Reset: NO",
        Expected => 0
    },
    {
        Data => {
            Start  => $Dates[5],
            End    => $Dates[4],
            UserID => $UserID1
        },
        Expected => 1,
        Name     => "Check: OutOfOffice / SetPreference: YES / Reset: NO / Value: [\$Dates[5],\$Dates[4]]/ User: \$UserID1"
    },
    {
        Data => {
            Start  => $Dates[2],
            End    => $Dates[3],
            UserID => $UserID2
        },
        Expected => 2,
        Name     => "Check: OutOfOffice / SetPreference: YES / Reset: NO / Value: [\$Dates[2],\$Dates[3]]/ User: \$UserID2"
    },
    {
        Data => {
            Start  => $Dates[0],
            End    => $Dates[1],
            UserID => $UserID3
        },
        Expected => 2,
        Name     => "Check: OutOfOffice / SetPreference: YES / Reset: YES / Value: [\$Dates[0],\$Dates[1]]/ User: \$UserID3"
    },
    {
        Data => {
            Start  => $Dates[4],
            End    => $Dates[5],
            UserID => $UserID1
        },
        Expected => 1,
        Name     => "Check: OutOfOffice / SetPreference: YES / Reset: YES / Value: [\$Dates[4],\$Dates[5]]/ User: \$UserID1"
    },
    {
        Data => {
            Start      => $Dates[4],
            End        => $Dates[5],
            Substitute => 1,
            UserID     => $UserID1
        },
        Expected => 1,
        Name     => "Check: OutOfOffice / SetPreference: YES / Reset: YES / Value: [\$Dates[4],\$Dates[5], 1]/ User: \$UserID1"
    }
);


for my $Test ( @TestData ) {

    if ( $Test->{Data} ) {
        my $Success = $Kernel::OM->Get('User')->SetPreferences(
            Key    => 'OutOfOfficeStart',
            Value  => $Test->{Data}->{Start},
            UserID => $Test->{Data}->{UserID}
        );

        $Self->True(
            $Success,
            "SetPreference: OutOfOfficeStart / Value $Test->{Start} / UserID $Test->{UserID}"
        );

        $Success = $Kernel::OM->Get('User')->SetPreferences(
            Key    => 'OutOfOfficeEnd',
            Value  => $Test->{Data}->{End},
            UserID => $Test->{Data}->{UserID}
        );

        $Self->True(
            $Success,
            "SetPreference: OutOfOfficeEnd / Value $Test->{End} / UserID $Test->{UserID}"
        );

        if ( $Test->{Data}->{Substitute} ) {
            $Success = $Kernel::OM->Get('User')->SetPreferences(
                Key    => 'OutOfOfficeSubstitute',
                Value  => $Test->{Data}->{Substitute},
                UserID => $Test->{Data}->{UserID}
            );

            $Self->True(
                $Success,
                "SetPreference: OutOfOfficeSubstitute / Value $Test->{Substitute} / UserID $Test->{UserID}"
            );
        }

        # get pseudo OOO prefs from user
        $Kernel::OM->Get('DB')->Prepare(
            SQL => "
                SELECT outofoffice_start, outofoffice_end, outofoffice_substitute
                FROM users
                WHERE id = ?",
            Bind => [ \$Test->{Data}->{UserID} ],
        );

        # fetch the result
        my %OutOfOffice;
        while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            $OutOfOffice{Start}      = $Row[0];
            $OutOfOffice{End}        = $Row[1];
            $OutOfOffice{Substitute} = $Row[2];
        }

        $Self->Is(
            $OutOfOffice{Start},
            $Test->{Data}->{Start},
            "pseudo OutOfOffice Preferences on user: OutOfOfficeStart / UserID $Test->{UserID}"
        );

        $Self->Is(
            $OutOfOffice{End},
            $Test->{Data}->{End},
            "pseudo OutOfOffice Preferences on user: OutOfOfficeEnd / UserID $Test->{UserID}"
        );

        if ( $Test->{Data}->{Substitute} ) {
        $Self->Is(
            $OutOfOffice{Substitute},
            $Test->{Data}->{Substitute},
            "pseudo OutOfOffice Preferences on user: OutOfOfficeSubstitute / UserID $Test->{UserID}"
        );
        }
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
