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

    $Self->{Supported} = {
        InciStateID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        InciStateIDs => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        InciState => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        }
    };

    return $Self->{Supported};
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
    my @SQLJoin;
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

    my $TablePrefix = 'ci';
    my $ColPrefix   = 'cur_';
    if ( $Param{Flags}->{PreviousVersion} ) {
        $TablePrefix = 'vr';
        $ColPrefix   = q{};

        if ( !$Param{Flags}->{JoinVersion} ) {
            push(
                @SQLJoin,
                'LEFT OUTER JOIN configitem_version vr on ci.id = vr.configitem_id'
            );
            $Param{Flags}->{JoinVersion} = 1;
        }
    }

    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => $TablePrefix . q{.} . $ColPrefix . 'inci_state_id',
        Value     => \@InciStateIDs,
        Type      => 'NUMERIC',
        Supported => $Self->{Supported}->{$Param{Search}->{Field}}->{Operators}
    );

    return if !@Where;

    push( @SQLWhere, @Where);

    return {
        SQLWhere => \@SQLWhere,
        SQLJoin  => \@SQLJoin,
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

    my @SQLJoin;
    my $TablePrefix = 'ci';
    my $ColPrefix   = 'cur_';
    if ( $Param{Flags}->{PreviousVersion} ) {
        $TablePrefix = 'vr';
        $ColPrefix   = q{};

        if ( !$Param{Flags}->{JoinVersion} ) {
            push(
                @SQLJoin,
                ' LEFT OUTER JOIN configitem_version vr on ci.id = vr.configitem_id'
            );
            $Param{Flags}->{JoinVersion} = 1;
        }
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        InciState    => 'gci.name',
        InciStateID  => $TablePrefix .q{.} . $ColPrefix . 'inci_state_id',
        InciStateIDs => $TablePrefix .q{.} . $ColPrefix . 'inci_state_id',
    );

    if ( $Param{Attribute} eq 'InciState' ) {
        push(
            @SQLJoin,
            ' INNER JOIN general_catalog gci ON gci.id = '
                . $TablePrefix
                . q{.}
                . $ColPrefix
                . 'inci_state_id'
        );
    }

    return {
        SQLAttrs => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLOrderBy => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLJoin => \@SQLJoin
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
