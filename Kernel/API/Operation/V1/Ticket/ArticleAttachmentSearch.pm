# --
# Kernel/API/Operation/User/ArticleAttachmentSearch.pm - API User Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleAttachmentSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Ticket::ArticleAttachmentSearch - API Ticket Article Attachment Search Operation backend

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
    }
}

=item Run()

perform ArticleAttachmentSearch Operation. This will return a article attachment list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Attachment => [
                {
                },
                {
                }
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

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

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Article = $TicketObject->ArticleGet(
        ArticleID  => $Param{Data}->{ArticleID},
        UserID     => $Self->{Authorization}->{UserID},
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

    # By default does not include HTML body as attachment (3) unless is explicitly requested (2).
    my $StripPlainBodyAsAttachment = $Param{Data}->{HTMLBodyAsAttachment} ? 2 : 3;

    my %AttachmentIndex = $TicketObject->ArticleAttachmentIndex(
        ContentPath                => $Article{ContentPath},
        ArticleID                  => $Param{Data}->{ArticleID},
        StripPlainBodyAsAttachment => $StripPlainBodyAsAttachment,
        UserID                     => $Self->{Authorization}->{UserID},
    );

    if ( %AttachmentIndex ) {

        # get already prepared Article data from ArticleGet operation
        my $AttachmentGetResult = $Self->ExecOperation(
            OperationType => 'V1::Ticket::ArticleAttachmentGet',
            Data          => {
                TicketID     => $Param{Data}->{TicketID},
                ArticleID    => $Param{Data}->{ArticleID},
                AttachmentID => join(',', keys %AttachmentIndex),
                include      => $Param{Data}->{include},
                expand       => $Param{Data}->{expand},
            }
        );
        if ( !IsHashRefWithData($AttachmentGetResult) || !$AttachmentGetResult->{Success} ) {
            return $AttachmentGetResult;
        }

        my @ResultList = IsArrayRefWithData($AttachmentGetResult->{Data}->{Attachment}) ? @{$AttachmentGetResult->{Data}->{Attachment}} : ( $AttachmentGetResult->{Data}->{Attachment} );
        
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
