# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::StateUpdateOnWebrequestFollowUp;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'DB',
    'Log',
    'State',
    'Ticket',
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
    $Self->{ConfigObject} = $Kernel::OM->Get('Config');
    $Self->{DBObject}     = $Kernel::OM->Get('DB');
    $Self->{LogObject}    = $Kernel::OM->Get('Log');
    $Self->{StateObject}  = $Kernel::OM->Get('State');
    $Self->{TicketObject} = $Kernel::OM->Get('Ticket');
    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # handle only events with given TicketID
    return 1 if ( !$Param{Data}->{TicketID} );

    # check if manual state change is activated in CustomerTicketZoom
    my $CustomerTicketZoomConfig
        = $Self->{ConfigObject}->Get("Ticket::Frontend::CustomerTicketZoom");
    return 1 if ( $CustomerTicketZoomConfig->{State} );

    # check needed stuff
    if ( !$Param{Data}->{ArticleID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need ArticleID!" );
        return;
    }

    # get article data and check article type
    my %ThisArticle = $Self->{TicketObject}->ArticleGet(
        ArticleID => $Param{Data}->{ArticleID},
        UserID    => 1,
    );

    return 1 if ( $ThisArticle{Channel} ne 'note' && $ThisArticle{SenderType} ne 'external');

    # get ticket data and check ticket state
    my %Ticket = $Self->{TicketObject}->TicketGet( TicketID => $Param{Data}->{TicketID} );
    my %State = $Self->{StateObject}->StateGet(
        ID => $Ticket{StateID},
    );

    # get last state update string from ticket history
    return 1 if !$Self->{DBObject}->Prepare(
        SQL =>
            "SELECT name, change_by FROM ticket_history WHERE history_type_id = 27 AND ticket_id = ? ORDER BY change_time DESC LIMIT 1",
        Bind => [ \$Param{Data}->{TicketID} ],
    );

    # get old state and last-changed-by id from ticket history
    my $OldState      = '';
    my $LastChangedBy = 0;
    if ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        if ( defined $Data[0] && $Data[0] =~ m/^\%\%(.*?)\%\%(.*?)\%\%$/ ) {

            # check whether set state equal to ticket state
            $OldState      = $1       if $2 eq $State{TypeName};
            $LastChangedBy = $Data[1] if $2 eq $State{TypeName};
        }
    }

    # check whether last state update done by system and old state like close or pending
    return 1 if ( $LastChangedBy != 1 && $OldState !~ /^(close|pending)/i );

    # set state
    my $State = $Self->{ConfigObject}->Get('PostmasterFollowUpStateClosed') || 'open';

    my $TicketStateWorkflowConfig =
        $Self->{ConfigObject}->Get('TicketStateWorkflow::PostmasterFollowUpState');
    my $TicketStateWorkflowConfigExtended =
        $Self->{ConfigObject}->Get('TicketStateWorkflowExtension::PostmasterFollowUpState');
    if ( defined $TicketStateWorkflowConfigExtended && ref $TicketStateWorkflowConfigExtended eq 'HASH' ) {
        for my $Extension ( sort keys %{$TicketStateWorkflowConfigExtended} ) {
            for my $State ( keys %{ $TicketStateWorkflowConfigExtended->{$Extension} } ) {
                $TicketStateWorkflowConfig->{$State} = $TicketStateWorkflowConfigExtended->{$Extension}->{$State};
            }
        }
    }

    if (
        $TicketStateWorkflowConfig
        &&
        ($TicketStateWorkflowConfig->{ $Ticket{Type}.':::'.$OldState } || $TicketStateWorkflowConfig->{ $OldState })
        )
    {
        $State = $TicketStateWorkflowConfig->{ $Ticket{Type}.':::'.$OldState } || $TicketStateWorkflowConfig->{ $OldState };
    }

    $Self->{TicketObject}->TicketStateSet(
        State    => $State,
        TicketID => $Param{Data}->{TicketID},
        UserID   => 1,
    );
    if ( $Self->{Debug} > 0 ) {
        print "State: $State\n";
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
