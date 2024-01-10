# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Notification::NotificationCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::API::Operation::V1::Notification::Common);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Notification::NotificationCreate - API Notification Create Operation backend

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
        'Notification' => {
            Type     => 'HASH',
            Required => 1
        },
        'Notification::Name' => {
            Required => 1
        },
        'Notification::Data' => {
            Required => 1,
            Type     => 'HASH'
        },
        'Notification::Message' => {
            Required => 1,
            Type     => 'HASH'
        },
    };
}

=item Run()

perform NotificationCreate Operation. This will return the created NotificationID.

    my $Result = $OperationObject->Run(
        Data => {
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
            NotificationID  => '',                      # ID of the created Notification
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Notification parameter
    my $Notification = $Self->_Trim( Data => $Param{Data}->{Notification} );

    # check if filter exists
    my %Exists = $Kernel::OM->Get('NotificationEvent')->NotificationGet( Name => $Notification->{Name} );
    if ( IsHashRefWithData(\%Exists) ) {
        return $Self->_Error( Code => 'Object.AlreadyExists' );
    }

    # validate Notification
    my $Check = $Self->_CheckNotification(
        Notification => $Notification
    );
    if ( !$Check->{Success} )  {
        return $Check;
    }

    # create Notification
    my $NotificationID = $Kernel::OM->Get('NotificationEvent')->NotificationAdd(
        Name    => $Notification->{Name},
        Comment => $Notification->{Comment} || '',
        Data    => $Notification->{Data} || {},
        Filter  => $Notification->{Filter} || undef,
        Message => $Notification->{Message} || {},
        ValidID => $Notification->{ValidID} || 1,
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$NotificationID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Notification, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code         => 'Object.Created',
        NotificationID => $NotificationID,
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
