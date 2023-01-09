# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleAttachmentCreate;

use strict;
use warnings;

use MIME::Base64();

use Kernel::System::VariableCheck qw(:all);

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
                ContentType => 'some content type'                     # optional, fallback
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

    my $TicketObject = $Kernel::OM->Get('Ticket');

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
        ContentType => $Attachment->{ContentType} || $Kernel::OM->Get('Config')->Get('Ticket::Article::Attachment::ContentType::Fallback'),
        Content     => MIME::Base64::decode_base64( $Attachment->{Content} ),
        ArticleID   => $Param{Data}->{ArticleID},
        UserID      => $Self->{Authorization}->{UserID},
        CountAsUpdate => 1
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
