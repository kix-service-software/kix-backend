# --
# Kernel/API/Operation/Link/LinkCreate.pm - API Link Create operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
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

    my %Permissions = $Kernel::OM->Get('Kernel::System::Role')->PermissionListForObject(
        RelevantPropertyValuePermissions => \@RelevantPropertyValuePermissions,
        Target        => $Param{RequestURI},
        ObjectID      => $Param{ObjectID},
        ObjectIDAttr  => $Param{OperationConfig}->{ObjectID},
    );

    return \%Permissions;
}

1;