# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Number::Random;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
);

sub TicketCreateNumber {
    my $Self = shift;

    # get needed config options
    my $SystemID = $Kernel::OM->Get('Config')->Get('SystemID');

    # random counter
    my $Count = $Kernel::OM->Get('Main')->GenerateRandomString(
        Length     => 10,
        Dictionary => [ 0..9 ],
    );

    # create new ticket number
    my $Tn = $SystemID . $Count;

    # Check ticket number. If exists generate new one!
    my $LoopProtectionCounter = 0;
    while ( $Self->TicketCheckNumber( Tn => $Tn ) ) {

        $LoopProtectionCounter += 1;

        if ( $LoopProtectionCounter >= 16000 ) {

            # loop protection
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "CounterLoopProtection is now $LoopProtectionCounter!"
                    . " Stopped TicketCreateNumber()!",
            );
            return;
        }

        # create new ticket number again
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Tn ($Tn) exists! Creating a new one.",
        );

        $Count = $Kernel::OM->Get('Main')->GenerateRandomString(
            Length     => 10,
            Dictionary => [ 0..9 ],
        );
        $Tn = $SystemID . $Count;
    }

    return $Tn;
}

sub GetTNByString {
    my ( $Self, $String ) = @_;

    if ( !$String ) {
        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get needed config options
    my $CheckSystemID = $ConfigObject->Get('Ticket::NumberGenerator::CheckSystemID');
    my $SystemID      = '';

    if ($CheckSystemID) {
        $SystemID = $ConfigObject->Get('SystemID');
    }

    my $TicketHook        = $ConfigObject->Get('Ticket::Hook') || '';
    my $TicketHookDivider = $ConfigObject->Get('Ticket::HookDivider') || '';

    # check current setting
    if ( $String =~ /\Q$TicketHook$TicketHookDivider\E($SystemID\d{2,20})/i ) {
        return $1;
    }

    # check default setting
    if ( $String =~ /\Q$TicketHook\E:\s{0,2}($SystemID\d{2,20})/i ) {
        return $1;
    }

    return;
}

sub GetTNArrayByString {
    my ( $Self, $String ) = @_;

    if ( !$String ) {
        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get needed config options
    my $CheckSystemID = $ConfigObject->Get('Ticket::NumberGenerator::CheckSystemID');
    my $SystemID      = '';

    if ($CheckSystemID) {
        $SystemID = $ConfigObject->Get('SystemID');
    }

    my $TicketHook        = $ConfigObject->Get('Ticket::Hook') || '';
    my $TicketHookDivider = $ConfigObject->Get('Ticket::HookDivider') || '';

    # check current setting
    if ( $String =~ /\Q$TicketHook$TicketHookDivider\E($SystemID\d{2,20})/i ) {
        my @Result = ( $String =~ /\Q$TicketHook$TicketHookDivider\E($SystemID\d{2,20})/ig );
        return @Result;
    }

    # check default setting
    if ( $String =~ /\Q$TicketHook\E:\s{0,2}($SystemID\d{2,20})/i ) {
        my @Result = ( $String =~ /\Q$TicketHook\E:\s{0,2}($SystemID\d{2,20})/ig );
        return @Result;
    }

    return;
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
