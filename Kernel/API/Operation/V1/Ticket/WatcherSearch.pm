# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::WatcherSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Ticket::WatcherSearch - API WatcherSearch Operation backend

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

perform WatchenSearch Operation. This will return a Watcher item list.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 1'                                             # required 
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                                    # In case of an error
        Data         => {
            Watcher => [
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

    my %Watcher = $Kernel::OM->Get('Kernel::System::Ticket')->TicketWatchGet(
        TicketID => $Param{Data}->{TicketID},
    );

    # get already prepared Watcher data from WatcherGet operation
    if ( IsHashRefWithData(\%Watcher) ) {     
        my $WatcherResult = $Self->ExecOperation(
            OperationType => 'V1::Ticket::WatcherGet',
            Data      => {
                WatcherID => join(',', sort keys %Watcher),
                TicketID  => $Param{Data}->{TicketID},
            }
        );    

        if ( !IsHashRefWithData($WatcherResult) || !$WatcherResult->{Success} ) {       	
            return $WatcherResult;
        }

        my @WatcherList = IsArrayRefWithData($WatcherResult->{Data}->{Watcher}) ? @{$WatcherResult->{Data}->{Watcher}} : ( $WatcherResult->{Data}->{Watcher} );

        if ( IsArrayRefWithData(\@WatcherList) ) {
            return $Self->_Success(
                Watcher => \@WatcherList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Watcher => [],
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
