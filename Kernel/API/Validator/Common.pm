# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Validator::Common;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

use base qw(
    Kernel::API::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Validator::Common - Base class for validators

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object.

    use Kernel::API::Validator;

    my $ValidatorObject = Kernel::API::Validator::XYZValidator->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Validate()

validate a attribute in the data hash

    my $Result = $ValidatorObject->Validate(
        Attribute => '...',
        Data      => {
            ...
        }
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
    };

=cut

sub Validate {
    my ( $Self, %Param ) = @_;

    return {
        Success => 1
    };
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
