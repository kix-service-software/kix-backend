# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Validator::AttachmentsValidator;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Validator::Common
);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Validator::AttachmentsValidator - validator module

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Validate()

validate given data attribute

    my $Result = $ValidatorObject->Validate(
        Attribute => '...',                     # required
        Data      => {                          # required but may be empty
            ...
        }
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
    };

=cut

sub Validate {
    my ( $Self, %Param ) = @_;

    # check params
    if ( !$Param{Attribute} ) {
        return $Self->_Error(
            Code    => 'Validator.InternalError',
            Message => 'Got no Attribute!',
        );
    }

    my $Found;
    if ( $Param{Attribute} eq 'Attachments' && IsHashRefWithData($Param{Data}->{$Param{Attribute}}) ) {
        my $ConfigObject = $Kernel::OM->Get('Config');

        my $ForbiddenExtensions   = $ConfigObject->Get('FileUpload::ForbiddenExtensions');
        my $ForbiddenContentTypes = $ConfigObject->Get('FileUpload::ForbiddenContentTypes');
        my $AllowedExtensions     = $ConfigObject->Get('FileUpload::AllowedExtensions');
        my $AllowedContentTypes   = $ConfigObject->Get('FileUpload::AllowedContentTypes');

        $Found = 1;

        my $Attachment = $Param{Data}->{$Param{Attribute}};
        foreach my $Needed ( qw(Filename) ) {
            if ( !$Attachment->{$Needed} ) {
                $Found = 0;
                last;
            }

            # check allowed size
            if ( $Attachment->{Content} && bytes::length(MIME::Base64::decode_base64($Attachment->{Content})) > $ConfigObject->Get('FileUpload::MaxAllowedSize') ) {
                return $Self->_Error(
                    Code    => 'Validator.Failed',
                    Message => "Size of attachment exceeds maximum allowed size (attachment: $Attachment->{Filename})!",
                );
            }

            # check forbidden file extension
            if ( $ForbiddenExtensions && $Attachment->{Filename} =~ /$ForbiddenExtensions/ ) {
                return $Self->_Error(
                    Code    => 'Validator.Failed',
                    Message => "Forbidden file type (attachment: $Attachment->{Filename})!",
                );
            }

            # check forbidden content type
            if ( $ForbiddenContentTypes && $Attachment->{ContentType} =~ /$ForbiddenContentTypes/ ) {
                return $Self->_Error(
                    Code    => 'Validator.Failed',
                    Message => "Forbidden content type (attachment: $Attachment->{Filename})!",
                );
            }

            # check allowed file extension
            if ( $AllowedExtensions && $Attachment->{Filename} !~ /$AllowedExtensions/ ) {
                # check allowed content type as fallback
                if ( $AllowedContentTypes && $Attachment->{ContentType} !~ /$AllowedContentTypes/ ) {
                    return $Self->_Error(
                        Code    => 'Validator.Failed',
                        Message => "Content type not allowed (attachment: $Attachment->{Filename})!",
                    );
                }
                elsif ( !$AllowedContentTypes ) {
                    return $Self->_Error(
                        Code    => 'Validator.Failed',
                        Message => "File type not allowed (attachment: $Attachment->{Filename})!",
                    );
                }
            }

            # check allowed content type
            if ( $AllowedContentTypes && $Attachment->{ContentType} !~ /$AllowedContentTypes/ ) {
                return $Self->_Error(
                    Code    => 'Validator.Failed',
                    Message => "File type not allowed (attachment: $Attachment->{Filename})!",
                );
            }
        }
    }
    else {
        return $Self->_Error(
            Code    => 'Validator.UnknownAttribute',
            Message => "Cannot validate attribute $Param{Attribute}!",
        );
    }

    if ( !$Found ) {
        return $Self->_Error(
            Code    => 'Validator.Failed',
            Message => "Validation of attribute $Param{Attribute} failed (wrong structure or missing required values) !",
        );
    }

    return $Self->_Success();
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
