# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::SupportData::Collect;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Main',
    'SupportData',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->{SupportDataConfig} = $Kernel::OM->Get('Config')->Get('SupportData');

    $Self->Description('Collect support data.');
    $Self->AddOption(
        Name        => 'send',
        Description => 'Send the collected support data to '.($Self->{SupportDataConfig}->{SendTo} || '<<no email address configured>>'),
        Required    => 0,
        HasValue    => 0,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $DoSend = $Self->GetOption('send');

    $Self->Print("<yellow>Collecting support data...</yellow>\n");
    my %SupportData = $Kernel::OM->Get('SupportData')->SupportDataCollect();
    $Self->Print("\n".$Kernel::OM->Get('Main')->Dump(\%SupportData)."\n");

    if ( $DoSend ) {
        if ( $Self->{SupportDataConfig}->{SendTo} ) {
            $Self->Print("<yellow>Sending support data...</yellow>\n");
            my $Success = $Kernel::OM->Get('SupportData')->SupportDataSend(SupportData => \%SupportData);
            if ( !$Success ) {
                $Self->PrintError("Can't send support data.");
                return $Self->ExitCodeError();
            }
        }
        else {
            $Self->PrintError("No recipient for suppport data configured!");
            return $Self->ExitCodeError();
        }
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
