# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::WatcherDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::WatcherDelete - API WatcherDelete Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::WatcherDelete');

    return $Self;
}

=item Run()

perform WatcherDelete Operation. This will return the deleted WatcherUserID.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID    => 123,                                  # required
            WatcherID   => 1                                     # required
        },
    );

    $Result = {
        Message    => '',                      # in case of error
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
            'WatcherID' => {
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

    # check delete permission
    my $Permission = $Self->CheckWritePermission(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to delete Watcher.",
        );
    }

    # check if Watcher exists
    my %Watchers = $Kernel::OM->Get('Kernel::System::Ticket')->TicketWatchGet(
        TicketID => $Param{Data}->{TicketID},
    );
    
    if ( !$Watchers{$Param{Data}->{WatcherID}} ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Watcher $Param{Data}->{WatcherID} not found in ticket $Param{Data}->{TicketID}",
        );
    }

    my $Success = $Kernel::OM->Get('Kernel::System::Ticket')->TicketWatchUnsubscribe(
        TicketID    => $Param{Data}->{TicketID},
        WatchUserID => $Param{Data}->{WatcherID},
        UserID   	=> $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToDelete',
            Message => 'Unable to to delete Watcher, please contact system administrator!',
        );
    }

    # return result
    return $Self->_Success(
        WatcherID => $Param{Data}->{WatcherID},
    );
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
