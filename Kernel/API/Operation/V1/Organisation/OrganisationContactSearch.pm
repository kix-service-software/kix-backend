# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Organisation::OrganisationContactSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Organisation::OrganisationContactSearch - API Organisation Contact Search Operation backend

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

perform OrganisationContactSearch Operation. This will return a Organisation list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Contact => [
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

    # perform contact search
    my @ContactList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Contact',
        Result     => 'ARRAY',
        Search     => {
            AND => [
                {
                    Field    => 'OrganisationID',
                    Operator => 'EQ',
                    Type     => 'NUMERIC',
                    Value    => $Param{Data}->{OrganisationID}
                }
            ]
        },
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType}
    );

    if (@ContactList) {

        # get already prepared Contact data from ContactGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType => 'V1::Contact::ContactGet',
            Data          => {
                ContactID => join(q{,}, @ContactList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Contact} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Contact})
                ? @{$GetResult->{Data}->{Contact}}
                : ( $GetResult->{Data}->{Contact} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Contact => \@ResultList,
            );
        }
    }

    # return result
    return $Self->_Success(
        Contact => [],
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
