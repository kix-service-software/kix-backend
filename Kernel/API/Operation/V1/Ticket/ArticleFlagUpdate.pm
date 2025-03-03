# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleFlagUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleFLagUpdate - API Ticket ArticleFlagUpdate Operation backend

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
        'FlagName' => {
            Required => 1
        },
        'ArticleFlag' => {
            Type     => 'HASH',
            Required => 1
        },
        'ArticleFlag::Value' => {
            Required => 1
        },
    }
}

=item Run()

perform ArticleFlagUpdate Operation. This will return the updated ArticleFlag

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 123,                                                  # required
            ArticleID => 123,                                                  # required
            FlagName  => 'seen',                                               # required
            ArticleFlag => {                                                   # required
                Value => '...'                                                 # required
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            FlagName => 'seen',                     # Name of changed flag
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

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
            Code => 'ParentObject.NotFound',
        );
    }

    # check if flag exists
    my %ArticleFlags = $Kernel::OM->Get('Ticket')->ArticleFlagGet(
        TicketID  => $Param{Data}->{TicketID},
        ArticleID => $Param{Data}->{ArticleID},
        UserID    => $Self->{Authorization}->{UserID},
    );

    if ( !exists($ArticleFlags{$Param{Data}->{FlagName}}) ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    my $Success = $Kernel::OM->Get('Ticket')->ArticleFlagSet(
        ArticleID => $Param{Data}->{ArticleID},
        Key       => $Param{Data}->{FlagName},
        Value     => $Param{Data}->{ArticleFlag}->{Value},
        UserID    => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    return $Self->_Success(
        FlagName => $Param{Data}->{FlagName},
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
