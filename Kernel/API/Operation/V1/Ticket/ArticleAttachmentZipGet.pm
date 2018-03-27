# --
# Kernel/API/Operation/Ticket/ArticleAttachmentZipGet.pm - API User Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleAttachmentZipGet;

use strict;
use warnings;

use MIME::Base64;

use File::Temp qw( tempfile tempdir );
use IO::Compress::Zip qw(:all);

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleAttachmentZipGet - API Ticket attachment zip Operation backend

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
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform ArticleAttachmentZipGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID             => '1',                                           # required 
            ArticleID            => '32',                                          # required
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            Attachment => [
                {
                    Content     => "...",                 # base64 encoded
                    ContentType => "application/zip",
                    Filename    => "Ticket_2017090510000095_Article_82.zip",
                    Type	    => "attachment",
                },
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'TicketID' => {
                Required => 1
            },
            'ArticleID' => {
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

    # check ticket permission
    my $Permission = $Self->CheckAccessPermission(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to access ticket $Param{Data}->{TicketID}.",
        );
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $TicketNumber = $TicketObject->TicketNumberLookup(
        TicketID => $Param{Data}->{TicketID},
    );

    # create zip object
    my $ZipResult;
    my $ZipFilename = "Ticket_" . $TicketNumber . "_Article_" . $Param{Data}->{ArticleID} . ".zip";
    my $ZipObject;

    my @AttachmentList;

    my %Article = $TicketObject->ArticleGet(
        ArticleID     => $Param{Data}->{ArticleID},
        DynamicFields => 0,
    );

    # check if article exists
    if ( !%Article ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Could not get data for article $Param{Data}->{ArticleID}",
        );
    }

    # check if article belongs to the given ticket
    if ( $Article{TicketID} != $Param{Data}->{TicketID} ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Article $Param{Data}->{ArticleID} not found in ticket $Param{Data}->{TicketID}",
        );
    }

    # restrict article sender types
    if ( $Self->{Authorization}->{UserType} eq 'Customer' && $Article{ArticleSenderType} ne 'customer') {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to access article $Param{Data}->{ArticleID}.",
        );
    }

    # get all attachments from article
    my %ArticleAttachments = $TicketObject->ArticleAttachmentIndex(
        ArticleID                  => $Param{Data}->{ArticleID},
        UserID                     => $Self->{Authorization}->{UserID},,
        StripPlainBodyAsAttachment => 1,
    );

    #search attachments
    for my $AttachmentNr ( keys %ArticleAttachments ) {
        
        my %Attachment = $TicketObject->ArticleAttachment(
            ArticleID => $Param{Data}->{ArticleID},
            FileID    => $AttachmentNr,
            UserID   => $Self->{Authorization}->{UserID},
        );

        next if ( $Attachment{Filename} eq 'file-2' );

        if ( !$ZipObject ) {
            $ZipObject = new IO::Compress::Zip(
                \$ZipResult,
                BinModeIn => 1,
                Name      => $Attachment{Filename},
            );

            if ( !$ZipObject ) {
		        return $Self->_Error(
		        	Code    => 'Operation.InternalError',
		            Message => 'Unable to create Zip object.',
		        );
            }

            $ZipObject->print( $Attachment{Content} );
            $ZipObject->flush();
        }
        else {
            $ZipObject->newStream( Name => $Attachment{Filename} );
            $ZipObject->print( $Attachment{Content} );
            $ZipObject->flush();
        }
    }

    if ($ZipObject) {
        $ZipObject->close();
    }

    my %Attachment = (
        Filename    => $ZipFilename,
        ContentType => 'application/zip',
        FilesizeRaw => length $ZipResult,
    );

    if ( $Attachment{FilesizeRaw} > ( 1024 * 1024 ) ) {
        $Attachment{Filesize} = sprintf "%.1f MBytes", ( $Attachment{FilesizeRaw} / ( 1024 * 1024 ) );
    }
    elsif ( $Attachment{FilesizeRaw} > 1024 ) {
        $Attachment{Filesize} = sprintf "%.1f KBytes", ( ( $Attachment{FilesizeRaw} / 1024 ) );
    }
    else {
        $Attachment{Filesize} = $Attachment{FilesizeRaw} . ' Bytes';
    }


    if ( $Param{Data}->{include}->{Content} ) {
        $Attachment{Content} = MIME::Base64::encode_base64($ZipResult),
    }
    
	# output zipped attachments
    return $Self->_Success(
        Attachment => \%Attachment
    );
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
