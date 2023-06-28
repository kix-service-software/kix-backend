# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Dev::Tools::CacheBenchmark;

use strict;
use warnings;

our $IsWin32 = 0;
if ( $^O eq 'MSWin32' ) {
    eval {
        require Win32;
        require Win32::Process;
    } or last;
    $IsWin32 = 1;
}

use Time::HiRes ();

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'Main',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Runs a benchmark over the available cache backends.');

    $Self->AddOption(
        Name        => 'backend',
        Description => "The cache backend to benchmark, i.e. FileStorable",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^[a-zA-Z0-9]*$/smx,
    );
    $Self->AddOption(
        Name        => 'processes',
        Description => "Number of parallel processes to use. Default: 1",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
    );
    $Self->AddOption(
        Name        => 'sid',
        Description => "The unique cache identifier.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*?/smx,
        Invisible   => 1,
    );
    $Self->AddOption(
        Name        => 'item-size',
        Description => "The item size to be checked. Needed for the job process in Win32.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+?/smx,
        Invisible   => 1,
    );
    $Self->AddOption(
        Name        => 'process-id',
        Description => "The ID of the job process. Needed for the job process in Win32.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^\d+$/smx,
        Invisible   => 1,
    );
    $Self->AdditionalHelp("<red>Please don't use this command in production environments.</red>\n");

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Backend   = $Self->GetOption('backend');
    my $ProcessID = $Self->GetOption('process-id');
    my $Processes = $Self->GetOption('processes');

    if (!$ProcessID) {

        # get home directory
        my $HomeDir = $Kernel::OM->Get('Config')->Get('Home');

        # get all avaliable backend modules
        my @BackendModuleFiles = $Kernel::OM->Get('Main')->DirectoryRead(
            Directory => $HomeDir . '/Kernel/System/Cache/',
            Filter    => $Backend ? $Backend.'.pm' : '*.pm',
            Silent    => 1,
        );

        MODULEFILE:
        for my $ModuleFile (@BackendModuleFiles) {

            next MODULEFILE if !$ModuleFile;

            # extract module name
            my ($Module) = $ModuleFile =~ m{ \/+ ([a-zA-Z0-9]+) \.pm $ }xms;

            next MODULEFILE if !$Module;

            $Kernel::OM->Get('Config')->Set(
                Key   => 'Cache::Module',
                Value => "Kernel::System::Cache::$Module",
            );

            # Make sure we get a fresh instance
            $Kernel::OM->ObjectsDiscard(
                Objects => ['Cache'],
            );

            my $CacheObject = $Kernel::OM->Get('Cache');

            if ( !$CacheObject->{CacheObject}->isa("Kernel::System::Cache::$Module") ) {
                die "Could not create cache backend Kernel::System::Cache::$Module";
            }

            $CacheObject->Configure(
                CacheInMemory  => 0,
                CacheInBackend => 1,
            );

            print "Testing cache module $Module\n";

            # create unique ID for this session
            my @Dictionary = ( "A" .. "Z" );
            my $SID;
            $SID .= $Dictionary[ rand @Dictionary ] for 1 .. 8;

            # preload cache for each process
            $Self->Preload(
                Backend   => $Module,
                SID       => $SID,
                Processes => $Processes || 1,
            );

            print "Cache module    Item Size[b] Operations Time[s]    Op/s  Set OK  Get OK  Del OK\n";
            print "--------------- ------------ ---------- ------- ------- ------- ------- -------\n";

            $Self->Benchmark(
                Backend   => $Module,
                SID       => $SID,
                Processes => $Processes || 1,
            );

            # cleanup initial cache
            print "Removing preloaded 100k x 1kB items... ";
            for ( my $i = 0; $i < 10; $i++ ) {
                my $Result = $CacheObject->CleanUp(
                    Type => 'CacheTestInitContent' . $SID . ( $i % 10 ),
                );
            }
            print "done.\n";
        }
    }
    else {
        my $SID = $Self->GetOption('sid');
        my $ItemSize = $Self->GetOption('item-size');
        my $Preload = $Self->GetOption('preload');

        $Kernel::OM->Get('Config')->Set(
            Key   => 'Cache::Module',
            Value => "Kernel::System::Cache::$Param{Backend}",
        );

        # Make sure we get a fresh instance
        $Kernel::OM->ObjectsDiscard(
            Objects => ['Cache'],
        );

        my $CacheObject = $Kernel::OM->Get('Cache');

        if ( !$CacheObject->{CacheObject}->isa("Kernel::System::Cache::$Param{Backend}") ) {
            die "Could not create cache backend Kernel::System::Cache::$Param{Backend}";
        }

        $CacheObject->Configure(
            CacheInMemory  => 0,
            CacheInBackend => 1,
        );

        if ($Preload) {
            $Self->_DoPreload(
                $Self,
                SID       => $SID,
                ProcessID => $ProcessID,
            );
        }
        else {
            $Self->_TestItemSize(
                $Self,
                SID       => $SID,
                ItemSize  => $ItemSize,
                ProcessID => $ProcessID,
            );
        }
    }

    return $Self->ExitCodeOk();
}

sub Preload {
    my ( $Self, %Param ) = @_;

    # load cache initially with 100k 1kB items
    print "Preloading cache with 100k x 1kB items per process... ";
    $| = 1;
    if (!$IsWin32) {
        my $JobResult = $Self->_DoJob(
            Backend   => $Param{Backend},
            SID       => $Param{SID},
            Preload   => 1,
            Processes => $Param{Processes},
        );
    }
    else {
        my $JobResult = $Self->_DoJobWin32(
            Backend   => $Param{Backend},
            SID       => $Param{SID},
            Preload   => 1,
            Processes => $Param{Processes},
        );
    }

    print "done.\n";

    return 1;
}

sub Benchmark {
    my ( $Self, %Param ) = @_;

    my $TimeTotal = 0;
    for my $ItemSize ( 64, 256, 512, 1024, 4096, 10240, 102400, 1048576, 4194304 ) {
        my $OpCount = 10 + 50 * int( 7 - Log10($ItemSize) );

        printf( "%-15s %12d %10d ", $Param{Backend}, $ItemSize, 100 * $OpCount );
        $| = 1;

        # start timer
        my $Start = Time::HiRes::time();

        my $JobResult;
        if (!$IsWin32) {
            $JobResult = $Self->_DoJob(
                Backend   => $Param{Backend},
                SID       => $Param{SID},
                ItemSize  => $ItemSize,
                Processes => $Param{Processes},
            );
        }
        else {
            $JobResult = $Self->_DoJobWin32(
                Backend   => $Param{Backend},
                SID       => $Param{SID},
                ItemSize  => $ItemSize,
                Processes => $Param{Processes},
            );
        }
        # stop timer
        my $TimeTaken = Time::HiRes::time() - $Start;

        $TimeTotal += $TimeTaken;

        printf("%7.2f %7.0f %6.0f%% %6.0f%% %6.0f%%\n", $TimeTaken, 100 * $OpCount / $TimeTaken, $JobResult->{SetOK}, $JobResult->{GetOK} , $JobResult->{DelOK});
    }

    printf("\nTotal Time: %.2fs\n", $TimeTotal);

    return 1;
}

sub _DoPreload {
    my ( $Self, %Param ) = @_;

    my $CacheObject = $Kernel::OM->Get('Cache');

    my $Content1kB = '.' x 1024;

    for ( my $i = 0; $i < 100000; $i++ ) {
        my $Result = $CacheObject->Set(
            Type => 'CacheTestInitContent' . $Param{SID} . ( $i % 10 ),
            Key => 'Test' . $Param{ProcessID} . $i,
            Value => $Content1kB,
            TTL   => 60 * 24 * 60 * 60,
        );
    }

    print $Param{ProcessID}.' ';

    return 1;
}

sub _DoJob {
    my ( $Self, %Param ) = @_;

    my @Children;

    for my $ProcessID ( 1 .. $Param{Processes} ) {
        my $PID = fork();

        if (!$PID) {
            # child process - do your job
            if ($Param{Preload}) {
                $Self->_DoPreload(
                    Backend   => $Param{Backend},
                    SID       => $Param{SID},
                    ProcessID => $ProcessID,
                );
            }
            else {
                $Self->_TestItemSize(
                    Backend   => $Param{Backend},
                    SID       => $Param{SID},
                    ProcessID => $ProcessID,
                    ItemSize  => $Param{ItemSize}
                );
            }

            exit 0;
        }
        else {
            push(@Children, $PID);
        }
    }

    my $Result;
    if ($Param{ItemSize}) {
        my $SetOK = 0;
        my $GetOK = 0;
        my $DelOK = 0;
        while (@Children) {
            my $PID = shift @Children;
            waitpid($PID, 0);

            # read result file
            my $JobResult = $Kernel::OM->Get('Main')->FileRead(
                Directory => $Kernel::OM->Get('Config')->Get('TempDir'),
                Filename  => 'CacheBenchmark.'.$Param{ItemSize}.'.'.$PID.'.result',
            );

            my ($JobSetOK, $JobGetOK, $JobDelOK) = split(/::/, $$JobResult);
            $SetOK += $JobSetOK;
            $GetOK += $JobGetOK;
            $DelOK += $JobDelOK;
        }

        $Result = {
            SetOK => $SetOK / $Param{Processes},
            GetOK => $GetOK / $Param{Processes},
            DelOK => $DelOK / $Param{Processes},
        };
    }
    else {
        while (@Children) {
            my $PID = shift @Children;
            waitpid($PID, 0);
        }
        $Result = 1;
    }

    return $Result;
}

sub _DoJobWin32 {
    my ( $Self, %Param ) = @_;

    my @Children;
    my $TimeStart = $Self->{TimeObject}->SystemTime();
    my $Home = $Kernel::OM->Get('Config')->Get('Home');

    for my $ProcessID ( 1 .. $Param{Processes} ) {
        my $Child;
        Win32::Process::Create(
            $Child,
            $ENV{COMSPEC},
            "/c $Home/bin/kix.Console.pl Dev::Tools::Database::SQLBenchmark --allow-root --backend $Param{Backend} --process-id $ProcessID --item-size $Param{ItemSize} --sid $Param{SID} --preload $Param{Preload}",
            0, 0, "."
        );
        push(@Children, $Child);
    }

    while (@Children) {
        my $ExitCode;
        $Children[0]->GetExitCode($ExitCode);
        if ($ExitCode != Win32::Process::STILL_ACTIVE()) {
            shift @Children;
        }
        sleep(1);
    }

    # return {

    # }
}

sub _TestItemSize {
    my ( $Self, %Param ) = @_;

    my $CacheObject = $Kernel::OM->Get('Cache');

    my $Content = ' ' x $Param{ItemSize};
    my $OpCount = 10 + 50 * int( 7 - Log10($Param{ItemSize}) );

    my $SetOK = 0;
    for ( my $i = 0; $i < $OpCount; $i++ ) {
        my $Result = $CacheObject->Set(
            Type => 'CacheTest' . $Param{SID} . ( $i % 10 ),
            Key => 'Test' . $Param{ProcessID} . $i,
            Value => $Content,
            TTL   => 60 * 24,
        );
        $SetOK++ if $Result;
    }

    my $GetOK = 0;
    for ( my $j = 0; $j < 98; $j++ ) {
        for ( my $i = 0; $i < $OpCount; $i++ ) {
            my $Result = $CacheObject->Get(
                Type => 'CacheTest' . $Param{SID} . ( $i % 10 ),
                Key => 'Test' . $Param{ProcessID} . $i,
            );

            $GetOK++ if ( $Result && ( $Result eq $Content ) );
        }
    }

    my $DelOK = 0;
    for ( my $i = 0; $i < $OpCount; $i++ ) {
        my $Result = $CacheObject->Delete(
            Type => 'CacheTest' . $Param{SID} . ( $i % 10 ),
            Key => 'Test' . $Param{ProcessID} . $i,
        );
        $DelOK++ if $Result;
    }

    # report
    my $Result = (100 * $SetOK /   ($OpCount)).'::'.(100 * $GetOK /   ( 98 * $OpCount )).'::'.(100 * $DelOK /   ($OpCount));

    $Kernel::OM->Get('Main')->FileWrite(
        Directory => $Kernel::OM->Get('Config')->Get('TempDir'),
        Filename  => 'CacheBenchmark.'.$Param{ItemSize}.'.'.$$.'.result',
        Content   => \$Result,
    );

    return 1;
}

sub Log10 {
    my $n = shift;
    return log($n) / log(10);
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
