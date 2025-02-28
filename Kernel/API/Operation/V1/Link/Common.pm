# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Link::Common;

use strict;
use warnings;

use MIME::Base64();

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Link::Common - Base class for all Link Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=begin Internal:

=item _CheckLink()

checks if the given Link parameter is valid.

    my $CheckResult = $OperationObject->_CheckLink(
        Link => $Link,              # all parameters
    );

    returns:

    $CheckResult = {
        Success => 1,                               # if everything is OK
    }

    $CheckResult = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckLink {
    my ( $Self, %Param ) = @_;

    my $Link = $Param{Link};

    my $LinkObject = $Kernel::OM->Get('LinkObject');

    # check if this link type is allowed
    my %PossibleTypesList = $LinkObject->PossibleTypesList(
        Object1 => $Link->{SourceObject},
        Object2 => $Link->{TargetObject},
    );

    # check if wanted link type is possible
    if ( !$PossibleTypesList{ $Link->{Type} } ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Cannot create Link. The given link type is not supported by the given objects.",
        );
    }

    # check if source and target are the same object
    if ( $Link->{SourceObject} eq $Link->{TargetObject} && $Link->{SourceKey} eq $Link->{TargetKey} ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Cannot create Link. It's not possible to link an object with itself.",
        );
    }

    # lookup the source object id
    my $SourceObjectID = $LinkObject->ObjectLookup(
        Name => $Link->{SourceObject},
    );
    if ( !$SourceObjectID ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Cannot create Link. Unknown SourceObject.",
        );
    }

    # lookup the target object id
    my $TargetObjectID = $LinkObject->ObjectLookup(
        Name => $Link->{TargetObject},
    );
    if ( !$TargetObjectID ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Cannot create Link. Unknown TargetObject.",
        );
    }

    # if everything is OK then return Success
    return $Self->_Success();
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
