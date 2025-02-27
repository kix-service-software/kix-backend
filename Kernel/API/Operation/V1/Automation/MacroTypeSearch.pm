# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Automation::MacroTypeSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::MacroTypeSearch - API Automation Macro Type Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform MacroTypeSearch Operation. This will return a list macro types.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            MacroType => [
                ...
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get macro types
    my $MacroTypes = $Kernel::OM->Get('Config')->Get('Automation::MacroType');

    if ( IsHashRefWithData($MacroTypes) ) {
        my @MacroTypeList;
        foreach my $Key ( sort keys %{$MacroTypes} ) {
            push @MacroTypeList, { Name => $Key, DisplayName => $MacroTypes->{$Key}->{DisplayName} };
        }
        return $Self->_Success(
            MacroType => \@MacroTypeList,
        )
    }

    # return result
    return $Self->_Success(
        MacroType => [],
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
