# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::Config;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Placeholder::Base);

our @ObjectDependencies = (
    'Config',
    'Log'
);

=head1 NAME

Kernel::System::Placeholder::Config

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

    my $ConfigObject = $Kernel::OM->Get('Config');

    my $Tag = $Self->{Start} . 'KIX_CONFIG_';
    $Param{Text} =~ s{$Tag(.+?)$Self->{End}}{
        my $Replace = '';
        # Mask secret config options.
        if ($1 =~ m{(Password|Pw)\d*$}smxi) {
            $Replace = 'xxx';
        }
        else {
            $Replace = $ConfigObject->Get($1) // '';
        }
        $Replace;
    }egx;

    # cleanup
    $Param{Text} =~ s/$Tag.+?$Self->{End}/-/gi;

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
