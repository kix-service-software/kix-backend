# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::Common;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::GeneralCatalog::Common - Base class for all GeneralCatalog Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=begin Internal:

=item _CheckPreferences()

checks if the given preference parameter is valid.

    my $PreferencesCheck = $OperationObject->_CheckPreferences(
        Preferneces => $PreferencesArrayRef,
        Class       => $GCClass
    );

    returns:

    $PrefernecesCheck = {
        Success => 1,                               # if everything is OK
    }

    $PrefernecesCheck = {
        Code    => 'Function.Error',                # if error
        Message => 'Error description',
    }

=cut

sub _CheckPreferences {
    my ( $Self, %Param ) = @_;

    my %NewPreferences;
    for my $Pref ( @{ $Param{Preferences} } ) {
        if (
            IsHashRefWithData($Pref) &&
            $Pref->{Name} && exists $Pref->{Value}  # value can be emtpy (e.g. on update)
        ) {
            $NewPreferences{$Pref->{Name}} = 1;
        } else {
            return {
                Message => 'The preference configs are invalid/incomplete (Name or Value missing).'
            };
        }
    }

    if (IsHashRefWithData(\%NewPreferences)) {
        my $PreferenceConfigs = $Kernel::OM->Get('Config')->Get('GeneralCatalogPreferences');
        if (IsHashRefWithData($PreferenceConfigs)) {
            for my $Pref ( values %{$PreferenceConfigs} ) {
                if (
                    IsHashRefWithData($Pref) &&
                    $Pref->{Class} && $Pref->{Class} eq $Param{Class} &&
                    $Pref->{PrefKey} && $NewPreferences{ $Pref->{PrefKey} }
                ) {
                    delete $NewPreferences{ $Pref->{PrefKey} };
                }
            }
        }
        if (IsHashRefWithData(\%NewPreferences)) {
            return {
                Message => 'Unknown preferences found (' . join(', ', keys %NewPreferences) . ')'
            };
        }
    }

    return {
        Success => 1
    };
}

=item _SetPreferences()

checks if the given preference parameter is valid.

    my $PreferencesSet = $OperationObject->_SetPreferences(
        Preferneces => $PreferencesArrayRef,
        Class       => $GCClass,
        ItemID      => 123
    );

    returns:

    $PrefernecesCheck = {
        Success => 1,                               # if everything is OK
    }

    $PrefernecesCheck = {
        Code    => 'Function.Error',                # if error
        Message => 'Error description',
    }


=cut

sub _SetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Preferences Class ItemID)) {
        if ( !$Param{$Needed} ) {
            return {
                Code    => 'Object.UnableToCreate',
                Message => "Could not set preferences ($Needed missing)."
            };
        }
    }

    # set known preferences
    if ( IsArrayRefWithData( $Param{Preferences} ) ) {
        my %NewPreferences;
        for my $Pref ( @{ $Param{Preferences} } ) {
            if (
                IsHashRefWithData($Pref) &&
                $Pref->{Name} && exists $Pref->{Value}  # value can be emtpy (e.g. on update)
            ) {
                $NewPreferences{ $Pref->{Name} } = $Pref->{Value};
            }
        }

        my $PreferenceConfigs = $Kernel::OM->Get('Config')->Get('GeneralCatalogPreferences');
        if (IsHashRefWithData($PreferenceConfigs)) {
            for my $Pref ( values %{$PreferenceConfigs} ) {
                if (
                    IsHashRefWithData($Pref) &&
                    $Pref->{Class} && $Pref->{Class} eq $Param{Class} &&
                    $Pref->{PrefKey} && exists $NewPreferences{ $Pref->{PrefKey} }
                ) {
                    if ($NewPreferences{ $Pref->{PrefKey} }) {
                        $Kernel::OM->Get('GeneralCatalog')->GeneralCatalogPreferencesSet(
                            ItemID => $Param{ItemID},
                            Key    => $Pref->{PrefKey},
                            Value  => $NewPreferences{ $Pref->{PrefKey} },
                        );
                    }

                    # value can be emtpy, so delete saved preferences value (e.g. on update)
                    else {
                        $Kernel::OM->Get('GeneralCatalog')->GeneralCatalogPreferencesDelete(
                            ItemID => $Param{ItemID},
                            Key    => $Pref->{PrefKey}
                        );
                    }
                }
            }
        }
    }

    return {
        Success => 1
    };
}

1;

=end Internal:

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
