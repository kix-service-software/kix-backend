# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Environment;

use strict;
use warnings;

use POSIX;
use ExtUtils::MakeMaker;
use Sys::Hostname::Long;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Main',
);

=head1 NAME

Kernel::System::Environment - collect environment info

=head1 SYNOPSIS

Functions to collect environment info

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create environment object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $EnvironmentObject = $Kernel::OM->Get('Environment');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item OSInfoGet()

collect operating system information

    my %OSInfo = $EnvironmentObject->OSInfoGet();

returns:

    %OSInfo = (
        Distribution => "debian",
        Hostname     => "servername.example.com",
        OS           => "Linux",
        OSName       => "debian 7.1",
        Path         => "/home/kix/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games",
        POSIX        => [
                        "Linux",
                        "servername",
                        "3.2.0-4-686-pae",
                        "#1 SMP Debian 3.2.46-1",
                        "i686",
                      ],
        User         => "kix",
    );

=cut

sub OSInfoGet {
    my ( $Self, %Param ) = @_;

    my @Data = POSIX::uname();

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    # If used OS is a linux system
    my $OSName;
    my $Distribution;
    if ( $^O =~ /(linux|unix|netbsd)/i ) {

        if ( $^O eq 'linux' ) {

            $MainObject->Require('Linux::Distribution');

            my $DistributionName = Linux::Distribution::distribution_name();

            $Distribution = $DistributionName || 'unknown';

            if ($DistributionName) {

                my $DistributionVersion = Linux::Distribution::distribution_version() || '';

                $OSName = $DistributionName . ' ' . $DistributionVersion;
            }
        }
        elsif ( -e "/etc/issue" ) {

            my $Content = $MainObject->FileRead(
                Location => '/etc/issue',
                Result   => 'ARRAY',
            );

            if ($Content) {
                $OSName = $Content->[0];
            }
        }
        else {
            $OSName = "Unknown version";
        }
    }
    elsif ( $^O eq 'darwin' ) {

        my $MacVersion = `sw_vers -productVersion` || '';
        chomp $MacVersion;

        $OSName = 'MacOSX ' . $MacVersion;
    }
    elsif ( $^O eq 'freebsd' ) {
        $OSName = `uname -r`;
    }
    else {
        $OSName = "Unknown";
    }

    my %OSMap = (
        linux   => 'Linux',
        freebsd => 'FreeBSD',
        darwin  => 'MacOSX',
    );

    # collect OS data
    my %EnvOS = (
        Hostname     => hostname_long(),
        OSName       => $OSName,
        Distribution => $Distribution,
        User         => $ENV{USER} || $ENV{USERNAME},
        Path         => $ENV{PATH},
        HostType     => $ENV{HOSTTYPE},
        LcCtype      => $ENV{LC_CTYPE},
        Cpu          => $ENV{CPU},
        MachType     => $ENV{MACHTYPE},
        POSIX        => \@Data,
        OS           => $OSMap{$^O} || $^O,
    );

    return %EnvOS;
}

=item ModuleVersionGet()

Return the version of an installed perl module:

    my $Version = $EnvironmentObject->ModuleVersionGet(
        Module => 'MIME::Parser',
    );

returns

    $Version = '5.503';

or undef if the module is not installed.

=cut

sub ModuleVersionGet {
    my ( $Self, %Param ) = @_;

    my $File = "$Param{Module}.pm";
    $File =~ s{::}{/}g;

    # traverse @INC to see if the current module is installed in
    # one of these locations
    my $Path;
    PATH:
    for my $Dir (@INC) {

        my $PossibleLocation = File::Spec->catfile( $Dir, $File );

        next PATH if !-r $PossibleLocation;

        $Path = $PossibleLocation;

        last PATH;
    }

    # if we have no $Path the module is not installed
    return if !$Path;

    # determine version number by means of ExtUtils::MakeMaker
    return MM->parse_version($Path);
}

=item PerlInfoGet()

collect perl information:

    my %PerlInfo = $EnvironmentObject->PerlInfoGet();

you can also specify options:

    my %PerlInfo = $EnvironmentObject->PerlInfoGet(
        BundledModules => 1,
    );

returns:

    %PerlInfo = (
        PerlVersion   => "5.14.2",

    # if you specified 'BundledModules => 1' you'll also get this:

        Modules => {
            "Algorithm::Diff"  => "1.30",
            "Apache::DBI"      => 1.62,
            ......
        },
    );

=cut

sub PerlInfoGet {
    my ( $Self, %Param ) = @_;

    # collect perl data
    my %EnvPerl = (
        PerlVersion => sprintf "%vd",
        $^V,
    );

    my %Modules;
    if ( $Param{BundledModules} ) {

        for my $Module (
            qw(
            parent
            Algorithm::Diff
            Apache::DBI
            CGI
            Class::Inspector
            Crypt::PasswdMD5
            CSS::Minifier
            Date::Pcalc
            Email::Valid
            Encode::Locale
            IO::Interactive
            JavaScript::Minifier
            JSON
            JSON::PP
            Linux::Distribution
            Locale::Codes
            LWP
            Email::Address::XS
            Mail::Internet
            MIME::Tools
            Module::Refresh
            Mozilla::CA
            Net::IMAP::Simple
            Net::HTTP
            Net::SSLGlue
            PDF::API2
            SOAP::Lite
            Sys::Hostname::Long
            Text::CSV
            Text::Diff
            YAML
            URI
            )
            )
        {
            $Modules{$Module} = $Self->ModuleVersionGet( Module => $Module );
        }
    }

    # add modules list
    if (%Modules) {
        $EnvPerl{Modules} = \%Modules;
    }

    return %EnvPerl;
}

=item DBInfoGet()

collect database information

    my %DBInfo = $EnvironmentObject->DBInfoGet();

returns

    %DBInfo = (
        Database => "kixdb",
        Host     => "dbserver.example.com",
        User     => "kixuser",
        Type     => "mysql",
        Version  => "MySQL 5.5.31-0+wheezy1",
    )

=cut

sub DBInfoGet {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $ConfigObject = $Kernel::OM->Get('Config');
    my $DBObject     = $Kernel::OM->Get('DB');

    # collect DB data
    my %EnvDB = (
        Host     => $ConfigObject->Get('DatabaseHost'),
        Database => $ConfigObject->Get('Database'),
        User     => $ConfigObject->Get('DatabaseUser'),
        Type     => $ConfigObject->Get('Database::Type') || $DBObject->{'DB::Type'},
        Version  => $DBObject->Version(),
    );

    return %EnvDB;
}

=item KIXInfoGet()

collect information about KIX installation

    my %Info = $EnvironmentObject->KIXInfoGet();

returns:

    %Info = (
        Product         => "KIX",
        Version         => "17.0.0",
        DefaultLanguage => "en",
        Home            => "/opt/kix",
        Host            => "prod.kix.com",
        SystemID        => 70,
    );

=cut

sub KIXInfoGet {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $FQDN = $Kernel::OM->Get('Config')->Get('FQDN');
    if (IsHashRefWithData($FQDN)) {
        $FQDN = $FQDN->{Backend}
    }

    # collect KIX data
    my %EnvData = (
        Version         => $ConfigObject->Get('Version'),
        Home            => $ConfigObject->Get('Home'),
        Host            => $FQDN,
        Product         => $ConfigObject->Get('Product'),
        SystemID        => $ConfigObject->Get('SystemID'),
        DefaultLanguage => $ConfigObject->Get('DefaultLanguage'),
    );

    return %EnvData;
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
