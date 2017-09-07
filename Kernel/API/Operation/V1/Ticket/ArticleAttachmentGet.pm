# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleAttachmentGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleAttachmentGet - API Ticket Get Operation backend

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

perform ArticleAttachmentGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID             => '1',                                           # required 
            ArticleID            => '32',                                          # required, could be coma separated IDs or an Array
            AttachmentID         => 'Article::32::1',                              # required, could be coma separated IDs or an Array
            include              => '...',                                         # Optional, 0 as default. Include additional objects
                                                                                   # (supported: Content)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            Attachment => [
                {
                    AttachmentID      => 123
                    ContentAlternative => "",
                    ContentID          => "",
                    ContentType        => "application/pdf",
                    Filename           => "StdAttachment-Test1.pdf",
                    Filesize           => "4.6 KBytes",
                    FilesizeRaw        => 4722,
                },
                {
                    #. . .
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
            'AttachmentID' => {
                Type     => 'ARRAY',
                Required => 1
            },
            'include' => {
                Type     => 'ARRAYtoHASH',
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
    my $Access = $Self->CheckAccessPermissions(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Access ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to access ticket $Param{Data}->{TicketID}.",
        );
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my @AttachmentList;

    # start attachment loop
    ATTACHMENT:
    for my $AttachmentID ( sort @{$Param{Data}->{AttachmentID}} ) {
        
        my %Attachment = $TicketObject->ArticleAttachment(
            ArticleID          => $Param{Data}->{ArticleID},
            FileID             => $AttachmentID,
            UserID             => $Self->{Authorization}->{UserID},
        );

        if ( !$Param{Data}->{include}->{Content} ) {
            delete $Attachment{Content};
        }

        # add
        push(@AttachmentList, \%Attachment);
    }

    if ( scalar(@AttachmentList) == 1 ) {
        return $Self->_Success(
            Attachment => $AttachmentList[0],
        );    
    }

    return $Self->_Success(
        Attachment => \@AttachmentList,
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
