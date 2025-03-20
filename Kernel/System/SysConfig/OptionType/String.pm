# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SysConfig::OptionType::String;

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

Kernel::System::SysConfig::OptionType::String - String type lib

=head1 SYNOPSIS

All functions for SysConfig option type String.

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
    my %Setting;
    my $DefaultValue;

    if ( IsHashRef($Param{Setting}) ) {
        %Setting = (
            Regex => $Param{Setting}->{Regex} || ''
        );
        $DefaultValue = $Param{Setting}->{content} || '';
    }
    else {
        $DefaultValue = $Param{Setting};
    }

    return (\%Setting, $DefaultValue);
}

=item Decode()

Decodes the JSON data

    my $DecodedData = $OptionTypeObject->Decode(
        Data => '...',
    );

=cut

sub Decode {
    my ( $Self, %Param ) = @_;

    # return data or an empty string to prevent undef errors
    return $Param{Data} || '';
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
