# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SysConfig::OptionType::Array;

use strict;
use warnings;

use base qw(
    Kernel::System::SysConfig::OptionType::Base
);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Log',
);

=head1 NAME

Kernel::System::SysConfig::OptionType::Array - Array type lib

=head1 SYNOPSIS

All functions for SysConfig option type Array.

=head1 PUBLIC INTERFACE

=over 4

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
        ITEM:
        foreach my $Item ( @{$Param{Setting}->{Item}} ) {
            if ( IsHashRefWithData($Item) ) {
                foreach my $Key ( keys %{$Item} ) {
                    # ignore Translatable
                    next if $Key eq 'Translatable';

                    if ( IsHashRefWithData($Item->{$Key}) && IsArrayRefWithData($Item->{$Key}->{Item}) ) {
                        my ($SettingSub, $DefaultValueSub) = $Self->SUPER::ValidateSetting(
                            Type    => $Key,
                            Setting => $Item->{$Key}
                        );
                        push(@DefaultValue, $DefaultValueSub);
                        next ITEM;
                    }
                    else {
                        push(@DefaultValue, $Item->{content});
                    }
                }
            }
            else {
                push(@DefaultValue, $Item);
            }
        }
    }

    return (undef, \@DefaultValue);
}

=item Extend()

Extends the given value with the extension

    my $Result = $OptionTypeObject->Extend(
        Value  => ...,
        Extend => ...,
    );

=cut

sub Extend {
    my ( $Self, %Param ) = @_;

    # merge without duplicates
    my @Value = @{$Param{Value}||[]};
    my %ExistingValues = map { $_ => 1 } @Value;

    foreach my $Extend ( @{$Param{Extend}||[]} ) {
        next if $ExistingValues{$Extend};
        push @Value, $Extend;
    }

    return \@Value;
}

=item Encode()

Encode the data to JSON

    my $EncodedData = $OptionTypeObject->Encode(
        Data => '...',
    );

=cut

sub Encode {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('JSON')->Encode(
        Data => $Param{Data}
    );
}

=item Decode()

Decodes the JSON data

    my $DecodedData = $OptionTypeObject->Decode(
        Data => '...',
    );

=cut

sub Decode {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('JSON')->Decode(
        Data => $Param{Data}
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
