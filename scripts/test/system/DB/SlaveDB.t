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

# This test checks the slave handling features in DB.pm

my $MasterDSN      = $Kernel::OM->Get('Config')->Get('DatabaseDSN');
my $MasterUser     = $Kernel::OM->Get('Config')->Get('DatabaseUser');
my $MasterPassword = $Kernel::OM->Get('Config')->Get('DatabasePw');

my @Tests = (
    {
        Name   => "No slave configured",
        Config => {
            'Core::MirrorDB::DSN'               => undef,
            'Core::MirrorDB::User'              => undef,
            'Core::MirrorDB::Password'          => undef,
            'Core::MirrorDB::AdditionalMirrors' => undef,
        },
        SlaveDBAvailable => 0,
        TestIterations   => 1,
    },
    {
        Name   => "First slave configured",
        Config => {
            'Core::MirrorDB::DSN'               => $MasterDSN,
            'Core::MirrorDB::User'              => $MasterUser,
            'Core::MirrorDB::Password'          => $MasterPassword,
            'Core::MirrorDB::AdditionalMirrors' => undef,
        },
        SlaveDBAvailable => 1,
        TestIterations   => 1,
    },
    {
        Name   => "First slave configured as invalid",
        Config => {
            'Core::MirrorDB::DSN'               => $MasterDSN,
            'Core::MirrorDB::User'              => 'wrong_user',
            'Core::MirrorDB::Password'          => 'wrong_password',
            'Core::MirrorDB::AdditionalMirrors' => undef,
        },
        Silent           => 1,
        SlaveDBAvailable => 0,
        TestIterations   => 1,
    },
    {
        Name   => "Additional slave configured",
        Config => {
            'Core::MirrorDB::DSN'               => undef,
            'Core::MirrorDB::User'              => undef,
            'Core::MirrorDB::Password'          => undef,
            'Core::MirrorDB::AdditionalMirrors' => {
                1 => {
                    DSN      => $MasterDSN,
                    User     => $MasterUser,
                    Password => $MasterPassword,
                },
            },
        },
        SlaveDBAvailable => 1,
        TestIterations   => 1,
    },
    {
        Name   => "Additional slave configured as invalid",
        Config => {
            'Core::MirrorDB::DSN'               => undef,
            'Core::MirrorDB::User'              => undef,
            'Core::MirrorDB::Password'          => undef,
            'Core::MirrorDB::AdditionalMirrors' => {
                1 => {
                    DSN      => $MasterDSN,
                    User     => 'wrong_user',
                    Password => 'wrong_password',
                },
            },
        },
        Silent           => 1,
        SlaveDBAvailable => 0,
        TestIterations   => 1,
    },
    {
        Name   => "Full config with valid first slave and invalid additional",
        Config => {
            'Core::MirrorDB::DSN'               => $MasterDSN,
            'Core::MirrorDB::User'              => $MasterUser,
            'Core::MirrorDB::Password'          => $MasterPassword,
            'Core::MirrorDB::AdditionalMirrors' => {
                1 => {
                    DSN      => $MasterDSN,
                    User     => 'wrong_user',
                    Password => 'wrong_password',
                },
                2 => {
                    DSN      => $MasterDSN,
                    User     => $MasterUser,
                    Password => $MasterPassword,
                },
            },
        },
        Silent           => 1,
        SlaveDBAvailable => 1,

        # Use many iterations so that also the invalid mirror will be tried first at some point, probably.
        TestIterations => 10,
    },
);

TEST:
for my $Test (@Tests) {

    for my $TestIteration ( 1 .. $Test->{TestIterations} ) {
        # Test cases wit UseSlaveDB = 0
        {
            # get fresh objects
            $Kernel::OM->ObjectsDiscard();

            # force loading sysconfig, so master db is not used later
            $Kernel::OM->Get('Config')->LoadSysConfig();

            # disconnect master db
            $Kernel::OM->Get('DB')->Disconnect();

            # set config for testcase
            for my $ConfigKey ( sort keys %{ $Test->{Config} } ) {
                $Kernel::OM->Get('Config')->Set(
                    Key   => $ConfigKey,
                    Value => $Test->{Config}->{$ConfigKey},
                );
            }

            # Regular fetch from master
            my @ValidIDs;
            my $TestPrefix = "$Test->{Name} - $TestIteration - UseSlaveDB 0: ";

            $Kernel::OM->Get('DB')->Prepare(
                SQL => "\nSELECT id\nFROM valid",    # simulate indentation
            );
            while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
                push @ValidIDs, $Row[0];
            }
            $Self->True(
                scalar @ValidIDs,
                "$TestPrefix valid ids were found",
            );
            $Self->True(
                $Kernel::OM->Get('DB')->{Cursor},
                "$TestPrefix statement handle active on master",
            );
            $Self->False(
                $Kernel::OM->Get('DB')->{SlaveDBObject},
                "$TestPrefix SlaveDB not connected",
            );
        }

        # Test cases wit UseSlaveDB = 1
        {
            # get fresh objects
            $Kernel::OM->ObjectsDiscard();

            # force loading sysconfig, so master db is not used later
            $Kernel::OM->Get('Config')->LoadSysConfig();

            # disconnect master db
            $Kernel::OM->Get('DB')->Disconnect();

            # set config for testcase
            for my $ConfigKey ( sort keys %{ $Test->{Config} } ) {
                $Kernel::OM->Get('Config')->Set(
                    Key   => $ConfigKey,
                    Value => $Test->{Config}->{$ConfigKey},
                );
            }

            # Perform requests on the slave DB
            local $Kernel::System::DB::UseSlaveDB = 1;
            my @ValidIDs   = ();
            my $TestPrefix = "$Test->{Name} - $TestIteration - UseSlaveDB 1: ";

            $Kernel::OM->Get('DB')->Prepare(
                SQL    => "\nSELECT id\nFROM valid",    # simulate indentation
                Silent => $Test->{Silent},
            );
            while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
                push @ValidIDs, $Row[0];
            }
            $Self->True(
                scalar @ValidIDs,
                "$TestPrefix valid ids were found",
            );

            if ( !$Test->{SlaveDBAvailable} ) {
                $Self->True(
                    $Kernel::OM->Get('DB')->{Cursor},
                    "$TestPrefix statement handle active on master",
                );
                $Self->False(
                    $Kernel::OM->Get('DB')->{SlaveDBObject},
                    "$TestPrefix SlaveDB not connected",
                );
                next TEST;
            }

            $Self->False(
                $Kernel::OM->Get('DB')->{Cursor},
                "$TestPrefix statement handle inactive on master",
            );
            $Self->True(
                $Kernel::OM->Get('DB')->{SlaveDBObject}->{Cursor},
                "$TestPrefix statement handle active on slave",
            );

            $Self->False(
                scalar $Kernel::OM->Get('DB')->Ping( AutoConnect => 0 ),
                "$TestPrefix master object is not connected automatically",
            );

            $Self->True(
                scalar $Kernel::OM->Get('DB')->{SlaveDBObject}->Ping( AutoConnect => 0 ),
                "$TestPrefix slave object is connected",
            );

            $Kernel::OM->Get('DB')->Disconnect();

            $Self->False(
                scalar $Kernel::OM->Get('DB')->Ping( AutoConnect => 0 ),
                "$TestPrefix master object is disconnected",
            );

            $Self->False(
                scalar $Kernel::OM->Get('DB')->{SlaveDBObject}->Ping( AutoConnect => 0 ),
                "$TestPrefix slave object is disconnected",
            );

            $Kernel::OM->Get('DB')->Connect();

            $Self->True(
                scalar $Kernel::OM->Get('DB')->Ping( AutoConnect => 0 ),
                "$TestPrefix master object is reconnected",
            );

            $Self->True(
                scalar $Kernel::OM->Get('DB')->{SlaveDBObject}->Ping( AutoConnect => 0 ),
                "$TestPrefix slave object is not reconnected automatically",
            );
        }
    }
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
