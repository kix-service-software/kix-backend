# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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
        my $Key     = $1;
        # Mask secret config options.
        if ($Key =~ m{(Password|Pw)\d*$}smxi) {
            $Replace = 'xxx';
        }
        else {
            # special handling for FQDN
            if ($Key =~ m/FQDN_?(.*)/ ) {
                my $FQDNConfig = $ConfigObject->Get('FQDN') // '';
                if ( IsHashRefWithData($FQDNConfig) ) {
                    if ( $Key eq 'FQDN' ) {
                        $Replace = $FQDNConfig->{Frontend} || '';
                    } elsif ($1) {
                        $Replace = $FQDNConfig->{$1} || '';
                    }
                }
            } else {
                $Replace = $ConfigObject->Get($Key) // '';
                # TODO: handle ref values
                # if ( IsHashRefWithData($Replace) || IsArrayRefWithData($Replace) ) {
                #     $Replace = $Kernel::OM->Get('JSON')->Encode(
                #         Data => $Replace
                #     );
                # }
            }
        }
        $Replace;
    }egx;

    # cleanup
    $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;

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
