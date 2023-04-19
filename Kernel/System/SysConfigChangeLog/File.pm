# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SysConfigChangeLog::File;

use strict;
use warnings;

umask "002";

our @ObjectDependencies = (
    'Config',
    'Encode',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get logfile location
    # KIX4OTRS-capeIT
    # $Self->{LogFile} = $ConfigObject->Get('LogModule::LogFile')
    #     || die 'Need LogModule::LogFile param in Config.pm';
    $Self->{LogFile} = $ConfigObject->Get('SysConfigChangeLog::LogModule::LogFile')
        || die 'Need SysConfigChangeLog::LogModule::LogFile param in Config.pm';

    # replace config tags
    $Self->{LogFile} =~ s{<KIX_CONFIG_(.+?)>}{$Self->{ConfigObject}->Get($2)}egx;

    # EO KIX4OTRS-capeIT

    # get log file suffix
    # KIX4OTRS-capeIT
    # if ( $ConfigObject->Get('LogModule::LogFile::Date') ) {
    #     my ( $s, $m, $h, $D, $M, $Y, $WD, $YD, $DST ) = localtime( time() );    ## no critic
    if ( $ConfigObject->Get('SysConfigChangeLog::LogModule::LogFile::Date') ) {
        my ( $s, $m, $h, $D, $M, $Y, $wd, $yd, $dst ) = localtime( time() );

        # EO KIX4OTRS-capeIT
        $Y = $Y + 1900;
        $M = sprintf '%02d', ++$M;
        $Self->{LogFile} .= ".$Y-$M";
    }

    # Fixed bug# 2265 - For IIS we need to create a own error log file.
    # Bind stderr to log file, because iis do print stderr to web page.
    if ( $ENV{SERVER_SOFTWARE} && $ENV{SERVER_SOFTWARE} =~ /^microsoft\-iis/i ) {
        ## no critic
        if ( !open STDERR, '>>', $Self->{LogFile} . '.error' ) {
            ## use critic
            print STDERR "ERROR: Can't write $Self->{LogFile}.error: $!";
        }
    }

    return $Self;
}

sub Log {
    my ( $Self, %Param ) = @_;

    my $FH;

    # open logfile
    ## no critic
    if ( !open $FH, '>>', $Self->{LogFile} ) {
        ## use critic

        # print error screen
        print STDERR "\n";
        print STDERR " >> Can't write $Self->{LogFile}: $! <<\n";
        print STDERR "\n";
        return;
    }

    # write log file
    $Kernel::OM->Get('Encode')->SetIO($FH);

    print $FH '[' . localtime() . ']';    ## no critic

    if ( lc $Param{Priority} eq 'debug' ) {
        print $FH "[Debug][$Param{Module}][$Param{Line}] $Param{Message}\n";
    }
    elsif ( lc $Param{Priority} eq 'info' ) {

        # KIX4OTRS-capeIT
        # print $FH "[Info][$Param{Module}] $Param{Message}\n";
        print $FH "[Info] $Param{Message}\n";

        # EO KIX4OTRS-capeIT
    }
    elsif ( lc $Param{Priority} eq 'notice' ) {

        # KIX4OTRS-capeIT
        # print $FH "[Notice][$Param{Module}] $Param{Message}\n";
        print $FH "[Notice] $Param{Message}\n";

        # EO KIX4OTRS-capeIT
    }
    elsif ( lc $Param{Priority} eq 'error' ) {
        print $FH "[Error][$Param{Module}][$Param{Line}] $Param{Message}\n";
    }
    else {

        # print error messages to STDERR
        print STDERR
            "[Error][$Param{Module}] Priority: '$Param{Priority}' not defined! Message: $Param{Message}\n";

        # and of course to logfile
        print $FH
            "[Error][$Param{Module}] Priority: '$Param{Priority}' not defined! Message: $Param{Message}\n";
    }

    # close file handle
    close $FH;

    return 1;
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
