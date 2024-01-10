# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Organisation::OrganisationSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Organisation::OrganisationSearch - API Organisation Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->SUPER::Init(%Param);

    $Self->{HandleSortInCORE} = 1;

    return $Result;
}

=item Run()

perform OrganisationSearch Operation. This will return a Organisation list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Organisation => [
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

    $Self->SetDefaultSort(
        Organisation => [
            { Field => 'Name' },
            { Field => 'Number' }
        ]
    );

    my @OrganisationIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Organisation',
        Result     => 'ARRAY',
        Search     => $Self->{Search}->{Organisation}      || {},
        Limit      => $Self->{SearchLimit}->{Organisation} || $Self->{SearchLimit}->{'__COMMON'},
        Sort       => $Self->{Sort}->{Organisation}        || $Self->{DefaultSort}->{Organisation},
        UserType   => $Self->{Authorization}->{UserType},
        UserID     => $Self->{Authorization}->{UserID},
        Debug      => $Param{Data}->{debug} || 0
    );

    if (@OrganisationIDs) {

        # get already prepared Organisation data from OrganisationGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Organisation::OrganisationGet',
            SuppressPermissionErrors => 1,
            Data                     => {
                OrganisationID              => join(q{,}, @OrganisationIDs),
                NoDynamicFieldDisplayValues => $Param{Data}->{NoDynamicFieldDisplayValues},
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Organisation} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Organisation})
                ? @{$GetResult->{Data}->{Organisation}}
                : ( $GetResult->{Data}->{Organisation} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Organisation => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Organisation => [],
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
