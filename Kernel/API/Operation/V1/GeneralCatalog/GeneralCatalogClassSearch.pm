# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogClassSearch;

use strict;
use warnings;

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::GeneralCatalog::GeneralCatalogClassSearch - API GeneralCatalogClass Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform GeneralCatalogClassSearch Operation. This will return a GeneralCatalogClass search.

    my $Result = $OperationObject->Run(
        Data => {}
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            GeneralCatalogClass => [...]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $GeneralCatalogClassList = $Kernel::OM->Get('GeneralCatalog')->ClassList();

    if ( $GeneralCatalogClassList ) {
        return $Self->_Success(
            GeneralCatalogClass => $GeneralCatalogClassList,
        )
    }

    # return result
    return $Self->_Success(
        GeneralCatalogClass => [],
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
