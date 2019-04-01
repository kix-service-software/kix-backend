# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleAttachmentCreate;

use strict;
use warnings;

use MIME::Base64();

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleAttachmentCreate - API Operation backend

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
        'ArticleID' => {
            Required => 1
        },
        'Attachment' => {
            Type     => 'HASH',
            Required => 1
        },
        'Attachment::ContentType' => {
            Required => 1
        },
        'Attachment::Filename' => {
            Required => 1
        },
        'Attachment::Content' => {
            Required => 1
        },
    }
}

=item Run()

perform ArticleAttachmentCreate Operation. This will return the created AttachmentID.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID   => 123,                                         # required
            Article    => 123,                                         # required
            Attachment => {                                            # required
                Content     => 'content'                               # required, base64 encoded
                ContentType => 'some content type'                     # required
                Filename    => 'some fine name'                        # required
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ArticleID   => 123,                     # ID of created article
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Attachment parameter
    my $Attachment = $Self->_Trim(
        Data => $Param{Data}->{Attachment}
    );

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{Data}->{TicketID},
    );

    if ( !%Ticket ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
            Message => "Ticket $Param{Data}->{TicketID} not found!",
        );
    }

    # get article data
    my %Article = $TicketObject->ArticleGet(
        ArticleID => $Param{Data}->{ArticleID},
    );

    if ( !%Article ) {
        return $Self->_Error(
            Code    => 'ParentObject.NotFound',
            Message => "Article $Param{Data}->{ArticleID} not found!",
        );
    }
    
    # check if article belongs to the given ticket
    if ( $Article{TicketID} != $Param{Data}->{TicketID} ) {
        return $Self->_Error(
            Code    => 'ParentObject.NotFound',
            Message => "Article $Param{Data}->{ArticleID} not found in ticket $Param{Data}->{TicketID}",
        );
    }
    
    # check attachment values
    my $AttachmentCheck = $Self->_CheckAttachment( 
        Attachment => $Attachment 
    );

    if ( !$AttachmentCheck->{Success} ) {
        return $Self->_Error(
            %{$AttachmentCheck},
        );
    }

    # create the new attachment
    my $AttachmentID = $TicketObject->ArticleWriteAttachment(
        %{$Attachment},
        Content    => MIME::Base64::decode_base64( $Attachment->{Content} ),
        ArticleID  => $Param{Data}->{ArticleID},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$AttachmentID ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    return $Self->_Success(
        Code         => 'Object.Created',
        AttachmentID => $AttachmentID,
    );
}

=begin Internal:

1;

=end Internal:




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
