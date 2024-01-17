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
my $MainObject   = $Kernel::OM->Get('Main');
my $Helper       = $Kernel::OM->Get('UnitTest::Helper');

# get home directory
my $HomeDir = $ConfigObject->Get('Home');

# atm we are only testing Redis
my @BackendModuleFiles = ( 'Kernel/System/Cache/Redis.pm' );

# define fixed time compatible backends
my %FixedTimeCompatibleBackends = (
    FileStorable => 0,
    Redis        => 0,
);

MODULEFILE:
for my $ModuleFile (@BackendModuleFiles) {

    next MODULEFILE if !$ModuleFile;

    # extract module name
    my ($Module) = $ModuleFile =~ m{ \/+ ([a-zA-Z0-9]+) \.pm $ }xms;

    next MODULEFILE if !$Module;

    for my $SubdirLevels ( 0 .. 3 ) {

        $Kernel::OM->ObjectParamAdd(
            Cache => {
                Backend => "Kernel::System::Cache::$Module"
            }
        );

        # make sure that the CacheObject gets recreated for each loop.
        $Kernel::OM->ObjectsDiscard( Objects => ['Cache'] );

        $ConfigObject->Set(
            Key   => 'Cache::SubdirLevels',
            Value => $SubdirLevels,
        );

        # get a new cache object
        my $CacheObject = $Kernel::OM->Get('Cache');

        next MODULEFILE if !$CacheObject;

        # flush the cache to have a clear test environment
        $CacheObject->CleanUp();

        # some tests check that the cache expires, for that we have to disable the in-memory cache
        $CacheObject->Configure(
            CacheInMemory => 0,
        );

        # set fixed time
        if ( $FixedTimeCompatibleBackends{$Module} ) {
            $Helper->FixedTimeSet();
        }

        my $CacheSet = $CacheObject->Set(
            Type  => 'CacheTest1',
            Key   => 'Test',
            Value => '1234',
            TTL   => 60 * 24 * 60 * 60,
        );
        $Self->True(
            $CacheSet,
            "#1 - $Module - $SubdirLevels - CacheSet(), TTL 60*24*60*60",
        );

        my $CacheGet = $CacheObject->Get(
            Type => 'CacheTest1',
            Key  => 'Test',
        );
        $Self->Is(
            $CacheGet || q{},
            '1234',
            "#1 - $Module - $SubdirLevels - CacheGet()",
        );

        my $CacheDelete = $CacheObject->Delete(
            Type => 'CacheTest1',
            Key  => 'Test',
        );
        $Self->True(
            $CacheDelete,
            "#1 - $Module - $SubdirLevels - CacheDelete()",
        );

        $CacheGet = $CacheObject->Get(
            Type => 'CacheTest1',
            Key  => 'Test',
        );
        $Self->False(
            $CacheGet || q{},
            "#1 - $Module - $SubdirLevels - CacheGet()",
        );

        # invalid keys
        $CacheSet = $CacheObject->Set(
            Type   => 'CacheTest1::invalid::type',
            Key    => 'Test',
            Value  => '1234',
            TTL    => 60 * 24 * 60 * 60,
            Silent => 1,
        );
        $Self->False(
            scalar $CacheSet,
            "#1 - $Module - $SubdirLevels - CacheSet() for invalid type",
        );

        $CacheGet = $CacheObject->Get(
            Type => 'CacheTest1::invalid::type',
            Key  => 'Test',
        );
        $Self->False(
            scalar $CacheGet,
            "#1 - $Module - $SubdirLevels - CacheGet() for invalid type",
        );

        # test charset specific situations
        $CacheSet = $CacheObject->Set(
            Type  => 'CacheTest2',
            Key   => 'Test',
            Value => {
                Key1 => 'Value1',
                Key2 => 'Value2äöüß',
                Key3 => 'Value3',
                Key4 => [
                    'äöüß',
                    '123456789',
                    'ÄÖÜß',
                    {
                        KeyA  => 'ValueA',
                        KeyB  => 'ValueBäöüßタ',
                        KeyC  => 'ValueC',
                        Value => '9ßüß-カスタ1234',
                    },
                ],
            },
            TTL => 60 * 24 * 60 * 60,
        );

        $Self->True(
            $CacheSet,
            "#2 - $Module - $SubdirLevels - CacheSet()",
        );

        $CacheGet = $CacheObject->Get(
            Type => 'CacheTest2',
            Key  => 'Test',
        );

        $Self->Is(
            $CacheGet->{Key2} || q{},
            'Value2äöüß',
            "#2 - $Module - $SubdirLevels - CacheGet() - {Key2}",
        );
        $Self->True(
            Encode::is_utf8( $CacheGet->{Key2} ) || q{},
            "#2 - $Module - $SubdirLevels - CacheGet() - {Key2} Encode::is_utf8",
        );
        $Self->Is(
            $CacheGet->{Key4}->[0] || q{},
            'äöüß',
            "#2 - $Module - $SubdirLevels - CacheGet() - {Key4}->[0]",
        );
        $Self->True(
            Encode::is_utf8( $CacheGet->{Key4}->[0] ) || q{},
            "#2 - $Module - $SubdirLevels - CacheGet() - {Key4}->[0] Encode::is_utf8",
        );
        $Self->Is(
            $CacheGet->{Key4}->[3]->{KeyA} || q{},
            'ValueA',
            "#2 - $Module - $SubdirLevels - CacheGet() - {Key4}->[3]->{KeyA}",
        );
        $Self->Is(
            $CacheGet->{Key4}->[3]->{KeyB} || q{},
            'ValueBäöüßタ',
            "#2 - $Module - $SubdirLevels - CacheGet() - {Key4}->[3]->{KeyB}",
        );

        $Self->True(
            Encode::is_utf8( $CacheGet->{Key4}->[3]->{KeyB} ) || q{},
            "#2 - $Module - $SubdirLevels - CacheGet() - {Key4}->[3]->{KeyB} Encode::is_utf8",
        );

        $CacheSet = $CacheObject->Set(
            Type  => 'CacheTest3',
            Key   => 'Test',
            Value => q{ü},
            TTL   => 8,
        );

        $Self->True(
            $CacheSet,
            "#3 - $Module - $SubdirLevels - CacheSet(), TTL 8",
        );

        # wait 7 seconds
        if ( $FixedTimeCompatibleBackends{$Module} ) {
            $Helper->FixedTimeAddSeconds(7);
        }
        else {
            sleep 7;
        }

        $CacheGet = $CacheObject->Get(
            Type => 'CacheTest3',
            Key  => 'Test',
        );

        $Self->Is(
            $CacheGet || q{},
            q{ü},
            "#3 - $Module - $SubdirLevels - CacheGet()",
        );

        $Self->True(
            Encode::is_utf8($CacheGet) || q{},
            "#3 - $Module - $SubdirLevels - CacheGet() - Encode::is_utf8",
        );

        $CacheSet = $CacheObject->Set(
            Type  => 'CacheTest4',
            Key   => 'Test',
            Value => '9ßüß-カスタ1234',
            TTL   => 4,
        );

        $Self->True(
            $CacheSet,
            "#4 - $Module - $SubdirLevels - CacheSet(), TTL 4",
        );

        # wait 3 seconds
        if ( $FixedTimeCompatibleBackends{$Module} ) {
            $Helper->FixedTimeAddSeconds(3);
        }
        else {
            sleep 3;
        }

        $CacheGet = $CacheObject->Get(
            Type => 'CacheTest4',
            Key  => 'Test',
        );

        $Self->Is(
            $CacheGet || q{},
            '9ßüß-カスタ1234',
            "#4 - $Module - $SubdirLevels - CacheGet()",
        );
        $Self->True(
            Encode::is_utf8($CacheGet) || q{},
            "#4 - $Module - $SubdirLevels - CacheGet() - Encode::is_utf8",
        );

        # wait 3 seconds
        if ( $FixedTimeCompatibleBackends{$Module} ) {
            $Helper->FixedTimeAddSeconds(3);
        }
        else {
            sleep 3;
        }

        $CacheGet = $CacheObject->Get(
            Type => 'CacheTest4',
            Key  => 'Test',
        );

        $Self->True(
            !$CacheGet || q{},
            "#4 - $Module - $SubdirLevels - CacheGet() - wait 6 seconds - TTL expires after 4 seconds",
        );

        $CacheSet = $CacheObject->Set(
            Type  => 'CacheTest5',
            Key   => 'Test',
            Value => '123456',
            TTL   => 60 * 60,
        );

        $Self->True(
            $CacheSet,
            "#5 - $Module - $SubdirLevels - CacheSet()",
        );

        $CacheGet = $CacheObject->Get(
            Type => 'CacheTest5',
            Key  => 'Test',
        );

        $Self->Is(
            $CacheGet || q{},
            '123456',
            "#5 - $Module - $SubdirLevels - CacheGet()",
        );
        $CacheDelete = $CacheObject->Delete(
            Type => 'CacheTest5',
            Key  => 'Test',
        );
        $Self->True(
            $CacheDelete,
            "#5 - $Module - $SubdirLevels - CacheDelete()",
        );

        # A-z char type test
        $CacheSet = $CacheObject->Set(
            Type   => 'Value2äöüß',
            Key    => 'Test',
            Value  => '1',
            TTL    => 60,
            Silent => 1,
        );
        $Self->True(
            !$CacheSet || q{},
            "#6 - $Module - $SubdirLevels - Set() - A-z type check",
        );

        $CacheDelete = $CacheObject->Delete(
            Type => 'Value2äöüß',
            Key  => 'Test',
        );
        $Self->True(
            !$CacheDelete || 0,
            "#6 - $Module - $SubdirLevels - CacheDelete() - A-z type check",
        );

        # create new cache files
        $CacheSet = $CacheObject->Set(
            Type  => 'CacheTest7',
            Key   => 'Test',
            Value => '1234',
            TTL   => 24 * 60 * 60,
        );
        $Self->True(
            $CacheSet,
            "#7 - $Module - $SubdirLevels - CacheSet(), TTL 24*60*60",
        );

        # check get
        $CacheGet = $CacheObject->Get(
            Type => 'CacheTest7',
            Key  => 'Test',
        );
        $Self->Is(
            $CacheGet || q{},
            '1234',
            "#7 - $Module - $SubdirLevels - CacheGet()",
        );

        # cleanup (expired)
        my $CacheCleanUp = $CacheObject->CleanUp( Expired => 1 );
        $Self->True(
            $CacheCleanUp,
            "#7 - $Module - $SubdirLevels - CleanUp( Expired => 1 )",
        );

        # check get
        $CacheGet = $CacheObject->Get(
            Type => 'CacheTest7',
            Key  => 'Test',
        );

        $Self->False(
            $CacheGet,
            "#7 - $Module - $SubdirLevels - CacheGet() - Expired",
        );

        # cleanup
        $CacheCleanUp = $CacheObject->CleanUp();
        $Self->True(
            $CacheCleanUp,
            "#7 - $Module - $SubdirLevels - CleanUp()",
        );

        # check get
        $CacheGet = $CacheObject->Get(
            Type => 'CacheTest7',
            Key  => 'Test',
        );
        $Self->False(
            $CacheGet,
            "#7 - $Module - $SubdirLevels - CacheGet()",
        );

        # unset fixed time
        if ( $FixedTimeCompatibleBackends{$Module} ) {
            $Helper->FixedTimeUnset();
        }

        my $String1 = q{};
        my $String2 = q{};
        my %KeyList;
        COUNT:
        for my $Count ( 1 .. 16 ) {

            $String1
                .= $String1
                . $Count
                . "abcdefghijklmnopqrstuvwxyz1234567890abcdefghijklmnopqrstuvwxyzöäüßЖЛЮѬ ";
            $String2
                .= $String2
                . $Count
                . "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZöäüßЖЛЮѬ ";
            my $Size = length $String1;

            if ( $Size > ( 1024 * 1024 ) ) {
                $Size = sprintf "%.1f MBytes", ( $Size / ( 1024 * 1024 ) );
            }
            elsif ( $Size > 1024 ) {
                $Size = sprintf "%.1f KBytes", ( ( $Size / 1024 ) );
            }
            else {
                $Size = $Size . ' Bytes';
            }

            # create key
            my $Key = $Helper->GetRandomNumber();

            # copy strings to safe the reference
            my $StringRef1 = $String1;
            my $StringRef2 = $String2;

            # define cachetests 1
            my %CacheTests1 = (

                HASH => {
                    Test  => 'ABC',
                    Test2 => $String1,
                    Test3 => [ 'AAA', 'BBB' ],
                },

                ARRAY => [
                    'ABC',
                    $String1,
                    [ 'AAA', 'BBB' ],
                ],

                SCALAR => \$StringRef1,

                String => $String1,
            );

            # define cachetests 2
            my %CacheTests2 = (

                HashRef => {
                    Test  => 'XYZ',
                    Test2 => $String2,
                    Test3 => [ 'CCC', 'DDD' ],
                },

                ArrayRef => [
                    'XYZ',
                    $String2,
                    [ 'EEE', 'FFF' ],
                ],

                ScalarRef => \$StringRef2,

                String => $String2,
            );

            TYPE:
            for my $Type ( sort keys %CacheTests1 ) {

                # set cache
                my $InnerCacheSet = $CacheObject->Set(
                    Type  => 'CacheTestLong1',
                    Key   => $Type . $Key,
                    Value => $CacheTests1{$Type},
                    TTL   => 24 * 60 * 60,
                );

                $Self->True(
                    $InnerCacheSet,
                    "#8 - $Module - $SubdirLevels - CacheSet1() Size $Size",
                );

                next TYPE if !$InnerCacheSet;

                $KeyList{1}->{ $Type . $Key } = $CacheTests1{$Type};
            }

            TYPE:
            for my $Type ( sort keys %CacheTests2 ) {

                # set cache
                my $InnerCacheSet = $CacheObject->Set(
                    Type  => 'CacheTestLong2',
                    Key   => $Type . $Key,
                    Value => $CacheTests2{$Type},
                    TTL   => 24 * 60 * 60,
                );

                $Self->True(
                    $InnerCacheSet,
                    "#8 - $Module - $SubdirLevels - CacheSet2() Size $Size",
                );

                next TYPE if !$InnerCacheSet;

                $KeyList{2}->{ $Type . $Key } = $CacheTests2{$Type};
            }
        }

        for my $Mode ( 'All', 'One', 'None' ) {

            if ( $Mode eq 'One' ) {

                # invalidate all values of CacheTestLong1
                my $CleanUp1 = $CacheObject->CleanUp(
                    Type => 'CacheTestLong1',
                );

                $Self->True(
                    $CleanUp1,
                    "#8 - $Module - $SubdirLevels - CleanUp() - invalidate all values of CacheTestLong1",
                );

                # unset all values of CacheTestLong1
                for my $Key ( sort keys %{ $KeyList{1} } ) {
                    $KeyList{1}->{$Key} = q{};
                }
            }
            elsif ( $Mode eq 'None' ) {

                # invalidate all values of CacheTestLong2
                my $CleanUp2 = $CacheObject->CleanUp(
                    Type => 'CacheTestLong2',
                );

                $Self->True(
                    $CleanUp2,
                    "#8 - $Module - $SubdirLevels - CleanUp() - invalidate all values of CacheTestLong2",
                );

                # unset all values of CacheTestLong2
                for my $Key ( sort keys %{ $KeyList{2} } ) {
                    $KeyList{2}->{$Key} = q{};
                }
            }

            for my $Count ( sort keys %KeyList ) {

                for my $Key ( sort keys %{ $KeyList{$Count} } ) {

                    # extract cache item
                    my $CacheItem = $KeyList{$Count}->{$Key};

                    # check get
                    my $InnerCacheGet = $CacheObject->Get(
                        Type => 'CacheTestLong' . $Count,
                        Key  => $Key,
                    ) || q{};

                    if (
                        ref $CacheItem eq 'HASH'
                        || ref $CacheItem eq 'ARRAY'
                        || ref $CacheItem eq 'SCALAR'
                    ) {

                        # check attributes
                        $Self->IsDeeply(
                            $InnerCacheGet,
                            $CacheItem,
                            "#8 - $Module - $SubdirLevels - CacheGet$Count() - Content Test",
                        );
                    }
                    else {

                        # Don't use Is(), produces too much output.
                        $Self->True(
                            $InnerCacheGet eq $CacheItem,
                            "#8 - $Module - $SubdirLevels - CacheGet$Count() - Content Test",
                        );
                    }
                }
            }
        }

        # check wide character key
        $CacheSet = $CacheObject->Set(
            Type  => 'WideCharacterTest',
            Key   => "Test \x{2639}",
            Value => '1',
            TTL   => 60,
        );
        $Self->True(
            $CacheSet,
            "#9 - $Module - CacheSet() - Wide Character Key check",
        );
        $CacheGet = $CacheObject->Get(
            Type => 'WideCharacterTest',
            Key  => "Test \x{2639}",
        );
        $Self->True(
            $CacheGet,
            "#9 - $Module - CacheGet() - Wide Character Key check",
        );

        # flush the cache
        $CacheObject->CleanUp();
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
