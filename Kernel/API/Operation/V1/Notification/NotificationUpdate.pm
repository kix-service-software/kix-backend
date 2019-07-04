# --
# Kernel/API/Operation/Notification/NotificationUpdate.pm - API Notification Update operation backend
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Ricky(dot)Kaiser(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Notification::NotificationUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(Kernel::API::Operation::V1::Notification::Common);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Notification::NotificationUpdate - API Notification Update Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
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
        'NotificationID' => {
            Required => 1
        },
        'Notification' => {
            Type     => 'HASH',
            Required => 1
        },
        'Notification::Name' => {
            RequiresValudIfUsed => 1
        },        
    };
}

=item Run()

perform NotificationUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            NotificationID => 123,
            Notification  => {
                Name    => 'some name',          # optional
                Comment => 'some comment',       # optional
                ValidID => 1,                    # optional
                Data    => {                     # optional
                    Key => [ Values ]
                ]
                Message => {                     # optional
                    en => {
                        Subject     => 'Hello',
                        Body        => 'Hello World',
                        ContentType => 'text/plain',
                    },
                    de => {
                        Subject     => 'Hallo',
                        Body        => 'Hallo Welt',
                        ContentType => 'text/plain',
                    },
                }
            }
        }
    );

    $Result = {
        Success           => 1,                       # 0 or 1
        Code              => '',                      # in case of error
        Message           => '',                      # in case of error
        Data              => {                        # result data payload after Operation
            NotificationID  => 123,                     # ID of the updated Notification 
        },
    };
   
=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Notification parameter
    my $Notification = $Self->_Trim( Data => $Param{Data}->{Notification} );

    # check if another Notification with name already exists
    my %Exists = $Kernel::OM->Get('Kernel::System::NotificationEvent')->NotificationGet(
        Name => $Notification->{Name},
    );
    if ( IsHashRefWithData(\%Exists) && $Exists{ID} != $Param{Data}->{NotificationID} ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Another Notification with the same name already exists."
        );
    }

    # check if Notification exists
    my %NotificationData = $Kernel::OM->Get('Kernel::System::NotificationEvent')->NotificationGet(
        ID => $Param{Data}->{NotificationID},
    );
    if ( !IsHashRefWithData(\%NotificationData) ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
        );
    }

    # validate Notification
    my $Check = $Self->_CheckNotification(
        Notification => $Notification
    );
    if ( !$Check->{Success} )  {
        return $Check;
    }

    # update Notification
    my $Success = $Kernel::OM->Get('Kernel::System::NotificationEvent')->NotificationUpdate(
        ID             => $Param{Data}->{NotificationID},
        Name           => $Notification->{Name} || $NotificationData{Name},
        Comment        => exists $Notification->{Comment} ? $Notification->{Comment} : $NotificationData{Comment},
        Data           => $Notification->{Data} || $NotificationData{Data},
        Message        => $Notification->{Message} || $NotificationData{Message},
        ValidID        => $Notification->{ValidID} || $NotificationData{ValidID},
        UserID         => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error( Code => 'Object.UnableToUpdate', );
    }

    # return result
    return $Self->_Success( NotificationID => $NotificationData{ID} );
}

1;
