# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::CMDB::ConfigItemSearch - API CMDB Search Operation backend

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

perform ConfigItemSearch Operation. This will return a class list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ConfigItem => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->SetDefaultSort(
        ConfigItem => [
            { Field => 'Name' },
            { Field => 'Number' },
        ]
    );

    # get customer relevant ids if necessary
    if ($Self->{Authorization}->{UserType} eq 'Customer') {
        my $CustomerCIIDList = $Self->_GetCustomerUserVisibleObjectIds(
            ObjectType             => 'ConfigItem',
            UserID                 => $Self->{Authorization}->{UserID},
            UserType               => $Self->{Authorization}->{UserType},
            RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID}
        );

        # return empty result if there are no assigned config items for customer
        return $Self->_Success(
            ConfigItem => [],
        ) if (!IsArrayRefWithData($CustomerCIIDList));

        push(
            @{$Self->{Search}->{ConfigItem}->{AND}},
            {
                Field    => 'ConfigItemID',
                Operator => 'IN',
                Type     => 'Numeric',
                Value    => $CustomerCIIDList
            }
        );
    }

    my @ConfigItemList = $Kernel::OM->Get('ObjectSearch')->Search(
        Result     => 'ARRAY',
        Search     => $Self->{Search}->{ConfigItem}      || {},
        Limit      => $Self->{SearchLimit}->{ConfigItem} || $Self->{SearchLimit}->{'__COMMON'},
        Sort       => $Self->{Sort}->{ConfigItem}        || $Self->{DefaultSort}->{ConfigItem},
        UserType   => $Self->{Authorization}->{UserType},
        UserID     => $Self->{Authorization}->{UserID},
        ObjectType => 'ConfigItem'
    );

    # get already prepared CI data from ConfigItemGet operation
    if ( @ConfigItemList ) {

        my $GetResult = $Self->ExecOperation(
            OperationType => 'V1::CMDB::ConfigItemGet',
            Data          => {
                ConfigItemID           => join(q{,}, @ConfigItemList),
                RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID}
            }
        );

        if (
            !IsHashRefWithData($GetResult)
            || !$GetResult->{Success}
        ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ConfigItem} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ConfigItem})
                ? @{$GetResult->{Data}->{ConfigItem}}
                : ( $GetResult->{Data}->{ConfigItem} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ConfigItem => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ConfigItem => [],
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
