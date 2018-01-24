# --# --
# Kernel/API/Operation/FAQ/FAQArticleAttachmentSearch.pm - API FAQArticleAttachment Search operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::FAQ::FAQArticleAttachmentSearch - API FAQArticleAttachment Search Operation backend

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
    for my $Needed (qw(DebuggerObject WebserviceID)) {
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

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # perform FAQArticleAttachment search
    my @AttachmentList = $Kernel::OM->Get('Kernel::System::FAQ')->AttachmentIndex(
        ItemID => $Param{Data}->{FAQArticleID},
        UserID => $Self->{Authorization}->{UserID},
    );

    if ( @AttachmentIndex ) {

        my @AttachmentIDs;
        foreach my $Attachment ( sort {$a->{FileID} <=> $b->{FileID}} @AttachmentIndex ) {
            push(@AttachmentIDs, $Attachment->{FileID});
        }
        
        # get already prepared Article data from ArticleGet operation
        my $AttachmentGetResult = $Self->ExecOperation(
            OperationType => 'V1::FAQ::FAQArticleAttachmentGet',
            Data          => {
                FAQArticleID    => $Param{Data}->{FAQArticleID},
                FAQAttachmentID => join(',', @AttachmentIDs),
            }
        );
        if ( !IsHashRefWithData($AttachmentGetResult) || !$AttachmentGetResult->{Success} ) {
            return $AttachmentGetResult;
        }

        my @ResultList = IsArrayRefWithData($AttachmentGetResult->{Data}->{Attachment}) ? @{$AttachmentGetResult->{Data}->{Attachment}} : ( $AttachmentGetResult->{Data}->{Attachment} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                FAQAttachment => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        FAQAttachment => [],
    );
}


1;