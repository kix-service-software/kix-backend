# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::TicketSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::TicketSearch - API Ticket Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketSearch');

    return $Self;
}

=item Run()

perform TicketSearch Operation. This will return a ticket list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => ''                                # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            Article => [
                {
                },
                {
                }
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my @TicketIndex = $TicketObject->TicketSearch(
        Result     => 'ARRAY',
        Filter     => $Self->{Filter}->{Ticket},
        Limit      => $Self->{Limit}->{Ticket} || $Self->{Filter}->{'__COMMON'},
        Sort       => $Self->{Sort}->{Ticket},
        UserType   => $Self->{Authorization}->{UserType},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( @TicketIndex ) {

        # get already prepared Ticket data from TicketGet operation
        my $TicketGetResult = $Self->ExecOperation(
            OperationType => 'V1::Ticket::TicketGet',
            Data          => {
                TicketID  => join(',', @TicketIndex),
                include   => $Param{Data}->{include},
                expand    => $Param{Data}->{expand},
            }
        );
        if ( !IsHashRefWithData($TicketGetResult) || !$TicketGetResult->{Success} ) {
            return $TicketGetResult;
        }

        my @ResultList = IsArrayRefWithData($TicketGetResult->{Data}->{Ticket}) ? @{$TicketGetResult->{Data}->{Ticket}} : ( $TicketGetResult->{Data}->{Ticket} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Ticket => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Ticket => {},
    );
}

=end Internal:


1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
