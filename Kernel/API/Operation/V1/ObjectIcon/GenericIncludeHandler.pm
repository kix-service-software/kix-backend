# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectIcon::GenericIncludeHandler;

use strict;
use warnings;

use Kernel::API::Operation::V1::ObjectIcon::ObjectIconSearch;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::ObjectIcon::GenericIncludeHandler - API Handler

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

This will return a ObjectIcon ID.

    my $Result = $Object->Run(
        Object     => '...',        # required
        ObjectID   => '...'         # required
    );

    $Result = 123

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check required parameters
    foreach my $Key ( qw(Object ObjectID UserID) ) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # For some objects it is necessary to change the object to get the right icon
    # because they are stored on top of another object.
    my $Object        = $Param{Object};
    my $Config        = $Kernel::OM->Get('Config')->Get('API::Operation::GenericInclude');
    my $ObjectMapping = $Config->{ObjectIcon}->{ObjectMapping} || {};

    if (
        IsHashRefWithData($ObjectMapping)
        && $ObjectMapping->{$Object}
    ) {
        $Object = $ObjectMapping->{$Object};
    }

    # perform ObjectIcon search
    my $IconIDs = $Kernel::OM->Get('ObjectIcon')->ObjectIconList(
        Object   => $Object,
        ObjectID => $Param{ObjectID},
        UserID   => $Param{UserID},
    );

    if ( !IsArrayRefWithData($IconIDs) ) {
        return;
    }

    # return result
    return $IconIDs->[0];
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
