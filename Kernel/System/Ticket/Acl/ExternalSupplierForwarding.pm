# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Acl::ExternalSupplierForwarding;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'Config',
);

sub new {
    my ( $Type, %Param ) = @_;

    #allocate new hash for object...
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    #get required params...
    for (qw(Config Acl)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return 1 if !$Param{TicketID};

    my $FwdQueueRef   = $Kernel::OM->Get('Config')->Get('ExternalSupplierForwarding::ForwardQueues');
    my @FwdQueueNames = keys( %{$FwdQueueRef} );

    my $FwdFaxQueueRef = $Kernel::OM->Get('Config')->Get('ExternalSupplierForwarding::ForwardFaxQueues');
    my @FwdFaxQueueNames = keys( %{$FwdFaxQueueRef} );

    my @ExcludedQueues = ( @FwdQueueNames, @FwdFaxQueueNames );

    #---------------------------------------------------------------------------------
    #(0) do not allow move-queue action if forward-queue
    $Param{Acl}->{'500_ExternalSupplierForwarding'} = {
        Properties => {
            Ticket => {
                Queue => \@ExcludedQueues,
            },
        },
        Possible => {
            Action => {
                AgentTicketPrintForwardFax => 1,
            },
        },
    };

    #---------------------------------------------------------------------------------
    $Param{Acl}->{'499_ExternalSupplierForwarding'} = {
        Possible => {
            Action => {
                AgentTicketPrintForwardFax => 0,
            },
        },
    };

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
