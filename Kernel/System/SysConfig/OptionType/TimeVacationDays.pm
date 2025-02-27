# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SysConfig::OptionType::TimeVacationDays;

use strict;
use warnings;

use base qw(
    Kernel::System::SysConfig::OptionType::Hash
);

use Kernel::System::VariableCheck qw(:all);

=item ValidateSetting()

Validates the given setting and returns the prepared Setting as well as the default value.

    my $Success = $OptionTypeObject->ValidateSetting(
        Setting => {...},
    );

=cut

sub ValidateSetting {
    my ( $Self, %Param ) = @_;

    my @DefaultValue;

    if ( IsArrayRefWithData($Param{Setting}->{Item}) ) {
        foreach my $Item ( @{$Param{Setting}->{Item}} ) {
            next if !IsHashRefWithData($Item);
            my %PreparedItem = %{$Item};
            delete $PreparedItem{Tanslatable};
            push(@DefaultValue, \%PreparedItem);
        }
    }

    return (undef, \@DefaultValue);
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
