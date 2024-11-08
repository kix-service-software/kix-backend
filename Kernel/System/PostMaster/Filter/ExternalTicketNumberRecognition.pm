# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::ExternalTicketNumberRecognition;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
    'State',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # checking mandatory configuration options
    for my $Option (qw(NumberRegExp DynamicFieldName SenderType Channel)) {
        if ( !defined $Param{JobConfig}->{$Option} && !$Param{JobConfig}->{$Option} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Missing configuration for $Option for postmaster filter.",
            );
            return 1;
        }
    }

    if ( $Self->{Debug} >= 1 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => "starting Filter $Param{JobConfig}->{Name}",
        );
    }

    # check if sender is of interest
    return 1 if !$Param{GetParam}->{From};

    if ( defined $Param{JobConfig}->{FromAddressRegExp} && $Param{JobConfig}->{FromAddressRegExp} )
    {

        if ( $Param{GetParam}->{From} !~ /$Param{JobConfig}->{FromAddressRegExp}/i ) {
            return 1;
        }
    }

    # search in the subject
    if ( $Param{JobConfig}->{SearchInSubject} ) {

        # try to get external ticket number from email subject
        my @SubjectLines = split /\n/, $Param{GetParam}->{Subject};
        LINE:
        for my $Line (@SubjectLines) {
            if ( $Line =~ m{ $Param{JobConfig}->{NumberRegExp} }msx ) {
                $Self->{Number} = $1;
                last LINE;
            }
        }

        if ( $Self->{Number} ) {
            if ( $Self->{Debug} >= 1 ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message  => "Found number: $Self->{Number} in subject",
                );
            }
        }
        else {
            if ( $Self->{Debug} >= 1 ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message  => "No number found in subject: '" . join( '', @SubjectLines ) . "'",
                );
            }
        }
    }

    # search in the body
    if ( $Param{JobConfig}->{SearchInBody} ) {

        # split the body into separate lines
        my @BodyLines = split /\n/, $Param{GetParam}->{Body};

        # traverse lines and return first match
        LINE:
        for my $Line (@BodyLines) {
            if ( $Line =~ m{ $Param{JobConfig}->{NumberRegExp} }msx ) {

                # get the found element value
                $Self->{Number} = $1;
                last LINE;
            }
        }
    }

    # we need to have found an external number to proceed.
    if ( !$Self->{Number} ) {
        if ( $Self->{Debug} >= 1 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => 'Could not find external ticket number => Ignoring',
            );
        }
        return 1;
    }
    else {
        if ( $Self->{Debug} >= 1 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Found number $Self->{Number}",
            );
        }
    }

    # is there a ticket for this ticket number?
    my %Query = (
        Result => 'ARRAY',
        Limit  => 1,
        UserID => 1,
        Search => {
            'AND' => []
        },
    );

    # check if we should only find the ticket number in tickets with a given state type
    if ( defined $Param{JobConfig}->{TicketStateTypes} && $Param{JobConfig}->{TicketStateTypes} ) {

        my @StateTypes;

        # if StateTypes contains semicolons, use that for split,
        # otherwise split on spaces (for compat)
        if ( $Param{JobConfig}->{TicketStateTypes} =~ m{;} ) {
            @StateTypes = split ';', $Param{JobConfig}->{TicketStateTypes};
        }
        else {
            @StateTypes = split ' ', $Param{JobConfig}->{TicketStateTypes};
        }

        my @StateTypeIDs = ();
        STATETYPE:
        for my $StateType (@StateTypes) {

            next STATETYPE if !$StateType;

            my $StateTypeID = $Kernel::OM->Get('State')->StateTypeLookup(
                StateType => $StateType,
            );

            if ($StateTypeID) {
                push( @StateTypeIDs, $StateTypeID );
            }
        }

        push( @{ $Query{Search}->{AND} }, {
                Field    => 'StateTypeID',
                Value    => \@StateTypeIDs,
                Operator => 'IN',
            }
        );
    }

    # dynamic field search condition
    push( @{ $Query{Search}->{AND} }, {
            Field    => 'DynamicField_' . $Param{JobConfig}->{'DynamicFieldName'},
            Value    => $Self->{Number},
            Operator => 'EQ',
        }
    );

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # search tickets
    my @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        %Query,
        ObjectType => 'Ticket',
        UserID     => 1,
        UserType   => 'Agent'
    );

    # get the first and only ticket id
    my $TicketID = shift @TicketIDs;

    # ok, found ticket to deal with
    if ($TicketID) {

        # get ticket number
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $TicketID,
            UserID   => 1,
        );

        if ( $Self->{Debug} >= 1 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message =>
                    "Found ticket $TicketNumber open for external number $Self->{Number}. Updating.",
            );
        }

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Config');

        # build subject
        my $TicketHook        = $ConfigObject->Get('Ticket::Hook') || '';
        my $TicketHookDivider = $ConfigObject->Get('Ticket::HookDivider') || '';
        $Param{GetParam}->{Subject} .= " [$TicketHook$TicketHookDivider$TicketNumber]";

        # set sender type and article type.
        $Param{GetParam}->{'X-KIX-FollowUp-SenderType'}  = $Param{JobConfig}->{SenderType};
        $Param{GetParam}->{'X-KIX-FollowUp-Channel'} = $Param{JobConfig}->{Channel};
        $Param{GetParam}->{'X-KIX-FollowUp-CustomerVisible'} = $Param{JobConfig}->{VisibleForCustomer};

        # also set these parameters. It could be that the follow up is rejected by Reject.pm
        #   (follow-ups not allowed), but the original article will still be attached to the ticket.
        $Param{GetParam}->{'X-KIX-SenderType'}  = $Param{JobConfig}->{SenderType};
        $Param{GetParam}->{'X-KIX-Channel'} = $Param{JobConfig}->{Channel};
        $Param{GetParam}->{'X-KIX-CustomerVisible'} = $Param{JobConfig}->{VisibleForCustomer};
    }
    else {
        if ( $Self->{Debug} >= 1 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Creating new ticket for external ticket $Self->{Number}",
            );
        }

        # get the dynamic field name and description from JobConfig, set as headers
        my $TicketDynamicFieldName = $Param{JobConfig}->{'DynamicFieldName'};
        $Param{GetParam}->{ 'X-KIX-DynamicField-' . $TicketDynamicFieldName } = $Self->{Number};

        # set sender type and article type
        $Param{GetParam}->{'X-KIX-SenderType'}  = $Param{JobConfig}->{SenderType};
        $Param{GetParam}->{'X-KIX-Channel'} = $Param{JobConfig}->{Channel};
        $Param{GetParam}->{'X-KIX-CustomerVisible'} = $Param{JobConfig}->{VisibleForCustomer};
    }

    return 1;
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
