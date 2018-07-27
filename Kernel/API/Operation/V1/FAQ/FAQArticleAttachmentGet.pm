# --
# Kernel/API/Operation/V1/FAQ/FAQArticleAttachmentGet.pm - API FAQ Get operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentGet - API FAQCategory Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentGet->new();

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

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::FAQCategory::FAQArticleAttachmentGet');

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

    my @FAQAttachmentData;

    # start loop
    foreach my $FAQAttachmentID ( @{$Param{Data}->{FAQAttachmentID}} ) {

        # get the FAQCategory data
        my %FAQAttachment = $Kernel::OM->Get('Kernel::System::FAQ')->AttachmentGet(
            FileID => $FAQAttachmentID,
            ItemID => $Param{Data}->{FAQArticleID},
            UserID => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%FAQAttachment ) ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No data found for FAQAttachmentID $FAQAttachmentID.",
            );
        }

        # add ID to result
        $FAQAttachment{ID} = $FAQAttachmentID;

        if ( !$Param{Data}->{include}->{Content} ) {
            delete $FAQAttachment{Content};
        }

        # rename ItemID in ArticleID
        $FAQAttachment{ArticleID} = $FAQAttachment{ItemID};
        delete $FAQAttachment{ItemID};
        
        # add
        push(@FAQAttachmentData, \%FAQAttachment);
    }

    if ( scalar(@FAQAttachmentData) == 1 ) {
        return $Self->_Success(
            Attachment => $FAQAttachmentData[0],
        );    
    }

    # return result
    return $Self->_Success(
        Attachment => \@FAQAttachmentData,
    );
}

1;
