#!/usr/bin/perl

use File::Slurp;

# read definition
open(HANDLE, '<Core.def') || die "unable to open Core.def";
chomp(my @Definition = <HANDLE>);
close(HANDLE);

# read template
my $Template = read_file('Core.yml.template') || die "unable to open Core.yml.template";

my $Operations = '';
foreach my $Line (@Definition) {
    # ignore comments or empty lines
    next if ($Line =~ /^\s*#/ || $Line =~ /^\s*$/g);

    my ($Route, $Method, $Operation, $Additions) = split(/\s*\|\s*/, $Line);
    my @AdditionList = $Additions ? split(/,/, $Additions) : ();

    $Operations .= <<EOT;
    $Operation:
        Description: ''
        MappingInbound:
            Type: Simple
        MappingOutbound:
            Type: Simple
        Type: $Operation
EOT
    if ($Additions) {
        foreach my $Addition (@AdditionList) {
            $Operations .= "        $Addition\n";
        }
    }

    $Routes .= <<EOT;
        $Operation:
          RequestMethod:
          - $Method
          Route: $Route
EOT
}

$Template =~ s/__OPERATIONS__/$Operations/g;
$Template =~ s/__ROUTES__/$Routes/g;

open(HANDLE, '>Core.yml');
print HANDLE $Template;
close(HANDLE);