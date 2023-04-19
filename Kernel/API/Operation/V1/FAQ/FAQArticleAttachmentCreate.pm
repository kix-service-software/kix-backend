# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentCreate;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentCreate - API FAQAttachment Create Operation backend

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
        'FAQArticleID' => {
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

perform FAQArticleAttachmentCreate Operation. This will return the created FAQAttachmentID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticleID  => 123,
            Attachment  => {
                Content     => $Content,                    # required, base64 encoded
                ContentType => 'text/xml',                  # optional
                Filename    => 'somename.xml',              # required
                Inline      => 1,                           # (0|1, default 0)
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            FAQAttachmentID  => '',                 # ID of the created Attachment
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Attachment parameter
    my $Attachment = $Self->_Trim(
        Data => $Param{Data}->{Attachment}
    );

    # create Attachment
    my $AttachmentID = $Kernel::OM->Get('FAQ')->AttachmentAdd(
        ItemID      => $Param{Data}->{FAQArticleID},
        Content     => MIME::Base64::decode_base64($Attachment->{Content}),
        ContentType => $Attachment->{ContentType} || $Kernel::OM->Get('Config')->Get('FAQ::Attachment::ContentType::Fallback'),
        Filename    => $Attachment->{Filename},
        Inline      => $Attachment->{Inline} || 0,
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$AttachmentID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create FAQArticle attachment, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code            => 'Object.Created',
        FAQAttachmentID => $AttachmentID,
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
