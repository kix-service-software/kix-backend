# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Role::GenericIncludeHandler;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Link::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Role::GenericIncludeHandler - API Handler

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
    for my $Needed (qw(DebuggerObject WebserviceID)) {
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

This will return a list with objects.

    my $Result = $Object->Run();

    $Result = {
        Assigned => [],
        DependingObjects => []
    }

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @RelevantPropertyValuePermissions = split(/\s*,\s*/, ($Param{OperationConfig}->{RelevantPropertyValuePermissions} || ''));

    my %Permissions = $Kernel::OM->Get('Role')->PermissionListForObject(
        RelevantPropertyValuePermissions => \@RelevantPropertyValuePermissions,
        Target        => $Param{RequestURI},
        ObjectID      => $Param{ObjectID},
        ObjectIDAttr  => $Param{OperationConfig}->{ObjectID},
    );

    return \%Permissions;
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
