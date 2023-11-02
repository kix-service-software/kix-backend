# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::ConfigItem::InciState;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::ConfigItem::InciState - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Property => {
            IsSortable     => 0|1,
            IsSearchable => 0|1,
            Operators     => []
        },
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [
            'InciStateID',
            'InciStateIDs',
            'InciState'
        ],
        Sort => [
            'InciStateID',
            'InciStateIDs',
            'InciState'
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

    my @InciStateIDs;
    if ( $Param{Search}->{Field} eq 'InciState' ) {
        my %States = reverse(
            %{$Kernel::OM->Get('GeneralCatalog')->ItemList(
                Class => 'ITSM::ConfigItem::IncidentState',
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
                    Message  => "Unknown incident state $State!",
                );
                return;
            }

            push( @InciStateIDs, $States{$State} );
        }
    }
    else {
        @InciStateIDs = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @InciStateIDs = @{$Param{Search}->{Value}}
        }
    }

    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => 'ci.cur_inci_state_id',
        Value     => \@InciStateIDs,
        Supported => [
            'EQ', 'NE', 'IN'
        ]
    );

    return if !@Where;

    push( @SQLWhere, @Where);

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
        InciState    => 'gc.name',
        InciStateID  => 'ci.cur_inci_state_id',
        InciStateIDs => 'ci.cur_inci_state_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'InciState' ) {
        $Join{SQLJoin} = [
            'INNER JOIN general_catalog gci ON gci.id = ci.cur_inci_state_id'
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
