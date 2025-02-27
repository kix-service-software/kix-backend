# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemSearch;

use strict;
use warnings;

use base qw(
    Kernel::API::Operation::V1::Common
);

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::GeneralCatalog::GeneralCatalogItemSearch - API GeneralCatalogItem Search Operation backend

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

perform GeneralCatalogItemSearch Operation. This will return a GeneralCatalogItem list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            GeneralCatalogItem => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->SetDefaultSort(
        GeneralCatalogItem => [
            { Field => 'Name' },
        ]
    );

    my @GeneralCatalogList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'GeneralCatalog',
        Result     => 'ARRAY',
        UserType   => $Self->{Authorization}->{UserType},
        UserID     => $Self->{Authorization}->{UserID},
        Search     => $Self->{Search}->{GeneralCatalogItem},
        Sort       => $Self->{Sort}->{GeneralCatalogItem} || $Self->{DefaultSort}->{GeneralCatalogItem},
        Limit      => $Self->{SearchLimit}->{GeneralCatalogItem} || $Self->{SearchLimit}->{'__COMMON'}
    );

    my @GeneralCatalogDataList;
    if ( @GeneralCatalogList ) {

        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::GeneralCatalog::GeneralCatalogItemGet',
            SuppressPermissionErrors => 1,
            Data      => {
                GeneralCatalogItemID => join( q{,}, @GeneralCatalogList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{GeneralCatalogItem} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{GeneralCatalogItem})
                ? @{$GetResult->{Data}->{GeneralCatalogItem}}
                : ( $GetResult->{Data}->{GeneralCatalogItem} );
        }

        push @GeneralCatalogDataList, @ResultList;
    }

    if ( IsArrayRefWithData(\@GeneralCatalogDataList) ) {
        return $Self->_Success(
            GeneralCatalogItem => \@GeneralCatalogDataList,
        )
    }

    # return result
    return $Self->_Success(
        GeneralCatalogItem => [],
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
