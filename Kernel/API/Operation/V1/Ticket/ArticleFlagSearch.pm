# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleFlagSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Ticket::ArticleFlagSearch - API Ticket Article Flag Search Operation backend

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
    }
}

=item Run()

perform ArticleFlagSearch Operation. This will return a article attachment list.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 1'                                             # required
            ArticleID => 32,                                            # required
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                                    # In case of an error
        Data         => {
            ArticleFlag => [
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

    my %ArticleFlags = $TicketObject->ArticleFlagsOfTicketGet(
        TicketID  => $Param{Data}->{TicketID},
        UserID    => $Self->{Authorization}->{UserID},
    );
    if ( %ArticleFlags ) {

        # get already prepared ArticleFlag data from ArticleFlagGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Ticket::ArticleFlagGet',
            SuppressPermissionErrors => 1,
            Data          => {
                TicketID  => $Param{Data}->{TicketID},
                ArticleID => $Param{Data}->{ArticleID},
                FlagName  => join(',', keys %{$ArticleFlags{$Param{Data}->{ArticleID}}}),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ArticleFlag} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ArticleFlag}) ? @{$GetResult->{Data}->{ArticleFlag}} : ( $GetResult->{Data}->{ArticleFlag} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ArticleFlag => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ArticleFlag => [],
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
