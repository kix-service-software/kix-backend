# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Priority;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Config
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Priority - attribute module for database object search

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
        'Priority'   => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','IN','!IN','NE','LT','LTE','GT','GTE'],
            ValueType    => 'Priority.Name'
        },
        'PriorityID' => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','IN','!IN','NE','LT','LTE','GT','GTE'],
            ValueType    => 'Integer'
        },
    };

    return $Self->{Supported};
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my @PriorityIDs;
    if ( $Param{Search}->{Field} eq 'Priority' ) {
        my @PriorityList = ( $Param{Search}->{Value} );
        if ( IsArrayRef($Param{Search}->{Value}) ) {
            @PriorityList = @{$Param{Search}->{Value}}
        }
        foreach my $Priority ( @PriorityList ) {
            my $PriorityID = $Kernel::OM->Get('Priority')->PriorityLookup(
                Priority => $Priority,
            );
            if ( !$PriorityID ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown priority $Priority!",
                );
                return;
            }

            push( @PriorityIDs, $PriorityID );
        }
    }
    else {
        @PriorityIDs = ( $Param{Search}->{Value} );
        if ( IsArrayRef($Param{Search}->{Value}) ) {
            @PriorityIDs = @{$Param{Search}->{Value}}
        }
    }

    my @SQLWhere;
    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => 'st.ticket_priority_id',
        Value     => \@PriorityIDs,
        Type      => 'NUMERIC',
        Supported => $Self->{Supported}->{$Param{Search}->{Field}}->{Operators}
    );

    return if !@Where;

    push( @SQLWhere, @Where);

    return {
        Where => \@SQLWhere,
    };
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        Select   => [ ],          # optional
        OrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams(%Param) );

    # map search attributes to table attributes
    my %AttributeMapping = (
        Priority    => 'COALESCE(tl.value, tp.name) AS TranslatePriority',
        PriorityID  => 'st.ticket_priority_id',
    );

    my %OrderMapping = (
        Priority    => 'TranslatePriority',
        PriorityID  => 'st.ticket_priority_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'Priority' ) {
        $Join{Join} = [
            'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id',
	        'LEFT OUTER JOIN translation_pattern tlp ON tlp.value = tp.name',
            "LEFT OUTER JOIN translation_language tl ON tl.pattern_id = tlp.id AND tl.language = '$Param{Language}'"
        ];
    }

    return {
        Select => [
            $AttributeMapping{$Param{Attribute}}
        ],
        OrderBy => [
            $OrderMapping{$Param{Attribute}}
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

