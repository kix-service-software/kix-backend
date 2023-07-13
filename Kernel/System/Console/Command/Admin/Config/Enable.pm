# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::Config::Enable;

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

    $Self->Description('Change a configuration setting.');
    $Self->AddArgument(
        Name        => 'option',
        Description => "Specify which config setting should be enabled.",
        HasValue    => 1,
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get option
    my %OptionData = $Kernel::OM->Get('SysConfig')->OptionGet(
        Name => $Self->GetArgument('option'),
    );
    if ( !IsHashRefWithData(\%OptionData) ) {
        $Self->PrintError("Option does not exist!");
        return $Self->ExitCodeError();
    }

    my $Success = $Kernel::OM->Get('SysConfig')->OptionUpdate(
        %OptionData,
        ValidID => 1,
        UserID  => 1
    );
    if ( !$Success ) {
        $Self->PrintError("Unable to enable option!");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");

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
