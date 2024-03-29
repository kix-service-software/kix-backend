# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, http://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Log;

use strict;
use warnings;

use Carp ();

our @ObjectDependencies = (
    'Config',
    'Encode',
);

=head1 NAME

Kernel::System::Log - global log interface

=head1 SYNOPSIS

All log functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a log object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Log' => {
            LogPrefix => 'InstallScriptX',  # not required, but highly recommend
        },
    );
    my $LogObject = $Kernel::OM->Get('Log');

=cut

my %LogLevel = (
    error  => 16,
    notice => 8,
    info   => 4,
    debug  => 2,
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    if ( !$Kernel::OM ) {
        Carp::confess('$Kernel::OM is not defined, please initialize your object manager')
    }

    my $ConfigObject = $Kernel::OM->Get('Config');
        
    $Self->{ProductVersion} = ($ConfigObject->Get('Product') || 'KIX') . ' ';
    $Self->{ProductVersion} .= ($ConfigObject->Get('Version') || 18);

    # get system id
    my $SystemID = $ConfigObject->Get('SystemID');

    # check log prefix
    $Self->{LogPrefix} = $Param{LogPrefix} || '?LogPrefix?';
    $Self->{LogPrefix} .= '-' . $SystemID;

    # configured log level (debug by default)
    $Self->{MinimumLevel}    = $ConfigObject->Get('MinimumLogLevel') || 'debug';
    $Self->{MinimumLevel}    = lc $Self->{MinimumLevel};
    $Self->{MinimumLevelNum} = $LogLevel{ $Self->{MinimumLevel} };

    # load log backend
    my $GenericModule = $ConfigObject->Get('LogModule') || 'Kernel::System::Log::SysLog';
    if ( !eval "require $GenericModule" ) {    ## no critic
        die "Can't load log backend module $GenericModule! $@";
    }

    # create backend handle
    $Self->{Backend} = $GenericModule->new(
        %Param,
    );

    return $Self if !eval "require IPC::SysV";    ## no critic

    # create the IPC options
    $Self->{IPCKey} = '444423' . $SystemID;       # This name is used to identify the shared memory segment.
    $Self->{IPCSize} = $ConfigObject->Get('LogSystemCacheSize') || 32 * 1024;

    # init session data mem
    if ( !eval { $Self->{IPCSHMKey} = shmget( $Self->{IPCKey}, $Self->{IPCSize}, oct(1777) ) } ) {

        # If direct creation fails, try more gently, allocate a small segment first and the reset/resize it.
        $Self->{IPCSHMKey} = shmget( $Self->{IPCKey}, 1, oct(1777) );
        if ( !shmctl( $Self->{IPCSHMKey}, 0, 0 ) ) {
            $Self->Log(
                Priority => 'error',
                Message  => "Can't remove shm for log: $!",
            );
            return;
        }

        # Re-initialize SHM segment.
        $Self->{IPCSHMKey} = shmget( $Self->{IPCKey}, $Self->{IPCSize}, oct(1777) );
    }

    return if !$Self->{IPCSHMKey};

    # Only flag IPC as active if everything worked well.
    $Self->{IPC} = 1;

    return $Self;
}

=item Log()

log something. log priorities are 'debug', 'info', 'notice' and 'error'.

These are mapped to the SysLog priorities. Please use the appropriate priority level:

=over

=item debug

Debug-level messages; info useful for debugging the application, not useful during operations.

=item info

Informational messages; normal operational messages - may be used for reporting etc, no action required.

=item notice

Normal but significant condition; events that are unusual but not error conditions, no immediate action required.

=item error

Error conditions. Non-urgent failures, should be relayed to developers or admins, each item must be resolved.

=back

See for more info L<http://en.wikipedia.org/wiki/Syslog#Severity_levels>

    $LogObject->Log(
        Priority => 'error',
        Message  => "Need something!",
    );

=cut

sub Log {
    my ( $Self, %Param ) = @_;

    my $Priority    = lc $Param{Priority}  || 'debug';
    my $PriorityNum = $LogLevel{$Priority} || $LogLevel{debug};

    return 1 if $PriorityNum < $Self->{MinimumLevelNum};

    my $Message = $Param{MSG} || $Param{Message} || '???';
    my $Caller = $Param{Caller} || 0;

    # returns the context of the current subroutine and sub-subroutine!
    my ( $Package1, $Filename1, $Line1, $Subroutine1 ) = caller( $Caller + 0 );
    my ( $Package2, $Filename2, $Line2, $Subroutine2 ) = caller( $Caller + 1 );

    $Subroutine2 ||= $0;

    # log backend
    $Self->{Backend}->Log(
        Priority  => $Priority,
        Message   => $Message,
        LogPrefix => $Self->{LogPrefix},
        Module    => $Subroutine2,
        Line      => $Line1,
    );

    # if error, write it to STDERR
    if ( $Priority =~ /^error/i ) {

        ## no critic
        my $Error = sprintf "ERROR: $Self->{LogPrefix} Perl: %vd OS: $^O Time: "
            . localtime() . "\n\n", $^V;
        ## use critic

        $Error .= " Message: $Message\n\n";

        if ( %ENV && ( $ENV{REMOTE_ADDR} || $ENV{REQUEST_URI} ) ) {

            my $RemoteAddress = $ENV{REMOTE_ADDR} || '-';
            my $RequestURI    = $ENV{REQUEST_URI} || '-';

            $Error .= " RemoteAddress: $RemoteAddress\n";
            $Error .= " RequestURI: $RequestURI\n\n";
        }

        $Error .= " Traceback ($$): \n";

        COUNT:
        for ( my $Count = 0; $Count < 30; $Count++ ) {

            my ( $Package1, $Filename1, $Line1, $Subroutine1 ) = caller( $Caller + $Count );

            last COUNT if !$Line1;

            my ( $Package2, $Filename2, $Line2, $Subroutine2 ) = caller( $Caller + 1 + $Count );

            # if there is no caller module use the file name
            $Subroutine2 ||= $0;

            # print line if upper caller module exists
            my $VersionString = '';

            eval { $VersionString = $Package1->VERSION || ''; };    ## no critic

            # version is present
            if ($VersionString) {
                $VersionString = ' (v' . $VersionString . ')';
            }

            $Error .= "   Module: $Subroutine2$VersionString Line: $Line1\n";

            last COUNT if !$Line2;
        }

        $Error .= "\n";
        print STDERR $Error;

        # store data for reference
        $Self->{error}->{Message} //= [];
        $Self->{error}->{Traceback} //= [];

        push @{$Self->{error}->{Message}}, $Message;
        push @{$Self->{error}->{Traceback}}, $Error;

        # truncate to 100 entries
        if ( @{$Self->{error}->{Message}} > 100 ) {
            shift @{$Self->{error}->{Message}};
        }
        if ( @{$Self->{error}->{Traceback}} > 100 ) {
            shift @{$Self->{error}->{Traceback}};
        }
    }

    # remember to info and notice messages
    elsif ( lc $Priority eq 'info' || lc $Priority eq 'notice' ) {
        $Self->{ lc $Priority }->{Message} //= [];

        push @{$Self->{ lc $Priority }->{Message}}, $Message;

        # truncate to 100 entries
        if ( @{$Self->{ lc $Priority }->{Message}} > 100 ) {
            shift @{$Self->{ lc $Priority }->{Message}};
        }
    }

    # write shm cache log
    if ( lc $Priority ne 'debug' && $Self->{IPC} ) {

        $Priority = lc $Priority;

        my $Data   = localtime() . ";;$Priority;;$Self->{LogPrefix};;$Message\n";    ## no critic
        my $String = $Self->GetLog();

        shmwrite( $Self->{IPCSHMKey}, $Data . $String, 0, $Self->{IPCSize} ) || die $!;
    }

    return 1;
}

=item GetLogEntry()

to get the last log info back

    my $Message = $LogObject->GetLogEntry(
        Type  => 'error',   # error|info|notice
        What  => 'Message', # Message|Traceback,
        Index => 1,         # optional: index in the list (max. 100 entries). Use negative values to access items at the end of the list (-1 is the last element). If not given, the last entry will be returned.
    );

=cut

sub GetLogEntry {
    my ( $Self, %Param ) = @_;

    my $Index = $Param{Index} || -1;

    return $Self->{ lc $Param{Type} }->{ $Param{What} }[$Index] || '';
}

=item GetLog()

to get the tmp log data (from shared memory - ipc) in csv form

    my $CSVLog = $LogObject->GetLog();

=cut

sub GetLog {
    my ( $Self, %Param ) = @_;

    my $String = '';
    if ( $Self->{IPC} ) {
        shmread( $Self->{IPCSHMKey}, $String, 0, $Self->{IPCSize} ) || die "$!";
    }

    # Remove \0 bytes that shmwrite adds for padding.
    $String =~ s{\0}{}smxg;

    # encode the string
    $Kernel::OM->Get('Encode')->EncodeInput( \$String );

    return $String;
}

=item GetNumericLogLevel()

jet the numeric log level

    my $LogLevelNum = $LogObject->GetNumericLogLevel(
        Priority => 'error'
    );

=cut

sub GetNumericLogLevel {
    my ( $Self, %Param ) = @_;

    return $LogLevel{$Param{Priority}};
}


=item CleanUp()

to clean up the logs and tmp log data from shared memory (ipc)

    $LogObject->CleanUp();

=cut

sub CleanUp {
    my ( $Self, %Param ) = @_;

    # cleanup backend
    if ( $Self->{Backend}->can('CleanUp') ) {
        $Self->{Backend}->CleanUp();
    }

    return 1 if !$Self->{IPC};

    shmwrite( $Self->{IPCSHMKey}, '', 0, $Self->{IPCSize} ) || die $!;

    return 1;
}

=item Dumper()

dump a perl variable to log

    $LogObject->Dumper(@Array);

    or

    $LogObject->Dumper(%Hash);

=cut

sub Dumper {
    my ( $Self, @Data ) = @_;

    require Data::Dumper;    ## no critic

    # returns the context of the current subroutine and sub-subroutine!
    my ( $Package1, $Filename1, $Line1, $Subroutine1 ) = caller(0);
    my ( $Package2, $Filename2, $Line2, $Subroutine2 ) = caller(1);

    $Subroutine2 ||= $0;

    # log backend
    $Self->{Backend}->Log(
        Priority  => 'debug',
        Message   => substr( Data::Dumper::Dumper(@Data), 0, 600600600 ),    ## no critic
        LogPrefix => $Self->{LogPrefix},
        Module    => $Subroutine2,
        Line      => $Line1,
    );

    return 1;
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
