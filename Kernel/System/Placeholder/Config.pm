# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
    my ($Self, %Param) = @_;

    # check needed stuff
    for (qw(Text UserID)) {
        if (!defined $Param{$_}) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Tag = $Self->{Start} . 'KIX_CONFIG_';

    return $Param{Text} if ($Param{Text} !~ m/$Tag/);

    my $SysConfigObject = $Kernel::OM->Get('SysConfig');

    $Param{Text} =~ s{$Tag(.+?)$Self->{End}}{
        my $Replace = '';
        my $FullKey = $1;
        my $Key = $1;
        if ($FullKey =~ /(.+?)_.+/) {
            $Key = $1;
        }

        my $Exists = $SysConfigObject->Exists(
            Name => $Key
        );
        if (
            !$Exists
            && $Key ne $FullKey
        ) {
            $Exists = $SysConfigObject->Exists(
                Name => $FullKey
            );
        }
        if ($Exists) {
            my %ConfigDefinition = $SysConfigObject->OptionGet(
                Name => $Key,
            );
            if (
                $ConfigDefinition{AccessLevel} &&
                (
                    $ConfigDefinition{AccessLevel} eq 'external' ||
                    $ConfigDefinition{AccessLevel} eq 'public' ||
                    (
                        $Kernel::OM->{Authorization}->{UserType} &&
                        $Kernel::OM->{Authorization}->{UserType} eq 'Agent' &&
                        $ConfigDefinition{AccessLevel} eq 'internal'
                    )
                )
            ) {
                $Replace = $Self->_GetReplaceValue(
                    Key             => $FullKey,
                    ReplaceNotFound => $Param{ReplaceNotFound}
                );
            }
            else {
                $Replace = $Param{UserID} == 1 ?
                    $Replace = $Self->_GetReplaceValue(Key => $FullKey, ReplaceNotFound => $Param{ReplaceNotFound})
                    : $Param{ReplaceNotFound};
            }
        }

        if ( !$Exists && $Param{UserID} == 1 ) {
            $Replace = $Self->_GetReplaceValue(Key => $FullKey, ReplaceNotFound => $Param{ReplaceNotFound});
        }

        $Replace;
    }egx;

    # cleanup
    $Param{Text} =~ s/$Tag.+?$Self->{End}/$Param{ReplaceNotFound}/gi;

    return $Param{Text};
}

sub _GetReplaceValue {

    my ($Self, %Param) = @_;

    # check needed stuff
    for (qw(Key ReplaceNotFound)) {
        if (!defined $Param{$_}) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $ConfigObject = $Kernel::OM->Get('Config');

    if ($Param{Key} =~ m/FQDN_?(.*)/) {
        my $FQDNConfig = $ConfigObject->Get('FQDN') // $Param{ReplaceNotFound};
        if (IsHashRefWithData($FQDNConfig)) {
            if ($Param{Key} eq 'FQDN') {
                return $FQDNConfig->{Frontend} || $Param{ReplaceNotFound};
            }
            elsif ($1) {
                return $FQDNConfig->{$1} || $Param{ReplaceNotFound};
            }
        }
    }
    else {
        return $ConfigObject->Get($Param{Key}) // $Param{ReplaceNotFound};
        # TODO: handle ref values
        # if ( IsHashRefWithData($Replace) || IsArrayRefWithData($Replace) ) {
        #     $Replace = $Kernel::OM->Get('JSON')->Encode(
        #         Data => $Replace
        #     );
        # }
    }

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
