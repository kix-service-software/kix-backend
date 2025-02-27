# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::BasePermission;

use strict;
use warnings;

use Kernel::System::Role::Permission qw(:all);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::Ticket::BasePermission - ticket base permission lib

=head1 SYNOPSIS

All ticket base permission functions.

=over 4

=cut

=item BasePermissionValidate()

validate a given base permission.

    my $Success = $TicketObject->BasePermissionValidate(
        Target => '...',
        Value  => ...
    );
=cut

sub BasePermissionValidate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach my $Key ( qw(Target) ) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # wildcard is always valid
    return 1 if $Param{Target} eq '*';

    return $Kernel::OM->Get('Queue')->QueueLookup(
        QueueID => $Param{Target} || 0,
        Silent  => 1,
    );
}

=item BasePermissionRelevantQueueUserIDList()
    determines user ids for given base permissions.

    my @UserIDs = $QueueObject->BasePermissionRelevantQueueUserIDList(
        QueueID       => 2,
        Permission    => '...',
        IsAgent       => 0|1,
        Strict        => 0|1            # Default: 0, only the given permission, no combined ones (example: READ + Strict = READONLY)
    );
=cut

sub BasePermissionRelevantQueueUserIDList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach my $Key ( qw(Permission QueueID) ) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    my $Value = 0;
    PERMISSION:
    foreach my $Permission ( split(/,/, $Param{Permission}) ) {
        $Value |= Kernel::System::Role::Permission::PERMISSION->{$Permission};
    }

    my @UserIDs = $Kernel::OM->Get('Role')->BasePermissionAgentList(
        Target    => $Param{QueueID},
        Value     => $Value,
        Strict    => $Param{Strict}
    );

    return @UserIDs;
}

=item BasePermissionRelevantObjectIDList()

validate a given base permission.

    my $Success = $QueueObject->BasePermissionRelevantObjectIDList(
        Permission    => '...',
        UsageContext  => ...,
        UserID        => 1,
        Strict        => 0|1            # Default: 0, only the given permission, no combined ones (example: READ + Strict = READONLY)
    );
=cut

sub BasePermissionRelevantObjectIDList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach my $Key ( qw(Permission UsageContext UserID) ) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    my $Value = 0;
    foreach my $Permission ( split(/,/, $Param{Permission}) ) {
        $Value |= Kernel::System::Role::Permission::PERMISSION->{$Permission};
    }

    # check if we have base permissions for this user in this usage context
    my %PermissionList = $Kernel::OM->Get('User')->PermissionList(
        UserID       => $Param{UserID},
        UsageContext => $Param{UsageContext},
        Types        => ['Base::Ticket'],
    );
    return 1 if !%PermissionList;

    # combine permissions on same target
    my %CombinedPermissions;
    foreach my $Permission ( values %PermissionList ) {
        $CombinedPermissions{$Permission->{Target}} //= 0;
        $CombinedPermissions{$Permission->{Target}} |= $Permission->{Value};
    }

    my @QueueIDs;

    TARGET:
    foreach my $Target ( keys %CombinedPermissions ) {
        next TARGET if !$Param{Strict} && ($CombinedPermissions{$Target} & $Value) != $Value;
        next TARGET if $Param{Strict} && $CombinedPermissions{$Target} ne $Value;

        if ( $Target !~ /\*/ ) {
            push @QueueIDs, $Target;
        }
        else {
            if ( !IsHashRef($Self->{QueueListReverse}) ) {
                $Self->{QueueListReverse} = { reverse $Kernel::OM->Get('Queue')->QueueList(Valid => 0) };
            }
            my $Pattern = $Target;
            $Pattern =~ s/\*/.*/g;

            QUEUE:
            foreach my $Queue ( sort keys %{$Self->{QueueListReverse}} ) {
                next QUEUE if $Queue !~ /^$Pattern$/;
                push @QueueIDs, $Self->{QueueListReverse}->{$Queue};
            }
        }
    }

    return if !@QueueIDs;

    @QueueIDs = sort( $Kernel::OM->Get('Main')->GetUnique( @QueueIDs ) );

    return \@QueueIDs;
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
