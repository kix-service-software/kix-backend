#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/plugins';
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::Role::Permission;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-2177',
    },
);

use vars qw(%INC);

_UpdateChartReportPermissions();

sub _UpdateChartReportPermissions {
    my ( $Self, %Param ) = @_;

    # prepare relevant roles
    my @Roles = (
        'Report User',
        'Ticket Agent',
        'Ticket Reader',
        'Ticket Agent Base Permission',
    );

    # lookup role ids
    my @RoleIDs = ();
    for my $Role ( @Roles ) {
        my $RoleID = $Kernel::OM->Get('Role')->RoleLookup(
            Role => $Role,
        );
        if ( $RoleID ) {
            push( @RoleIDs, $RoleID );
        }
    }
    return 1 if ( !@RoleIDs );

    # lookup report definition id
    my $DefinitionID = $Kernel::OM->Get('Reporting')->ReportDefinitionLookup(
        Name => 'Number of open tickets by statetype',
    );
    return 1 if ( !$DefinitionID );

    # get ID of Resource permission type
    my $ResourcePermissionTypeID = $Kernel::OM->Get('Role')->PermissionTypeLookup(
        Name => 'Resource'
    );
    if (!$ResourcePermissionTypeID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Cannot find permission type 'Resource'."
        );
    }

    for my $RoleID ( @RoleIDs ) {
        next if $Kernel::OM->Get('Role')->PermissionLookup(
            RoleID => $RoleID,
            TypeID => $ResourcePermissionTypeID,
            Target => '/reporting/reportdefinitions/' . $DefinitionID
        );

        # assign resource permission
        my $Result = $Kernel::OM->Get('Role')->PermissionAdd(
            RoleID     => $RoleID,
            TypeID     => $ResourcePermissionTypeID,
            Target     => '/reporting/reportdefinitions/' . $DefinitionID,
            Value      => Kernel::System::Role::Permission::PERMISSION->{READ},
            IsRequired => 0,
            Comment    => "Permission for role.",
            UserID     => 1,
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message => "Could not create object permission for role '$RoleID' on /reporting/reportdefinitions/$DefinitionID",
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Created object permission for role '$RoleID' on /reporting/reportdefinitions/$DefinitionID"
            );
        }
    }

    my @Permissions = $Kernel::OM->Get('Role')->PermissionListGet(
        RoleIDs => \@RoleIDs,
        Types   => ['Object'],
        Target  => '/reporting/reports%Report.DefinitionID%IN%'
    );
    for my $Permission ( @Permissions ) {
        if ( $Permission->{Target} =~ m/IN \[(.+)\]/ ) {
            my $IDList = $1;
            my @DefinitionIDs = split( ',', $IDList );

            push( @DefinitionIDs, $DefinitionID );

            @DefinitionIDs = $Kernel::OM->Get('Main')->GetUnique(@DefinitionIDs);

            my $NewIDList = join(',', @DefinitionIDs);
            my $NewTarget = $Permission->{Target};
            $NewTarget =~ s/\[.+\]/[$NewIDList]/;

            if ( $Permission->{Target} ne $NewTarget ) {
                my $Success = $Kernel::OM->Get('Role')->PermissionUpdate(
                    %{ $Permission },
                    Target => $NewTarget,
                    UserID => 1
                );
                if ( !$Success ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message => "Could not update report object permission for role '$Permission->{RoleID}'",
                    );
                }
                else {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message  => "Updated report object permission for role '$Permission->{RoleID}'"
                    );
                }
            }
        }
    }

    return 1;
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
