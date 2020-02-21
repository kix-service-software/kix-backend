# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::TicketCreateChecklistFromTicketTemplate;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Contact',
    'Kernel::System::Link',
    'Kernel::System::Log',
    'Kernel::System::SystemAddress',
    'Kernel::System::State',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{ParamObject}  = $Kernel::OM->Get('Kernel::System::Web::Request');
    $Self->{TicketObject} = $Kernel::OM->Get('Kernel::System::Ticket');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check required params...
    for my $CurrKey (qw(Event Data)) {
        if ( !$Param{$CurrKey} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $CurrKey!"
            );
            return;
        }
    }

    # get data
    my %Data = %{ $Param{Data} };
    $Param{TicketID} = $Data{TicketID};
    $Param{DefaultSet} = $Data{TicketTemplate} || $Self->{ParamObject}->GetParam( Param => 'DefaultSet' ) || '';

    # get ticket template
    if ( $Param{DefaultSet} ) {

        # get checklist config
        my $KIXSidebarChecklistConfig
            = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::KIXSidebarChecklist');

        my %TicketTemplateData = $Self->{TicketObject}->TicketTemplateGet(
            ID => $Param{DefaultSet}
        );
        my $KIXSidebarChecklistStrg = $TicketTemplateData{KIXSidebarChecklistTextField};

        # insert checklist data for this ticket id
        if ( defined $KIXSidebarChecklistStrg && $KIXSidebarChecklistStrg ) {
            foreach my $Item (split(/\n/, $KIXSidebarChecklistStrg)) {
                my $ItemID = $Self->{TicketObject}->TicketChecklistItemAdd(
                    TicketID => $Param{TicketID},
                    Text     => $Item,
                    State    => $KIXSidebarChecklistConfig->{DefaultCreateState} || 'open',
                );
            }
        }
    }

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
