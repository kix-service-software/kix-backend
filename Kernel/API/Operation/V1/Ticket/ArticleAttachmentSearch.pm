# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleAttachmentSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

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

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Article = $TicketObject->ArticleGet(
        ArticleID  => $Param{Data}->{ArticleID},
        UserID     => $Self->{Authorization}->{UserID},
    );

    # check if article exists
    if ( !%Article ) {
        return $Self->_Error(
            Code    => 'ParentObject.NotFound',
            Message => "Could not get data for article $Param{Data}->{ArticleID}",
        );
    }

    # check if article belongs to the given ticket
    if ( $Article{TicketID} != $Param{Data}->{TicketID} ) {
        return $Self->_Error(
            Code    => 'ParentObject.NotFound',
            Message => "Article $Param{Data}->{ArticleID} not found in ticket $Param{Data}->{TicketID}",
        );
    }

    # restrict article sender types
    if ( $Self->{Authorization}->{UserType} eq 'Customer' && $Article{ArticleSenderType} ne 'external') {
        return $Self->_Error(
            Code => 'Object.NoPermission',
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
                AttachmentID => join(',', sort keys %AttachmentIndex),
                include      => $Param{Data}->{include},
                expand       => $Param{Data}->{expand},
            }
        );
        if ( !IsHashRefWithData($AttachmentGetResult) || !$AttachmentGetResult->{Success} ) {
            return $AttachmentGetResult;
        }

        my @ResultList = IsArrayRef($AttachmentGetResult->{Data}->{Attachment}) ? @{$AttachmentGetResult->{Data}->{Attachment}} : ( $AttachmentGetResult->{Data}->{Attachment} );
        
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
