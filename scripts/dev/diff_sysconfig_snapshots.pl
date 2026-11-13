#!/usr/bin/perl
# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

=head1 NAME

diff_sysconfig_snapshots.pl - compare two SysConfig snapshots and emit the
changed-defaults list for the release notes (KIX2018-14235).

Standalone: core Perl + JSON::PP only. No KIX, no database.

=head1 SYNOPSIS

    perl diff_sysconfig_snapshots.pl \
        --old sysconfig-v37.json \
        --new sysconfig-v41.json \
        --format markdown \
        --output release-notes-sysconfig.md

    # --format json      machine readable, for the doc pipeline
    # --include-metadata also report Description-only changes

=cut

use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case bundling);
use JSON::PP;

my %Opt = (
    Old             => '',
    New             => '',
    Format          => 'markdown',
    Output          => '',
    IncludeMetadata => 0,
);

GetOptions(
    'old=s'            => \$Opt{Old},
    'new=s'            => \$Opt{New},
    'format=s'         => \$Opt{Format},
    'output=s'         => \$Opt{Output},
    'include-metadata' => \$Opt{IncludeMetadata},
) or die "Invalid options. See SYNOPSIS.\n";

$Opt{Old} or die "--old is required.\n";
$Opt{New} or die "--new is required.\n";

if ( $Opt{Format} !~ /\A(?:markdown|json)\z/ ) {
    die "--format must be 'markdown' or 'json', got '$Opt{Format}'.\n";
}

my $JSON = JSON::PP->new->utf8->canonical;

# ---------------------------------------------------------------------------
sub ReadSnapshot {
    my ($Path) = @_;

    open my $FH, '<:raw', $Path
      or die "Unable to open '$Path': $!\n";
    local $/;
    my $Content = <$FH>;
    close $FH or die "Unable to close '$Path': $!\n";

    my $Data = eval { $JSON->decode($Content) };
    die "Unable to parse '$Path' as JSON: $@\n" if $@;

    if ( ref $Data ne 'HASH' || !$Data->{SchemaVersion} || ref $Data->{Options} ne 'HASH' ) {
        die "'$Path' is not a valid SysConfig snapshot "
          . "(missing SchemaVersion or Options).\n";
    }
    if ( $Data->{SchemaVersion} != 1 ) {
        die "'$Path' has unsupported SchemaVersion '$Data->{SchemaVersion}'.\n";
    }

    return $Data;
}

# Deterministic deep-equality via canonical JSON.
# Scalars are wrapped to normalize number-vs-string ("1" vs 1); genuine type
# changes are caught separately through the Type field.
sub Canon {
    my ($Value) = @_;
    return '<undef>' if !defined $Value;
    return $JSON->encode( ref $Value ? $Value : { scalar => "$Value" } );
}

# ---------------------------------------------------------------------------
my $Old = ReadSnapshot( $Opt{Old} );
my $New = ReadSnapshot( $Opt{New} );

if ( ( $Old->{Product} // '' ) ne ( $New->{Product} // '' ) ) {
    die "Refusing to compare different products: '"
      . ( $Old->{Product} // '?' ) . "' vs '" . ( $New->{Product} // '?' )
      . "'.\nGenerate both snapshots with the same --product.\n";
}

# warn on differing plugin sets: Extend-resolved defaults are not comparable
my %OldPlugins = map { ( $_->{Name} // '?' ) => 1 } @{ $Old->{Plugins} || [] };
my %NewPlugins = map { ( $_->{Name} // '?' ) => 1 } @{ $New->{Plugins} || [] };
my @PluginDelta = (
    ( map { "+$_" } grep { !$OldPlugins{$_} } sort keys %NewPlugins ),
    ( map { "-$_" } grep { !$NewPlugins{$_} } sort keys %OldPlugins ),
);
if (@PluginDelta) {
    warn "WARNING: plugin sets differ (@PluginDelta).\n"
      . "         Extend-resolved defaults may change for reasons unrelated\n"
      . "         to the release itself. Review the diff manually.\n";
}

my @ValueFields = qw(Type Default Group AccessLevel ExperienceLevel
                     IsRequired DefaultValidID ValidID);
my @MetaFields  = qw(Description);

my %Diff = (
    Added          => {},
    Removed        => {},
    Changed        => {},
    MetadataOnly   => {},
    SkippedContext => 0,
);

my %AllNames = map { $_ => 1 } ( keys %{ $Old->{Options} }, keys %{ $New->{Options} } );

NAME:
for my $Name ( sort keys %AllNames ) {
    my $O = $Old->{Options}->{$Name};
    my $N = $New->{Options}->{$Name};

    # runtime-created options are installation specific - never release notes
    if ( ( $O && $O->{Context} ) || ( $N && $N->{Context} ) ) {
        $Diff{SkippedContext}++;
        next NAME;
    }

    if ( !$O ) { $Diff{Added}->{$Name}   = $N; next NAME; }
    if ( !$N ) { $Diff{Removed}->{$Name} = $O; next NAME; }

    my %Changes;
    for my $Field (@ValueFields) {
        next if Canon( $O->{$Field} ) eq Canon( $N->{$Field} );
        $Changes{$Field} = { Old => $O->{$Field}, New => $N->{$Field} };
    }

    my %MetaChanges;
    if ( $Opt{IncludeMetadata} ) {
        for my $Field (@MetaFields) {
            next if Canon( $O->{$Field} ) eq Canon( $N->{$Field} );
            $MetaChanges{$Field} = { Old => $O->{$Field}, New => $N->{$Field} };
        }
    }

    if (%Changes) {
        $Diff{Changed}->{$Name} = {
            Changes => \%Changes,
            Type    => $N->{Type},
            Group   => $N->{Group},
        };
    }
    elsif (%MetaChanges) {
        $Diff{MetadataOnly}->{$Name} = { Changes => \%MetaChanges };
    }
}

# ---------------------------------------------------------------------------
sub RenderValue {
    my ($Value) = @_;
    return '_(undef)_' if !defined $Value;
    if ( ref $Value ) {
        my $Encoded = JSON::PP->new->utf8->canonical->encode($Value);
        $Encoded =~ s/\|/\\|/g;
        return '`' . ( length $Encoded > 120 ? substr($Encoded, 0, 117) . '...' : $Encoded ) . '`';
    }
    my $Text = "$Value";
    $Text =~ s/\|/\\|/g;
    $Text =~ s/\n/ /g;
    return '`' . ( length $Text > 120 ? substr($Text, 0, 117) . '...' : $Text ) . '`';
}

sub RenderMarkdown {
    my ($Diff, $Old, $New) = @_;

    my @Out;
    push @Out, "## Geänderte SysConfig-Defaultwerte\n";
    push @Out, "Vergleich: **$Old->{Product} $Old->{Version}** → "
             . "**$New->{Product} $New->{Version}**\n";
    push @Out, "| Kategorie | Anzahl |", "|---|---|";
    push @Out, "| Neu hinzugefügt | " . ( scalar keys %{ $Diff{Added} } )   . " |";
    push @Out, "| Entfernt | "        . ( scalar keys %{ $Diff{Removed} } ) . " |";
    push @Out, "| Default/Metadaten geändert | "
             . ( scalar keys %{ $Diff{Changed} } ) . " |";
    push @Out, "";

    if ( %{ $Diff{Changed} } ) {
        push @Out, "### Geänderte Defaultwerte\n";
        push @Out, "| Schlüssel | Feld | Alt | Neu |", "|---|---|---|---|";
        for my $Name ( sort keys %{ $Diff{Changed} } ) {
            my $Entry = $Diff{Changed}->{$Name};
            for my $Field ( sort keys %{ $Entry->{Changes} } ) {
                my $Change = $Entry->{Changes}->{$Field};
                push @Out, "| `$Name` | $Field | "
                  . RenderValue( $Change->{Old} ) . " | "
                  . RenderValue( $Change->{New} ) . " |";
            }
        }
        push @Out, "";
    }

    if ( %{ $Diff{Added} } ) {
        push @Out, "### Neu hinzugefügte Schlüssel\n";
        push @Out, "| Schlüssel | Typ | Default |", "|---|---|---|";
        for my $Name ( sort keys %{ $Diff{Added} } ) {
            my $O = $Diff{Added}->{$Name};
            push @Out, "| `$Name` | " . ( $O->{Type} // '?' ) . " | "
              . RenderValue( $O->{Default} ) . " |";
        }
        push @Out, "";
    }

    if ( %{ $Diff{Removed} } ) {
        push @Out, "### Entfernte Schlüssel\n";
        push @Out, "> Lokale Anpassungen an diesen Schlüsseln werden beim "
                 . "Update wirkungslos.\n";
        for my $Name ( sort keys %{ $Diff{Removed} } ) {
            push @Out, "- `$Name`";
        }
        push @Out, "";
    }

    return join "\n", @Out;
}

# ---------------------------------------------------------------------------
my $Result = $Opt{Format} eq 'json'
  ? JSON::PP->new->utf8->canonical->pretty->indent_length(2)->encode({
        SchemaVersion => 1,
        Old           => { Product => $Old->{Product}, Version => $Old->{Version} },
        New           => { Product => $New->{Product}, Version => $New->{Version} },
        PluginDelta   => \@PluginDelta,
        Summary       => {
            Added          => scalar keys %{ $Diff{Added} },
            Removed        => scalar keys %{ $Diff{Removed} },
            Changed        => scalar keys %{ $Diff{Changed} },
            MetadataOnly   => scalar keys %{ $Diff{MetadataOnly} },
            SkippedContext => $Diff{SkippedContext},
        },
        Diff => \%Diff,
    })
  : RenderMarkdown( \%Diff, $Old, $New );

if ( $Opt{Output} ) {
    open my $FH, '>:raw', $Opt{Output}
      or die "Unable to write '$Opt{Output}': $!\n";
    print {$FH} $Result;
    close $FH or die "Unable to close '$Opt{Output}': $!\n";
    print "Wrote $Opt{Format} report to $Opt{Output}\n";
}
else {
    print $Result;
}

printf STDERR "added=%d removed=%d changed=%d metadata_only=%d skipped_context=%d\n",
  scalar keys %{ $Diff{Added} },
  scalar keys %{ $Diff{Removed} },
  scalar keys %{ $Diff{Changed} },
  scalar keys %{ $Diff{MetadataOnly} },
  $Diff{SkippedContext};

exit 0;