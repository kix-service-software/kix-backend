# --
# Kernel/API/Operation/Ticket/WatcherSearch.pm - API User Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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
        Data       => $Param{Data},
        Parameters => {
            'TicketID' => {
                Required => 1
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # check ticket permission
    my $Permission = $Self->CheckAccessPermission(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to access ticket $Param{Data}->{TicketID}.",
        );
    }

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
