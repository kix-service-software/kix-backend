# --
# Kernel/API/Operation/FAQ/FAQArticleAttachmentCreate.pm - API FAQAttachment Create operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentCreate - API FAQAttachment Create Operation backend

=head1 SYNOPSIS

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

=item Run()

perform FAQArticleAttachmentCreate Operation. This will return the created FAQAttachmentID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQCategoryID => 123,
            FAQArticleID  => 123,
            FAQAttachment  => {
                Content     => $Content,
                ContentType => 'text/xml',
                Filename    => 'somename.xml',
                Inline      => 1,   (0|1, default 0)
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            FAQAttachmentID  => '',                         # ID of the created FAQAttachment
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webFAQAttachment
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
        Parameters => {
            'FAQAttachment' => {
                Type     => 'HASH',
                Required => 1
            },
            'FAQCategoryID' => {
                Required => 1
            },            
            'FAQArticleID' => {
                Required => 1
            },
            'FAQAttachment::Filename' => {
                Required => 1
            },
            'FAQAttachment::ContentType' => {
                Required => 1
            },
            'FAQAttachment::Content' => {
                Required => 1
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }
    
    # check rw permissions
    my $Permission = $Kernel::OM->Get('Kernel::System::FAQ')->CheckCategoryUserPermission(
        CategoryID => $Param{Data}->{FAQCategoryID},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( $Permission ne 'rw' ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to create tickets in given queue!",
        );
    }

    # isolate and trim FAQAttachment parameter
    my $FAQAttachment = $Self->_Trim(
        Data => $Param{Data}->{FAQAttachment}
    );



    # create FAQAttachment
    my $FAQAttachmentID = $Kernel::OM->Get('Kernel::System::FAQ')->AttachmentAdd(
        ItemID      => $Param{Data}->{FAQArticleID},
        Content     => $FAQAttachment->{Content} || '',
        ContentType => 'text/xml',
        Filename    => $FAQAttachment->{Filename},
        Inline      => $FAQAttachment->{Inline},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$FAQAttachmentID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create FAQArticleAttachment, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        FAQAttachmentID => $FAQAttachmentID,
    );    
}


1;
