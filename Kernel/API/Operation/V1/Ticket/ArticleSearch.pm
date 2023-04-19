# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Ticket::ArticleSearch - API Ticket Article Search Operation backend

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
    }
}

=item Run()

perform ArticleSearch Operation. This will return a article list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Article => [
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

    my @ArticleIndex = $TicketObject->ArticleIndex(
        TicketID        => $Param{Data}->{TicketID},
        UserID          => $Self->{Authorization}->{UserID},
    );

    # filter for customer assigned articles if necessary
    @ArticleIndex = $Self->_FilterCustomerUserVisibleObjectIds(
        TicketID               => $Param{Data}->{TicketID},
        ObjectType             => 'TicketArticle',
        ObjectIDList           => \@ArticleIndex,
        UserID                 => $Self->{Authorization}->{UserID},
        RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID}
    );

    if ( @ArticleIndex ) {

        # get already prepared Article data from ArticleGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Ticket::ArticleGet',
            SuppressPermissionErrors => 1,
            Data                     => {
                TicketID               => $Param{Data}->{TicketID},
                ArticleID              => join(',', @ArticleIndex),
                include                => $Param{Data}->{include},
                expand                 => $Param{Data}->{expand}
            }
        );

        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Article} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Article}) ? @{$GetResult->{Data}->{Article}} : ( $GetResult->{Data}->{Article} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Article => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Article => [],
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
