#!/usr/bin/perl
# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

=head1 NAME

dump_sysconfig_defaults.pl - create a reproducible snapshot of all SysConfig
option defaults for release note generation (KIX2018-14235).

Runs INSIDE a KIX container against a rebuilt database. Contains no parsing
logic of its own: it dumps what the product actually ships, including
Extend-resolved values.

=head1 SYNOPSIS

    # 1. start target version, rebuild config
    bin/kix.Console.pl Maint::Config::Rebuild

    # 2. dump
    perl scripts/dev/dump_sysconfig_defaults.pl \
        --product KIXPro \

    # --version is read from RELEASE if omitted

=cut

use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../..";
use lib "$Bin/../../Kernel/cpan-lib";
use lib "$Bin/../../Custom";

$ENV{KIX_HOME} //= "$Bin/../..";

use Getopt::Long qw(:config no_ignore_case bundling);
use JSON::PP;

use Kernel::System::ObjectManager;

my %Opt = (
    Product => 'KIX',
    Version => '',
);

GetOptions(
    'product=s' => \$Opt{Product},
    'version=s' => \$Opt{Version},
) or die "Invalid options. See SYNOPSIS.\n";

local $Kernel::OM = Kernel::System::ObjectManager->new();

my $ConfigObject = $Kernel::OM->Get('Config');
my $MainObject   = $Kernel::OM->Get('Main');

# --- resolve version from RELEASE file unless given -------------------------
if ( !$Opt{Version} ) {
    my $ReleaseFile = $ConfigObject->Get('Home') . '/RELEASE';
    my $ContentRef  = $MainObject->FileRead(
        Location => $ReleaseFile,
        Result   => 'SCALAR',
    );

    if ( ref $ContentRef && ${$ContentRef} =~ /^\s*VERSION\s*=\s*(\S+)/m ) {
        $Opt{Version} = $1;
    }
    else {
        die "Unable to read VERSION from '$ReleaseFile'. "
          . "Pass --version explicitly.\n";
    }
}

# --- dump -------------------------------------------------------------------
my %AllOptions = $Kernel::OM->Get('SysConfig')->OptionGetAll();

if ( !%AllOptions ) {
    die "SysConfig->OptionGetAll() returned no data.\n"
      . "Is the database reachable and the config rebuilt?\n"
      . "  bin/kix.Console.pl Maint::Config::Rebuild\n";
}

# --- provenance: Extend resolution depends on the installed plugin set ------
my @Plugins = eval {
    $Kernel::OM->Get('Installation')->PluginList( Valid => 1, InitOrder => 1 );
};
if ( $@ || !@Plugins ) {
    warn "Unable to determine plugin list: " . ( $@ || 'empty result' ) . "\n"
      . "Extend-resolved defaults cannot be attributed reliably. "
      . "Snapshot provenance is INCOMPLETE.\n";
}

# --- project onto release-relevant fields only ------------------------------
# Deliberately excluded: Value, IsModified, ID, CreateTime/By, ChangeTime/By.
# Those are installation-specific and would make snapshots non-comparable.
my %Snapshot;
my $ContextSkipped = 0;

OPTION:
for my $Name ( sort keys %AllOptions ) {
    my $Option = $AllOptions{$Name};
    next OPTION if ref $Option ne 'HASH';

    # runtime-created options (e.g. ClientRegistration) are not shipped
    # defaults and differ per installation - keep the marker, filter in diff.
    if ( $Option->{Context} ) {
        $ContextSkipped++;
    }

    $Snapshot{$Name} = {
        Type            => $Option->{Type},
        Default         => $Option->{Default},
        Group           => $Option->{Group},
        AccessLevel     => $Option->{AccessLevel},
        ExperienceLevel => $Option->{ExperienceLevel},
        IsRequired      => $Option->{IsRequired} ? 1 : 0,
        DefaultValidID  => $Option->{DefaultValidID},
        ValidID         => $Option->{ValidID},
        Description     => $Option->{Description},
        Context         => $Option->{Context},
    };
}

# canonical => sorted keys => byte-stable.
# NO timestamp in the payload: snapshots must be diffable without noise.
my $JSON = JSON::PP->new->utf8->canonical->pretty->indent_length(2);

my $Payload = {
    SchemaVersion => 1,
    Product       => $Opt{Product},
    Version       => $Opt{Version},
    Plugins       => [
        map { { Name => $_->{Name}, Directory => $_->{Directory} } } @Plugins
    ],
    OptionCount    => scalar keys %Snapshot,
    ContextOptions => $ContextSkipped,
    Options        => \%Snapshot,
};

# encode fully BEFORE any output: a partial write would leave corrupt JSON
my $Encoded = eval { $JSON->encode($Payload) };
if ( $@ || !defined $Encoded ) {
    die "Unable to encode snapshot: " . ( $@ || 'unknown error' ) . "\n";
}

# ->utf8 yields BYTES. Force a raw layer, otherwise an active :utf8 layer
# (PERL_UNICODE / container locale) double-encodes German umlauts.
binmode(STDOUT, ':raw');
print $Encoded;

# diagnostics go to STDERR - STDOUT must stay pure JSON
print STDERR "Dumped " . ( scalar keys %Snapshot ) . " SysConfig options "
  . "($Opt{Product} $Opt{Version})\n"
  . "  context-bound options included but flagged: $ContextSkipped\n"
  . "  plugins: " . ( scalar @Plugins ) . "\n";

exit 0;