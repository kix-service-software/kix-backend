# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonObjectType
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket - object type module for object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # init join map as empty hash
    $Param{Flags}->{JoinMap} = {};

    # init flag join counter with 0
    $Param{Flags}->{ArticleFlagJoinCounter} = 0;
    $Param{Flags}->{TicketFlagJoinCounter} = 0;

    # init dynamic field join counter with 0
    $Param{Flags}->{DynamicFieldJoinCounter} = 0;

    # init translation join counter with 0
    $Param{Flags}->{TranslationJoinCounter} = 0;

    # init sla join counter with 0
    $Param{Flags}->{SLAJoinCounter} = 0;

    # init sla criterion join counter with 0
    $Param{Flags}->{SLACriterionJoinCounter} = 0;

    # init sort attribute counter with 0
    $Param{Flags}->{SortAttributeCounter} = 0;

    return 1;
}

sub GetBaseDef {
    my ( $Self, %Param ) = @_;

    return {
        Select  => ['st.id', 'st.tn'],
        From    => ['ticket st'],
        OrderBy => ['st.id ASC']
    };
}

sub GetPermissionDef {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw( UserID UserType ) ) {
        if ( !$Param{ $Needed } ) {
            return {
                Where => [ '0=1' ]
            };
        }
    }

    # set default permission
    $Param{Permission} ||= 'READ';

    # init collection for permission search parts
    my @PermissionSearchParts = ();

    # get allowed queues by base permission
    my $QueueIDs = $Kernel::OM->Get('Ticket')->BasePermissionRelevantObjectIDList(
        %Param,
        Types        => ['Base::Ticket'],
        UsageContext => $Param{UserType},
        Permission   => $Param{Permission},
    );
    # user has no base permission in this context, nothing to prepare
    if(
        !IsArrayRef( $QueueIDs )
        && $QueueIDs
    ) {
        return {};
    }
    # set queue filter
    elsif ( IsArrayRefWithData( $QueueIDs ) ) {
        push(
            @PermissionSearchParts,
            {
                'Field'    => 'QueueID',
                'Operator' => 'IN',
                'Value'    => $QueueIDs
            }
        );
    }
    # set queue filter without values (will provide 0=1)
    else {
        push(
            @PermissionSearchParts,
            {
                'Field'    => 'QueueID',
                'Operator' => 'IN',
                'Value'    => []
            }
        );
    }

    my $PermissionModules = $Kernel::OM->Get('Config')->Get('Ticket::BasePermissionModule') || {};
    PERMISSION_MODULE:
    for my $PermissionModule ( sort( keys( %{ $PermissionModules } ) ) ) {
        next PERMISSION_MODULE if ( !$PermissionModules->{ $PermissionModule }->{Module} );

        my $Backend = $PermissionModules->{ $PermissionModule }->{Module};

        if ( !$Kernel::OM->Get('Main')->Require( $Backend ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to require $Backend!"
            );
            next PERMISSION_MODULE;
        }

        my $BackendObject = $Backend->new( %{ $Self } );
        if ( !$BackendObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create instance of $Backend!"
            );
            next PERMISSION_MODULE;
        }
        $BackendObject->{Config} = $PermissionModules->{ $PermissionModule };

        my $Result = $BackendObject->Run(
            %Param,
            BasePermissionQueueIDs => $QueueIDs,
            UserID                 => $Param{UserID},
            ReturnType             => 'ObjectSearch',
        );
        next PERMISSION_MODULE if ( !IsHashRefWithData( $Result ) );

        push( @PermissionSearchParts, $Result );
    }

    # get permission search def from backend
    return $Self->GetSearchDef(
        %Param,
        Search => {
            OR => \@PermissionSearchParts
        }
    );
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