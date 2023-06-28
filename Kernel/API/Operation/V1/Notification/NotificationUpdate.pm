# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Notification::NotificationUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::API::Operation::V1::Notification::Common);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Notification::NotificationUpdate - API Notification Update Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

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
    my %Exists = $Kernel::OM->Get('NotificationEvent')->NotificationGet(
        Name => $Notification->{Name},
    );
    if ( IsHashRefWithData(\%Exists) && $Exists{ID} != $Param{Data}->{NotificationID} ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Another Notification with the same name already exists."
        );
    }

    # check if Notification exists
    my %NotificationData = $Kernel::OM->Get('NotificationEvent')->NotificationGet(
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
    my $Success = $Kernel::OM->Get('NotificationEvent')->NotificationUpdate(
        ID             => $Param{Data}->{NotificationID},
        Name           => $Notification->{Name} || $NotificationData{Name},
        Comment        => exists $Notification->{Comment} ? $Notification->{Comment} : $NotificationData{Comment},
        Data           => $Notification->{Data} || $NotificationData{Data},
        Filter         => $Notification->{Filter} || $NotificationData{Filter},
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

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
