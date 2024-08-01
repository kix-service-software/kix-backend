# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleAttachmentGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleAttachmentGet - API Ticket Get Operation backend

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
        'AttachmentID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform ArticleAttachmentGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID             => '1',                                           # required
            ArticleID            => '32',                                          # required, could be comma separated IDs or an Array
            AttachmentID         => ':1',                                          # required, could be comma separated IDs or an Array
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

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    my %Article = $TicketObject->ArticleGet(
        ArticleID     => $Param{Data}->{ArticleID},
        DynamicFields => 0,
    );

    # check if article exists
    if ( !%Article ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # check if article belongs to the given ticket
    if ( $Article{TicketID} != $Param{Data}->{TicketID} ) {
        return $Self->_Error(
            Code    => 'ParentObject.NotFound',
            Message => "Article $Param{Data}->{ArticleID} not found in ticket $Param{Data}->{TicketID}",
        );
    }

    my @AttachmentList;

    # start loop
    foreach my $AttachmentID ( @{$Param{Data}->{AttachmentID}} ) {

        my %Attachment = $TicketObject->ArticleAttachment(
            ArticleID    => $Param{Data}->{ArticleID},
            AttachmentID => $AttachmentID,
            UserID       => $Self->{Authorization}->{UserID},
            NoContent    => $Param{Data}->{include}->{Content} ? 0 : 1,
        );

        # check if article attachment exists
        if ( !%Attachment ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        if ( $Param{Data}->{include}->{Content} ) {
            # encode content base64
            $Attachment{Content} = MIME::Base64::encode_base64( $Attachment{Content} );
        }
        else {
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
