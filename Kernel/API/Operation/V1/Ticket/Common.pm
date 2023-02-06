# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::Common;

use strict;
use warnings;

use MIME::Base64();

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::Common - Base class for all Ticket Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item PreRun()

some code to run before actual execution

    my $Success = $CommonObject->PreRun(
        ...
    );

    returns:

    $Success = {
        Success => 1,                     # if everything is OK
    }

    $Success = {
        Code    => 'Forbidden',           # if error
        Message => 'Error description',
    }

=cut

sub PreRun {
    my ( $Self, %Param ) = @_;

    if ( IsArrayRefWithData($Param{Data}->{TicketID}) ) {

        # check if articles are accessible for current customer user
        if ( IsArrayRefWithData($Param{Data}->{ArticleID}) ) {
            return $Self->_CheckCustomerAssignedObject(
                ObjectType             => 'TicketArticle',
                IDList                 => $Param{Data}->{ArticleID},
                TicketID               => $Param{Data}->{TicketID},
                RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID}
            );
        }

        # check if tickets are accessible for current customer user
        return $Self->_CheckCustomerAssignedObject(
            ObjectType             => 'Ticket',
            IDList                 => $Param{Data}->{TicketID},
            RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID}
        );
    }

    return $Self->_Success();
}

=item ValidatePendingTime()

checks if the given pending time is valid.

    my $Success = $CommonObject->ValidatePendingTime(
        PendingTime => {
            Year   => 2011,
            Month  => 12,
            Day    => 23,
            Hour   => 15,
            Minute => 0,
        },
    );

    my $Success = $CommonObject->ValidatePendingTime(
        PendingTime => {
            Diff => 10080,
        },
    );

    returns
    $Success = 1            # or 0

=cut

sub ValidatePendingTime {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{PendingTime};
    return if !IsHashRefWithData( $Param{PendingTime} );

    # if only the Diff attribute is present, check if it's a valid number and return.
    # Nothing else needs to be checked in that case.
    if ( keys %{ $Param{PendingTime} } == 1 && defined $Param{PendingTime}->{Diff} ) {
        return if $Param{PendingTime}->{Diff} !~ m{\A \d+ \z}msx;
        return 1;
    }
    elsif ( defined $Param{PendingTime}->{Diff} ) {

        # the use of Diff along with any other option is forbidden
        return;
    }

    # check that no time attribute is empty or negative
    for my $TimeAttribute ( sort keys %{ $Param{PendingTime} } ) {
        return if $Param{PendingTime}->{$TimeAttribute} eq '';
        return if int $Param{PendingTime}->{$TimeAttribute} < 0,
    }

    # try to convert pending time to a SystemTime
    my $SystemTime = $Kernel::OM->Get('Time')->Date2SystemTime(
        %{ $Param{PendingTime} },
        Second => 0,
    );
    return if !$SystemTime;

    return 1;
}

sub ExecOperation {
    my ( $Self, %Param ) = @_;

    # add relevant orga id to data if given
    if ( IsHashRefWithData($Self->{RequestData}) && $Self->{RequestData}->{RelevantOrganisationID} ) {
        if (IsHashRefWithData($Param{Data})) {
            $Param{Data}->{RelevantOrganisationID} = $Self->{RequestData}->{RelevantOrganisationID};
        } else {
            $Param{Data} = {
                RelevantOrganisationID => $Self->{RequestData}->{RelevantOrganisationID}
            };
        }
    }

    return $Self->SUPER::ExecOperation(%Param);
}

=begin Internal:

=item _CheckTicket()

checks if the given ticket parameter is valid.

    my $TicketCheck = $OperationObject->_CheckTicket(
        Ticket => $Ticket,                        # all ticket parameters
    );

    returns:

    $TicketCheck = {
        Success => 1,                               # if everything is OK
    }

    $TicketCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckTicket {
    my ( $Self, %Param ) = @_;

    my $Ticket = $Param{Ticket};

    # check ticket internally
    for my $Needed (qw(Title)) {
        if ( !$Ticket->{$Needed} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Required parameter $Needed is missing!",
            );
        }
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    if ( defined $Ticket->{Articles} ) {

        if ( !IsArrayRefWithData($Ticket->{Articles}) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Ticket::Articles is invalid!",
            );
        }

        # check Article internal structure
        foreach my $ArticleItem (@{$Ticket->{Articles}}) {
            if ( !IsHashRefWithData($ArticleItem) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter Ticket::Articles is invalid!",
                );
            }

            # check article attribute values
            my $ArticleCheck = $Self->_CheckArticle( Article => $ArticleItem );

            if ( !$ArticleCheck->{Success} ) {
                return $Self->_Error(
                    %{$ArticleCheck}
                );
            }
        }
    }

    if ( defined $Ticket->{DynamicFields} ) {

        if ( !IsArrayRefWithData($Ticket->{DynamicFields}) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Ticket::DynamicFields is invalid!",
            );
        }

        # check DynamicField internal structure
        foreach my $DynamicFieldItem (@{$Ticket->{DynamicFields}}) {
            if ( !IsHashRefWithData($DynamicFieldItem) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter Ticket::DynamicFields is invalid!",
                );
            }

            # check DynamicField attribute values
            my $DynamicFieldCheck = $Self->_CheckDynamicField(
                DynamicField => $DynamicFieldItem,
                ObjectType   => 'Ticket'
            );

            if ( !$DynamicFieldCheck->{Success} ) {
                return $Self->_Error(
                    %{$DynamicFieldCheck}
                );
            }
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _CheckArticle()

checks if the given article parameter is valid.

    my $ArticleCheck = $OperationObject->_CheckArticle(
        Article => $Article,                        # all article parameters
    );

    returns:

    $ArticleCheck = {
        Success => 1,                               # if everything is OK
    }

    $ArticleCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckArticle {
    my ( $Self, %Param ) = @_;

    my $Article = $Param{Article};

    # check ticket internally
    for my $Needed (qw(Subject Body)) {
        if ( !$Article->{$Needed} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Required parameter $Needed is missing!",
            );
        }
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # check Article->NoAgentNotify
    if ( $Article->{NoAgentNotify} && $Article->{NoAgentNotify} ne '1' ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Parameter NoAgentNotify is invalid!",
        );
    }

    # check Article array parameters
    for my $Attribute (
        qw( ForceNotificationToUserID ExcludeNotificationToUserID ExcludeMuteNotificationToUserID )
        )
    {
        if ( defined $Article->{$Attribute} ) {

            # check structure
            if ( IsHashRefWithData( $Article->{$Attribute} ) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter $Attribute is invalid!",
                );
            }
            else {
                if ( !IsArrayRefWithData( $Article->{$Attribute} ) ) {
                    $Article->{$Attribute} = [ $Article->{$Attribute} ];
                }
                for my $UserID ( @{ $Article->{$Attribute} } ) {
                    my $UserLogin = $Kernel::OM->Get('User')->UserLookup( 
                        UserID => $UserID,
                        Silent => 1,
                    );
                    if ( !$UserLogin ) {
                        return $Self->_Error(
                            Code    => 'BadRequest',
                            Message => "Parameter UserID $UserID in parameter $Attribute is invalid!",
                        );
                    }
                }
            }
        }
    }

    if ( defined $Article->{Attachments} ) {

        if ( !IsArrayRefWithData($Article->{Attachments}) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Article::Attachments is invalid!",
            );
        }

        # check Attachment internal structure
        foreach my $AttachmentItem (@{$Article->{Attachments}}) {
            if ( !IsHashRefWithData($AttachmentItem) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter Article::Attachments is invalid!",
                );
            }

            # check Attachment attribute values
            my $AttachmentCheck = $Self->_CheckAttachment( Attachment => $AttachmentItem );

            if ( !$AttachmentCheck->{Success} ) {
                return $Self->_Error(
                    %{$AttachmentCheck}
                );
            }
        }
    }

    if ( defined $Article->{DynamicField} ) {

        if ( !IsArrayRefWithData($Article->{DynamicFields}) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Article::DynamicFields is invalid!",
            );
        }

        # check DynamicField internal structure
        foreach my $DynamicFieldItem (@{$Article->{DynamicFields}}) {
            if ( !IsHashRefWithData($DynamicFieldItem) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Parameter Article::DynamicFields is invalid!",
                );
            }

            # check DynamicField attribute values
            my $DynamicFieldCheck = $Self->_CheckDynamicField(
                DynamicField => $DynamicFieldItem,
                ObjectType   => 'Article'
            );

            if ( !$DynamicFieldCheck->{Success} ) {
                return $Self->_Error(
                    %{$DynamicFieldCheck}
                );
            }
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _CheckAttachment()

checks if the given attachment parameter is valid.

    my $AttachmentCheck = $OperationObject->_CheckAttachment(
        Attachment => $Attachment,                  # all attachment parameters
    );

    returns:

    $AttachmentCheck = {
        Success => 1,                               # if everything is OK
    }

    $AttachmentCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckAttachment {
    my ( $Self, %Param ) = @_;

    my $Attachment = $Param{Attachment};

    # check attachment item internally
    for my $Needed (qw(Filename Content)) {
        if ( !$Attachment->{$Needed} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter Attachment::$Needed is missing!",
            );
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
