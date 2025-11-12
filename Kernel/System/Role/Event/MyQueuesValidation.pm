# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Role::Event::MyQueuesValidation;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Log
    Main
    Role
    User
);

use Kernel::System::VariableCheck qw(:all);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(Data Event Config) ) {
        if ( !$Param{ $Needed } ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if (
        $Param{Event} eq 'RoleUpdate'
        || $Param{Event} eq 'RolePermissionUpdate'
        || $Param{Event} eq 'RolePermissionDelete'
    ) {
        if ( !$Param{Data}->{RoleID} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need RoleID in Data!"
            );
            return;
        }

        my @UserList = $Kernel::OM->Get('Role')->RoleUserList(
            RoleID => $Param{Data}->{RoleID},
        );

        $Self->_HandleUserList(
            UserIDs => \@UserList
        );
    }
    elsif( $Param{Event} eq 'RoleUserDelete' ) {
        if ( IsArrayRefWithData( $Param{Data}->{UserIDs} ) ) {
            $Self->_HandleUserList(
                UserIDs => $Param{Data}->{UserIDs}
            );
        }
    }

    return 1;
}

sub _HandleUserList {
    my ( $Self, %Param ) = @_;

    for my $UserID ( @{ $Param{UserIDs} } ) {
        my %Preferences = $Kernel::OM->Get('User')->GetPreferences(
            UserID => $UserID,
        );

        my $MyQueueList;
        if ( !defined( $Preferences{MyQueues} ) ) {
            return 1;
        }
        elsif( IsArrayRef( $Preferences{MyQueues} ) ) {
            $MyQueueList = $Preferences{MyQueues};
        }
        else {
            $MyQueueList = [ $Preferences{MyQueues} ];
        }

        my @AllowedQueueList = $Self->_GetAllowedQueues(
            UserID => $UserID
        );
        # get intersection of selected list and allowed list
        my @CombinedList = $Kernel::OM->Get('Main')->GetCombinedList(
            ListA => $MyQueueList,
            ListB => \@AllowedQueueList,
            Union => 0,
        );

        if ( scalar( @{ $MyQueueList } ) != scalar( @CombinedList ) ) {
            $Kernel::OM->Get('User')->SetPreferences(
                Key    => 'MyQueues',
                Value  => \@CombinedList,
                UserID => $UserID,
            );
        }
    }

    return 1;
}

sub _GetAllowedQueues {
    my ( $Self, %Param ) = @_;

    # perform Queue search
    my %QueueList = $Kernel::OM->Get('Queue')->QueueList(
        Valid => 0
    );

    if ( %QueueList ) {
        my %BasePermissionQueueIDs;

        my $Result = $Kernel::OM->Get('Ticket')->BasePermissionRelevantObjectIDList(
            UserID       => $Param{UserID},
            UsageContext => 'Agent',
            Permission   => 'WRITE,READ',
        );

        if ( IsArrayRefWithData($Result) ) {
            # get intersection of avaiable queue list and base permission list
            my @QueueIDs     = keys( %QueueList );
            my @CombinedList = $Kernel::OM->Get('Main')->GetCombinedList(
                ListA => $Result,
                ListB => \@QueueIDs,
                Union => 0,
            );

            %BasePermissionQueueIDs = (
                %BasePermissionQueueIDs,
                map { $_ => 1 } @CombinedList,
            );
        }

        if ( %BasePermissionQueueIDs ) {
            %QueueList = %BasePermissionQueueIDs;
        } elsif ( $Result ne 1 ) {
            %QueueList = ();
        }
        else {
            my $HasPermission = $Kernel::OM->Get('User')->CheckResourcePermission(
                UserID              => $Param{UserID},
                UsageContext        => 'Agent',
                Target              => '/tickets',
                RequestedPermission => 'WRITE,READ',
            );

            if ( !$HasPermission ) {
                %QueueList = ();
            }
        }
    }

    return keys( %QueueList );
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
