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
    Kernel::System::ObjectSearch::Database::Ticket::Common
);

our @ObjectDependencies = (
    'Config',
    'Log',
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
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [
            'Priority',
            'PriorityID'
        ],
        Sort   => [
            'Priority',
            'PriorityID'
        ],
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

    my @PriorityIDs;
    if ( $Param{Search}->{Field} eq 'Priority' ) {
        my @PriorityList = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
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
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @PriorityIDs = @{$Param{Search}->{Value}}
        }
    }

    if ( $Param{Search}->{Operator} eq 'EQ' ) {
        push( @SQLWhere, 'st.ticket_priority_id = '.$PriorityIDs[0] );
    }
    elsif ( $Param{Search}->{Operator} eq 'IN' ) {
        push( @SQLWhere, 'st.ticket_priority_id IN ('.(join(',', @PriorityIDs)).')' );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Search}->{Operator}!",
        );
        return;
    }

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
        Priority    => 'COALESCE(tl.value, tp.name) AS TanslateName',
        PriorityID  => 'st.ticket_priority_id',
    );

    my %OrderMapping = (
        Priority    => 'TanslateName',
        PriorityID  => 'st.ticket_priority_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'Priority' ) {
        $Join{SQLJoin} = [
            'INNER JOIN ticket_priority tp ON tp.id = st.ticket_priority_id',
	        'LEFT OUTER JOIN translation_pattern tlp ON tlp.value = tp.name',
            "LEFT OUTER JOIN translation_language tl ON tl.pattern_id = tlp.id AND tl.language = '$Param{Language}'"
        ];
    }

    return {
        SQLAttrs => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLOrderBy => [
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

