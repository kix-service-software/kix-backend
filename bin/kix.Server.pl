#!/usr/bin/perl
# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;

use Getopt::Std;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin);
use lib dirname($RealBin) . '/Kernel/cpan-lib';
use lib dirname($RealBin) . '/Custom';

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'kix.Server.pl',
    },
);

print STDOUT "kix.Server.pl - starting/stopping the KIX backend server\n";

local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'kix.Server.pl',
    },
);

# get config object
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

# get pid directory
my $PIDFile  = $ConfigObject->Get('Home') . '/var/run/server.pid';

if ( !@ARGV ) {
    PrintUsage();
    exit 0;
}

# check for action
if ( lc $ARGV[0] eq 'start' ) {
    exit 1 if !Start();
    exit 0;
}
elsif ( lc $ARGV[0] eq 'stop' ) {
    exit 1 if !Stop();
    exit 0;
}
elsif ( lc $ARGV[0] eq 'status' ) {
    exit 1 if !Status();
    exit 0;
}
else {
    PrintUsage();
    exit 0;
}

sub PrintUsage {
    my $UsageText;
    $UsageText .= "Start or stop the KIX backend server.\n";
    $UsageText .= "Usage:\n";
    $UsageText .= " kix.Server.pl <ACTION>\n";
    $UsageText .= "\nActions:\n";
    $UsageText .= sprintf " %-30s - %s", 'start', 'Starts the KIX backend server' . "\n";
    $UsageText .= sprintf " %-30s - %s", 'stop', 'Stops the KIX backend server' . "\n";
    $UsageText .= sprintf " %-30s - %s", 'status', 'Shows current state of the KIX backend server' . "\n";
    $UsageText .= sprintf " %-30s - %s", 'help', 'Shows this help' . "\n";
    print STDOUT "$UsageText\n";

    return 1;
}

sub Start {
    my %Param = @_;
	
    my $PID = _GetPID();

    if ( $PID && -e "/proc/$PID" ) {
        print STDERR "KIX backend server is already running (pid $PID)\n";
        return;
    }

	my $ServiceProcess;
	my $Port = $ConfigObject->Get('ServicePort') || 8080;
	my $Server = $ConfigObject->Get('PlackServer') || 'Starman';
	my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    my $PlackOptions = $Kernel::OM->Get('Kernel::Config')->Get('PlackOptions') || '';

    if ($PlackOptions) {
        print STDOUT "using additional startup options: $PlackOptions\n"; 
    }
	
    my $Result = `plackup -s $Server $PlackOptions --access-log $Home/var/log/server.access.log --access-log $Home/var/log/server.error.log --port $Port --daemonize --pid $PIDFile $Home/bin/server/app.psgi 2>&1`;

    Status();
    
	return 1;
}

sub Stop {
    my %Param = @_;

    my $PID = _GetPID();

    if ( $PID && -e "/proc/$PID" ) {
		print STDOUT "Stopping KIX backend server (pid $PID)\n";
        kill('TERM', $PID);
		print STDOUT "KIX backend server stopped\n";
    }
	else {
		print STDOUT "KIX server is not running\n";
	}
		
    return 1;
}

sub Status {
    my %Param = @_;

    my $PID = _GetPID();

    if ( $PID && -e "/proc/$PID" ) {
        print STDOUT "KIX backend server is running (pid $PID)\n";
        return 1;
    }

    print STDOUT "KIX backend server is not running\n";
    return;
}

sub _GetPID {
    my $PID;

    if ( -e $PIDFile ) {
	
        # read existing PID file
        open my $FH, '<', $PIDFile;    ## no critic

        $PID = do { local $/; <$FH> };
        chomp($PID);

        close $FH;
    }

    return $PID;
}


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
