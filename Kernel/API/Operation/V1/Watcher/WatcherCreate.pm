# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Watcher::WatcherCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Watcher::WatcherCreate - API WatcherCreate Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketWatcherCreate');

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
        'Watcher::Object' => {
            Required => 1
        },
        'Watcher::ObjectID' => {
            Required => 1
        },
        'Watcher::UserID' => {
            Required => 1
        },
    }
}

=item Run()

perform WatcherCreate Operation. This will return the created WatcherItemID

    my $Result = $OperationObject->Run(
        Data => {
            Watcher => {                                     # required
                Object   => 'Ticket',                        # required
                ObjectID => 123,                             # required
                UserID   => 123,                             # required
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            WatcherID => 1
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Watcher parameter
    my $Watcher = $Self->_Trim(
        Data => $Param{Data}->{Watcher}
    );

    # check if Watcher exists
    my @WatcherList = $Kernel::OM->Get('Kernel::System::Watcher')->WatcherList(
        Object   => $Watcher->{Object},
        ObjectID => $Watcher->{ObjectID},
    );
    my %Watchers = map { $_->{UserID} => $_ } @WatcherList;
    
    if ( $Watchers{$Watcher->{UserID}} ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create Watcher. Watcher already exists.",
        );
    }
    
    my $WatcherID = $Kernel::OM->Get('Kernel::System::Watcher')->WatcherAdd(
        Object      => $Watcher->{Object},
        ObjectID    => $Watcher->{ObjectID},
        WatchUserID => $Watcher->{UserID},
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$WatcherID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Watcher, please contact the system administrator',
        );
    }

    return $Self->_Success(
        Code      => 'Object.Created',
        WatcherID => $WatcherID,
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
