# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Organisation::OrganisationTicketSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Organisation::OrganisationTicketSearch - API Organisation Ticket Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->SUPER::Init(%Param);

    $Self->{HandleSortInCORE} = 1;

    return $Result;
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
        'OrganisationID' => {
            Required => 1
        }
    }
}

=item Run()

perform OrganisationTicketSearch Operation. This will return a Organisation list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Ticket => [
                {
                },
                {
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform ticket search
    my @TicketList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Ticket',
        Search     => {
            AND => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'EQ',
                    Value    => $Param{Data}->{OrganisationID},
                }
            ]
        },
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
        Result   => 'ARRAY',
    );

    if (@TicketList) {

        # get already prepared Ticket data from TicketGet operation
        my $TicketGetResult = $Self->ExecOperation(
            OperationType => 'V1::Ticket::TicketGet',
            Data          => {
                TicketID => join(q{,}, @TicketList),
            }
        );

        if ( !IsHashRefWithData($TicketGetResult) || !$TicketGetResult->{Success} ) {
            return $TicketGetResult;
        }

        my @ResultList = IsArrayRef($TicketGetResult->{Data}->{Ticket})
            ? @{$TicketGetResult->{Data}->{Ticket}}
            : ( $TicketGetResult->{Data}->{Ticket} );

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Ticket => \@ResultList,
            );
        }
    }

    # return result
    return $Self->_Success(
        Ticket => [],
    );
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
