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

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');

my $HomeDir            = $ConfigObject->Get('Home');
my @BackendModuleFiles = $Kernel::OM->Get('Main')->DirectoryRead(
    Directory => $HomeDir . '/Kernel/System/Cache/',
    Filter    => '*.pm',
    Silent    => 1,
);

MODULEFILE:
for my $ModuleFile (@BackendModuleFiles) {

    next MODULEFILE if !$ModuleFile;

    # extract module name
    my ($Module) = $ModuleFile =~ m{ \/+ ([a-zA-Z0-9]+) \.pm $ }xms;

    next MODULEFILE if !$Module;

    $ConfigObject->Set(
        Key   => 'Cache::Module',
        Value => "Kernel::System::Cache::$Module",
    );

    # create a local cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    die "Could not setup $Module" if !$CacheObject;

    # flush the cache to have a clear test environment
    $CacheObject->CleanUp();

    my $SetCaches = sub {
        $Self->True(
            $CacheObject->Set(
                Type  => 'A',
                Key   => 'A',
                Value => 'A',
                TTL   => 60 * 60 * 24 * 20,
            ),
            "Set A/A",
        );

        $Self->True(
            $CacheObject->Set(
                Type  => 'B',
                Key   => 'B',
                Value => 'B',
                TTL   => 60 * 60 * 24 * 20,
            ),
            "Set B/B",
        );
    };

    $SetCaches->();

    $Self->True(
        $CacheObject->CleanUp( Type => 'C' ),
        "Inexistent cache type removed",
    );

    $Self->Is(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        'A',
        "Cache A/A is present",
    );

    $Self->Is(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        'B',
        "Cache B/B is present",
    );

    $SetCaches->();

    $Self->True(
        $CacheObject->CleanUp( Type => 'A' ),
        "Cache type A removed",
    );

    $Self->False(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        "Cache A/A is not present",
    );

    $Self->Is(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        'B',
        "Cache B/B is present",
    );

    $SetCaches->();

    $Self->True(
        $CacheObject->CleanUp( KeepTypes => ['A'] ),
        "All cache types removed except A",
    );

    $Self->Is(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        'A',
        "Cache A/A is present",
    );

    $Self->False(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        "Cache B/B is not present",
    );

    $SetCaches->();

    $Self->True(
        $CacheObject->CleanUp(),
        "All cache types removed",
    );

    $Self->False(
        $CacheObject->Get(
            Type => 'A',
            Key  => 'A'
        ),
        "Cache A/A is not present",
    );

    $Self->False(
        $CacheObject->Get(
            Type => 'B',
            Key  => 'B'
        ),
        "Cache B/B is not present",
    );

    # flush the cache
    $CacheObject->CleanUp();
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
