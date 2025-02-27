# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::MacroSearch - API Macro Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform MacroSearch Operation. This will return a Macro list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Macro => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @MacroDataList;

    # we don't do any core search filtering, inform the API to do it for us, based on the given search
    $Self->HandleSearchInAPI();

    my %MacroList = $Kernel::OM->Get('Automation')->MacroList(
        Valid => 0,
    );

    # get already prepared Macro data from MacroGet operation
    if ( IsHashRefWithData(\%MacroList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Automation::MacroGet',
            SuppressPermissionErrors => 1,
            Data      => {
                MacroID => join(',', sort keys %MacroList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Macro} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Macro}) ? @{$GetResult->{Data}->{Macro}} : ( $GetResult->{Data}->{Macro} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Macro => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Macro => [],
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
