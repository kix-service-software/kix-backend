# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Config::Dump;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Dump configuration settings.');
    $Self->AddArgument(
        Name        => 'name',
        Description => "Specify which config setting should be dumped. The wildcard '*' can be used.",
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Key = $Self->GetArgument('name');
    chomp $Key;
    $Key =~ s/\*/.*?/g;

    my @Options = sort keys %{$Kernel::OM->Get('Config')->{Config} || {}};

    foreach my $Option ( @Options ) {
        next if $Option !~ /^$Key$/;

        my $Value = $Kernel::OM->Get('Config')->Get($Option);

        if ( !defined $Value ) {
            $Self->PrintError("The config setting $Key could not be found.");
            return $Self->ExitCodeError();
        }

        if ( IsHashRef($Value) || IsArrayRef($Value) ) {
            my $Dump = $Kernel::OM->Get('Main')->Dump($Value);
            $Dump =~ s/^(.*?) = //g;
            print "$Option = ".$Dump;
        }
        else {
            print "$Option = $Value\n";
        }
    }

    return $Self->ExitCodeOk();
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
