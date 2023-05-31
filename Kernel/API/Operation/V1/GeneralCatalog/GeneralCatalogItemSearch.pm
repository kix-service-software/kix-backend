# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::GeneralCatalog::GeneralCatalogItemSearch - API GeneralCatalogItem Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

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

    my @GeneralCatalogDataList;

    my $GeneralCatalogClassList = $Kernel::OM->Get('GeneralCatalog')->ClassList();

    foreach my $Class ( @$GeneralCatalogClassList ){

	    my $GeneralCatalogItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
	        Class => $Class,
            Valid => 0,
	    );

	    # get already prepared GeneralCatalog data from GeneralCatalogGet operation
	    if ( IsHashRefWithData($GeneralCatalogItemList) ) {
	        my $GetResult = $Self->ExecOperation(
	            OperationType            => 'V1::GeneralCatalog::GeneralCatalogItemGet',
                SuppressPermissionErrors => 1,
	            Data      => {
	                GeneralCatalogItemID => join(',', sort keys %$GeneralCatalogItemList),
	            }
	        );
            if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
                return $GetResult;
            }

            my @ResultList;
            if ( defined $GetResult->{Data}->{GeneralCatalogItem} ) {
                @ResultList = IsArrayRef($GetResult->{Data}->{GeneralCatalogItem}) ? @{$GetResult->{Data}->{GeneralCatalogItem}} : ( $GetResult->{Data}->{GeneralCatalogItem} );
            }

	        push @GeneralCatalogDataList, @ResultList;
	    }
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
