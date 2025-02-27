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

my $CacheType = "UnitTest_Cache_Configure";

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
    $CacheObject->Configure(
        CacheInMemory  => 1,
        CacheInBackend => 1,
    );

    die "Could not setup $Module" if !$CacheObject;

    # flush the cache to have a clear test environment
    $CacheObject->CleanUp();

    # set value in memory and in backend
    $CacheObject->Set(
        Type  => $CacheType,
        Key   => "Key1",
        Value => 1,
        TTL   => 60 * 60 * 24 * 3,
    );

    # get value from memory only
    $Self->Is(
        scalar $CacheObject->Get(
            Type           => $CacheType,
            Key            => 'Key1',
            CacheInBackend => 0,
        ),
        1,
        "Cached value from memory",
    );

    # get value from backend only
    $Self->Is(
        scalar $CacheObject->Get(
            Type          => $CacheType,
            Key           => 'Key1',
            CacheInMemory => 0,
        ),
        1,
        "Cached value from backend",
    );

    # disable both options
    $Self->Is(
        scalar $CacheObject->Get(
            Type           => $CacheType,
            Key            => 'Key1',
            CacheInMemory  => 0,
            CacheInBackend => 0,
        ),
        undef,
        "Cached value from no backend",
    );

    # Set value, but in no backend. Subsequent tests make sure it is
    #   actually removed.
    $CacheObject->Set(
        Type           => $CacheType,
        Key            => "Key1",
        Value          => 1,
        TTL            => 60 * 60 * 24 * 3,
        CacheInMemory  => 0,
        CacheInBackend => 0,
    );

    # get value from memory only
    $Self->Is(
        scalar $CacheObject->Get(
            Type           => $CacheType,
            Key            => 'Key1',
            CacheInBackend => 0,
        ),
        undef,
        "Removed value from memory",
    );

    # get value from backend only
    $Self->Is(
        scalar $CacheObject->Get(
            Type          => $CacheType,
            Key           => 'Key1',
            CacheInMemory => 0,
        ),
        undef,
        "Removed value from backend",
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
