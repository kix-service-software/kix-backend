# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
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

=item Run()

This will return a list with objects.

    my $Result = $Object->Run();

    $Result = [
        {...},
        {...}
    }

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

    my @RelevantBasePermissions = split(/\s*,\s*/, ($Param{OperationConfig}->{RelevantBasePermissions} || ''));

    my @Permissions = $Kernel::OM->Get('Role')->PermissionListForObject(
        RelevantBasePermissions => \@RelevantBasePermissions,
        Target                  => $Param{ObjectID},
    );

    return \@Permissions;
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
