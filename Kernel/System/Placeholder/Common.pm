# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::Common;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'Time'
);

=head1 NAME

Kernel::System::Placeholder::Common

=cut

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # replace NOW placeholders
    my $Tag = $Self->{Start} . 'KIX_NOW';

    if ($Param{Text} =~ m/$Tag/) {
        my $Now = $Kernel::OM->Get('Time')->CurrentTimestamp();
        if ($Now =~ m/(?<Date>.+)\s(?<Time>.+)/) {
            $Param{Text} = $Self->_HashGlobalReplace( $Param{Text}, "$Tag\_",
                (
                    DateTime => $Now,
                    Date     => $+{Date},
                    Time     => $+{Time},
                )
            );

            # replace als simple placeholder <KIX_NOW>
            $Param{Text} =~ s/$Tag$Self->{End}/$Now/gi;
        }

        # cleanup
        $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;
    }

    return $Param{Text};
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
