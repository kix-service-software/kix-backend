# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::VariableCheck;

use strict;
use warnings;

use Data::Validate::IP qw(is_ipv4 is_ipv6);

use Exporter qw(import);
our %EXPORT_TAGS = (    ## no critic
    all => [
        'IsArrayRef',
        'IsArrayRefWithData',
        'IsBase64',
        'IsCodeRef',
        'IsHashRef',
        'IsHashRefWithData',
        'IsInteger',
        'IsMD5Sum',
        'IsNotEqual',
        'IsNumber',
        'IsObject',
        'IsPositiveInteger',
        'IsString',
        'IsStringWithData',
        'DataIsDifferent',
    ],
);
Exporter::export_ok_tags('all');

=head1 NAME

Kernel::System::VariableCheck - helper functions to check variables

=head1 SYNOPSIS

Provides several helper functions to check variables, e.g.
if a variable is a string, a hash ref etc. This is helpful for
input data validation, for example.

Call this module directly without instantiating:

    use Kernel::System::VariableCheck qw(:all);              # export all functions into the calling package
    use Kernel::System::VariableCheck qw(IsHashRefWithData); # export just one function

    if (IsHashRefWithData($HashRef)) {
        ...
    }

The functions can be grouped as follows:

=head2 Variable type checks

=over 4

=item * L</IsString()>

=item * L</IsStringWithData()>

=item * L</IsArrayRefWithData()>

=item * L</IsHashRefWithData()>


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
