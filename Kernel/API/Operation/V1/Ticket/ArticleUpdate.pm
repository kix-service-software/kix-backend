# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleUpdate - API Ticket ArticleUpdate Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ArticleUpdate');

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
        'ArticleID' => {
            Required => 1
        },
        'Article' => {
            Type     => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform ArticleUpdate Operation. This will return the updated ArticleID

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 123,                                                  # required
            ArticleID => 123,                                                  # required
            Article  => {                                                      # required
                Subject                         => 'some subject',             # required
                Body                            => 'some body'                 # required
                ContentType                     => 'some content type',        # ContentType or MimeType and Charset is requieed
                MimeType                        => 'some mime type',           
                Charset                         => 'some charset',           

                IncomingTime                    => 'YYYY-MM-DD HH24:MI:SS',    # optional
                TicketID                        => 123,                        # optional, used to move the article to another ticket
                ChannelID                       => 123,                        # optional
                Channel                         => 'some channel name',        # optional
                CustomerVisible                 => 0|1,                        # optional
                SenderTypeID                    => 123,                        # optional
                SenderType                      => 'some sender type name',    # optional
                From                            => 'some from string',         # optional
                TimeUnits                       => 123,                        # optional
                DynamicFields => [                                             # optional
                    {
                        Name   => 'some name',                                          
                        Value  => $Value,                                      # value type depends on the dynamic field
                    },
                    # ...
                ],
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ArticleID => 123,                       # ID of changed article
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Article parameter
    my $Article = $Self->_Trim(
        Data => $Param{Data}->{Article}
    );

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Article = $TicketObject->ArticleGet(
        ArticleID     => $Param{Data}->{ArticleID},
        DynamicFields => 0,
    );

    # check if article exists
    if ( !%Article ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if article belongs to the given ticket
    if ( $Article{TicketID} != $Param{Data}->{TicketID} ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # everything is ok, let's update the article
    return $Self->_ArticleUpdate(
        TicketID  => $Param{Data}->{TicketID},
        ArticleID => $Param{Data}->{ArticleID},
        Article   => $Article,
        UserID    => $Self->{Authorization}->{UserID},
    );
}

=begin Internal:

=item _ArticleUpdate()

update a ticket with its dynamic fields

    my $Response = $OperationObject->_ArticleUpdate(
        TicketID          => 123,
        ArticleID         => 123,
        Article           => { },                # all article parameters
        UserID            => 123,
    );

    returns:

    $Response = {
        Success => 1,                           # if everything is OK
        Data => {
            ArticleID     => 123,
        }
    }

    $Response = {
        Success      => 0,                      # if unexpected error
        Code         => '...'
        Message      => '...',
    }

=cut

sub _ArticleUpdate {
    my ( $Self, %Param ) = @_;

    my $Article = $Param{Article};

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # update normal attributes
    foreach my $Attribute ( qw(Subject Body From ChannelID Channel CustomerVisible SenderType SenderTypeID) ) {
        next if !defined $Article->{$Attribute};

        my $Success = $TicketObject->ArticleUpdate(
            ArticleID => $Param{ArticleID},
            Key       => $Attribute,
            Value     => $Article->{$Attribute},
            UserID    => $Param{UserID},
            TicketID  => $Param{TicketID},
        );

        if ( !$Success ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to update article attribute $Attribute",
            );
        }
    }

    # check if we have to move the article
    if ( IsStringWithData($Article->{TicketID}) && $Article->{TicketID} != $Param{TicketID} ) {
        my $Success = $TicketObject->ArticleMove(
            TicketID  => $Article->{TicketID},
            ArticleID => $Param{ArticleID},
            UserID    => $Param{UserID},
        );
        if ( !$Success ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to move article",
            );
        }
    }

    # check if we have to update the incoming time
    if ( IsStringWithData($Article->{IncomingTime}) ) {
        my $Success = $TicketObject->ArticleMove(
            TicketID  => $Article->{TicketID},
            ArticleID => $Param{ArticleID},
            UserID    => $Param{UserID},
        );
        if ( !$Success ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to update article",
            );
        }
    }

    # check if we have to update the TimeUnits
    if ( IsStringWithData($Article->{TimeUnits}) ) {
        # delete old time account values
        my $DeleteSuccess = $TicketObject->TicketAccountedTimeDelete(
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
        );

        if ( !$DeleteSuccess ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to update article",
            );
        }

        # set new time account value
        my $UpdateSuccess = $TicketObject->TicketAccountTime(
            TicketID  => $Param{TicketID},
            ArticleID => $Param{ArticleID},
            TimeUnit  => $Article->{TimeUnits},
            UserID    => $Param{UserID},
        );

        if ( !$UpdateSuccess ) {
            return $Self->_Error(
                Code         => 'Object.UnableToUpdate',
                Message      => "Unable to update article",
            );
        }
    }

    # set dynamic fields
    if ( IsArrayRefWithData($Article->{DynamicFields}) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{$Article->{DynamicFields}} ) {
            my $Result = $Self->SetDynamicFieldValue(
                %{$DynamicField},
                ArticleID => $Param{ArticleID},
                UserID    => $Param{UserID},
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    Code         => 'Object.UnableToUpdate',
                    Message      => "Dynamic Field $DynamicField->{Name} could not be set ($Result->{Message})",
                );
            }
        }
    }

    return $Self->_Success(
        ArticleID => $Param{ArticleID},
    );
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
