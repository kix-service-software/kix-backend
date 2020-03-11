# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::HistorySearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Ticket::HistorySearch - API Ticket History Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'TicketID' => {
            Required => 1
        },
    }
}

=item Run()

perform HistorySearch Operation. This will return a history list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            History => [
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

    # get history list
    my @HistoryList = $Kernel::OM->Get('Kernel::System::Ticket')->HistoryGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
    );
    my %HistoryHash = map { $_->{HistoryID} => $_ } @HistoryList;

    if ( @HistoryList ) {

        # get already prepared history data from HistoryGet operation
        my $HistoryGetResult = $Self->ExecOperation(
            OperationType            => 'V1::Ticket::HistoryGet',
            SuppressPermissionErrors => 1,
            Data          => {
                TicketID  => $Param{Data}->{TicketID},
                HistoryID => join(',', sort keys %HistoryHash),
            }
        );
        if ( !IsHashRefWithData($HistoryGetResult) || !$HistoryGetResult->{Success} ) {
            return $HistoryGetResult;
        }

        my @ResultList = IsArrayRef($HistoryGetResult->{Data}->{History}) ? @{$HistoryGetResult->{Data}->{History}} : ( $HistoryGetResult->{Data}->{History} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                History => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        History => [],
    );
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
