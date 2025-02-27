# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Session::MarkObjectAsSeen;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Session::MarkObjectAsSeen - API Session MarkObjectAsSeen Create Operation backend

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
        'MarkObjectAsSeen' => {
            Type     => 'HASH',
            Required => 1
        },
        'MarkObjectAsSeen::ObjectType' => {
            Required => 1
        },
        'MarkObjectAsSeen::IDs' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform MarkObjectAsSeenCreate Operation. This will return success.

    my $Result = $OperationObject->Run(
        Data => {
            MarkObjectAsSeen  => {
                ObjectType => 'Article',
                IDs        => [1,2,4]
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => undef,
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim parameters
    my $MarkAsSeen = $Self->_Trim(
        Data => $Param{Data}->{MarkObjectAsSeen},
    );

    my $Success;
    if ($MarkAsSeen->{ObjectType} eq 'Article') {
        $Success = $Self->_SetArticlesAsSeen(
            ArticleIDs => $MarkAsSeen->{IDs}
        );
    } elsif ($MarkAsSeen->{ObjectType} eq 'Ticket') {
        $Success = $Self->_SetTicketsAsSeen(
            TicketIDs => $MarkAsSeen->{IDs}
        );
    } else {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => "Could not mark object as seen - not supported object type \"$MarkAsSeen->{ObjectType}\"",
        );
    }

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not mark object as seen',
        );
    }

    # return result
    return $Self->_Success();
}

sub _SetArticlesAsSeen {
    my ( $Self, %Param ) = @_;

    for my $ArticleID (@{$Param{ArticleIDs}}) {
        my $SetSuccess = $Kernel::OM->Get('Ticket')->ArticleFlagSet(
            ArticleID => $ArticleID,
            TicketID  => $Param{TicketID},
            Key       => 'Seen',
            Value     => 1,
            UserID    => $Self->{Authorization}->{UserID},
            # for performance reasons - ticket flag update will trigger notification
            Silent    => $Param{TicketID} ? 1 : 0,
            NoEvents  => $Param{TicketID} ? 1 : 0
        );
        if (!$SetSuccess) {
            return 0;
        }
    }
    return 1;
}

sub _SetTicketsAsSeen {
    my ( $Self, %Param ) = @_;

    for my $TicketID (@{$Param{TicketIDs}}) {
        my $Success = $Kernel::OM->Get('Ticket')->MarkAsSeen(
            TicketID => $TicketID,
            UserID   => $Self->{Authorization}->{UserID}
        );
        return 0 if !$Success;
    }
    return 1;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
