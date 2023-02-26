# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::BasePermission;

use strict;
use warnings;

use Kernel::System::Role::Permission;

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

=item BasePermissionRelevantObjectIDList()

validate a given base permission.

    my $Success = $QueueObject->BasePermissionRelevantObjectIDList(
        Target => '...',
        Value  => ...
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

    my @Values = (
        Kernel::System::Role::Permission::PERMISSION_CRUD
    );
    if ( $Param{Permission} eq 'READ' ) {
        push @Values, Kernel::System::Role::Permission::PERMISSION->{READ};
    }

    my %PermissionList = $Kernel::OM->Get('User')->PermissionList(
        UserID       => $Param{UserID},
        UsageContext => $Param{UsageContext},
        Types        => ['Base::Ticket'],
        Values       => \@Values,
    );

    my @QueueIDs;

    PERMISSION:
    foreach my $Permission ( values %PermissionList ) {
        if ( $Permission->{Target} !~ /\*/ ) {
            push @QueueIDs, $Permission->{Target};
        }
        else {
            if ( !IsHashRef($Self->{QueueListReverse}) ) {
                $Self->{QueueListReverse} = { reverse $Kernel::OM->Get('Queue')->QueueList(Valid => 0) };
            }
            my $Pattern = $Permission->{Target};
            $Pattern =~ s/\*/.*/g;

            QUEUE:
            foreach my $Queue ( sort keys %{$Self->{QueueListReverse}} ) {
                next QUEUE if $Queue !~ /^$Pattern$/;
                push @QueueIDs, $Self->{QueueListReverse}->{$Queue};
            }
        }
    }

    return @QueueIDs;
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
