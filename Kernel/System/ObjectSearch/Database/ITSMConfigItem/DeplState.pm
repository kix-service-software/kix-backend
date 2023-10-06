# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ITSMConfigItem::DeplState;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::ITSMConfigItem::Common
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::ITSMConfigItem::DeplState - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [
            'DeplStateID',
            'DeplStateIDs',
            'DeplState'
        ],
        Sort => [
            'DeplStateID',,
            'DeplStateIDs',
            'DeplState'
        ]
    };
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        SQLWhere   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    my @DeplStateIDs;
    if ( $Param{Search}->{Field} eq 'DeplState' ) {
        my %States = reverse(
            %{$Kernel::OM->Get('GeneralCatalog')->ItemList(
                Class => 'ITSM::ConfigItem::DeploymentState',
            )}
        );

        my @StateList = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @StateList = @{$Param{Search}->{Value}}
        }
        foreach my $State ( @StateList ) {
            if ( !$States{$State} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown deplayment state $State!",
                );
                return;
            }

            push( @DeplStateIDs, $States{$State} );
        }
    }
    else {
        @DeplStateIDs = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @DeplStateIDs = @{$Param{Search}->{Value}}
        }
    }

    my %SupportedOperator = (
        'EQ' => 1,
        'NE' => 1,
        'IN' => 1,
    );

    if ( !$SupportedOperator{$Param{Search}->{Operator}} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Search}->{Operator}!",
        );
        return;
    }

    my $Where = $Self->GetOperation(
        Operator => $Param{Search}->{Operator},
        Column   => 'ci.cur_depl_state_id',
        Value    => \@DeplStateIDs,
    );

    return if !$Where;

    push( @SQLWhere, $Where);

    return {
        SQLWhere => \@SQLWhere,
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        SQLAttrs   => [ ],          # optional
        SQLOrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # map search attributes to table attributes
    my %AttributeMapping = (
        DeplState    => 'gc.name',
        DeplStateID  => 'ci.cur_depl_state_id',
        DeplStateIDs => 'ci.cur_depl_state_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'DeplState' ) {
        $Join{SQLJoin} = [
            'INNER JOIN general_catalog gcd ON gcd.id = ci.cur_depl_state_id'
        ];
    }

    return {
        SQLAttrs => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLOrderBy => [
            $AttributeMapping{$Param{Attribute}}
        ],
        %Join
    };
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
