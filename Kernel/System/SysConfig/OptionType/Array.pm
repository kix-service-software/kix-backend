# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SysConfig::OptionType::Array;

use strict;
use warnings;

use base qw(
    Kernel::System::SysConfig::OptionType::Base
);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
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

=item Encode()

Encode the data to JSON

    my $EncodedData = $OptionTypeObject->Encode(
        Data => '...',
    );

=cut

sub Encode {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Kernel::System::JSON')->Encode(
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

    return $Kernel::OM->Get('Kernel::System::JSON')->Decode(
        Data => $Param{Data}
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
