# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentGet - API FAQCategory Get Operation backend

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
        'FAQAttachmentID' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform FAQArticleAttachmentGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticleID    => 123,
            FAQAttachmentID => 123,
        },
    );

    $Result = {
        CategoryID => 2,
        ParentID   => 0,
        Name       => 'My Category',
        Comment    => 'This is my first category.',
        ValidID    => 1,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @AttachmentData;

    # start loop
    foreach my $AttachmentID ( @{$Param{Data}->{FAQAttachmentID}} ) {

        # get the FAQCategory data
        my %Attachment = $Kernel::OM->Get('FAQ')->AttachmentGet(
            FileID => $AttachmentID,
            ItemID => $Param{Data}->{FAQArticleID},
            UserID => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%Attachment ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # add ID to result
        $Attachment{ID} = 0 + $AttachmentID;

        if ( !$Param{Data}->{include}->{Content} ) {
            delete $Attachment{Content};
        }
        else {
            $Attachment{Content} = MIME::Base64::encode_base64($Attachment{Content});
        }

        # rename ItemID to ArticleID
        $Attachment{ArticleID} = 0 + $Attachment{ItemID};
        delete $Attachment{ItemID};

        # rename Filesize to FilesizeRaw
        $Attachment{FilesizeRaw} = 0 + $Attachment{Filesize};

        # human readable file size
        if ( $Attachment{FilesizeRaw} ) {
            if ( $Attachment{FilesizeRaw} > ( 1024 * 1024 ) ) {
                $Attachment{Filesize} = sprintf "%.1f MBytes", ( $Attachment{FilesizeRaw} / ( 1024 * 1024 ) );
            }
            elsif ( $Attachment{FilesizeRaw} > 1024 ) {
                $Attachment{Filesize} = sprintf "%.1f KBytes", ( ( $Attachment{FilesizeRaw} / 1024 ) );
            }
            else {
                $Attachment{Filesize} = $Attachment{FilesizeRaw} . ' Bytes';
            }
        }

        # add
        push(@AttachmentData, \%Attachment);
    }

    if ( scalar(@AttachmentData) == 1 ) {
        return $Self->_Success(
            Attachment => $AttachmentData[0],
        );
    }

    # return result
    return $Self->_Success(
        Attachment => \@AttachmentData,
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
