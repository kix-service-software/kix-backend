# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQArticleAttachmentSearch - API FAQArticleAttachment Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform FAQArticleAttachmentSearch Operation. This will return a FAQArticleAttachment ID list.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticleID    => 123,
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            FAQAttachment => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform FAQArticleAttachment search
    my @AttachmentList = $Kernel::OM->Get('FAQ')->AttachmentIndex(
        ItemID => $Param{Data}->{FAQArticleID},
        UserID => $Self->{Authorization}->{UserID},
    );

    if ( @AttachmentList ) {

        my @AttachmentIDs;
        foreach my $Attachment ( sort {$a->{FileID} <=> $b->{FileID}} @AttachmentList ) {
            push(@AttachmentIDs, $Attachment->{FileID});
        }

        # get already prepared Article data from ArticleGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::FAQ::FAQArticleAttachmentGet',
            SuppressPermissionErrors => 1,
            Data          => {
                FAQArticleID    => $Param{Data}->{FAQArticleID},
                FAQAttachmentID => join(',', @AttachmentIDs),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Attachment} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Attachment}) ? @{$GetResult->{Data}->{Attachment}} : ( $GetResult->{Data}->{Attachment} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Attachment => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Attachment => [],
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
