# --
# Modified version of the work: Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::GeneralCatalog::BasePermission;

use strict;
use warnings;

use Kernel::System::Role::Permission qw(:all);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::GeneralCatalog::BasePermission - Asset base permission lib

=head1 SYNOPSIS

All Asset base permission functions.

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

    return $Kernel::OM->Get('GeneralCatalog')->ItemLookup(
        ItemID => $Param{Target} || 0,
        Silent  => 1,
    );
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
        Types        => ['Base::Asset'],
    );
    return 1 if !%PermissionList;

    # combine permissions on same target
    my %CombinedPermissions;
    foreach my $Permission ( values %PermissionList ) {
        $CombinedPermissions{$Permission->{Target}} //= 0;
        $CombinedPermissions{$Permission->{Target}} |= $Permission->{Value};
    }

    my @ItemIDs = ();

    TARGET:
    foreach my $Target ( keys %CombinedPermissions ) {
        next TARGET if !$Param{Strict} && ($CombinedPermissions{$Target} & $Value) != $Value;
        next TARGET if $Param{Strict} && $CombinedPermissions{$Target} ne $Value;

        if ( $Target !~ /\*/ ) {
            push @ItemIDs, $Target;
        }
        else {
            if ( !IsHashRef($Self->{ItemListReverse}) ) {
                $Self->{ItemListReverse} = $Kernel::OM->Get('GeneralCatalog')->ItemList(
                    Valid => 0,
                    Class => 'ITSM::ConfigItem::Class'
                );
            }
            my $Pattern = $Target;
            $Pattern =~ s/\*/.*/g;

            ITEM:
            foreach my $Item ( sort keys %{$Self->{ItemListReverse}} ) {
                next ITEM if $Item !~ /^$Pattern$/;
                push @ItemIDs, $Item;
            }
        }
    }

    @ItemIDs = sort( $Kernel::OM->Get('Main')->GetUnique( @ItemIDs ) );

    return \@ItemIDs;
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
