# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::State;

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

Kernel::System::ObjectSearch::Database::Ticket::State - attribute module for database object search

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
        'StateID'     => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','IN','!IN','NE','LT','LTE','GT','GTE'],
            ValueType    => 'Integer'
        },
        'State'       => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','IN','!IN','NE','LT','LTE','GT','GTE'],
            ValueType    => 'State.Name'
        },
        'StateType'   => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','IN','!IN','NE','LT','LTE','GT','GTE'],
            ValueType    => 'StateType.Name'
        },
        'StateTypeID' => {
            IsSearchable => 1,
            IsSortable   => 0,
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
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    my $Operator = $Param{Search}->{Operator};
    my $Value    = $Param{Search}->{Value};
    my @StateIDs;

    # special handling for StateType
    if ( $Param{Search}->{Field} eq 'StateType' ) {

        # get all StateIDs for the given StateTypes
        my @StateTypes = ( $Value );
        if ( IsArrayRef($Value) ) {
            @StateTypes = @{$Value};
        }

        foreach my $StateType ( @StateTypes ) {

            if ( $StateType eq 'Open' ) {
                # get all viewable states
                my @ViewableStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
                    Type   => 'Viewable',
                    Result => 'ID',
                );
                push(@StateIDs, @ViewableStateIDs);
            }
            elsif ( $StateType eq 'Closed' ) {
                # get all non-viewable states
                my %AllStateIDs = $Kernel::OM->Get('State')->StateList(
                    UserID => 1,
                );
                my %ViewableStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
                    Type   => 'Viewable',
                    Result => 'HASH',
                );
                foreach my $StateID ( sort keys %AllStateIDs ) {
                    next if $ViewableStateIDs{$StateID};
                    push(@StateIDs, $StateID);
                }
            }
            else {
                my @StateTypeStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
                    StateType => $StateType,
                    Result    => 'ID',
                );
                if ( !@StateTypeStateIDs ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "No states found for StateType $StateType!",
                    );
                } else {
                    push(@StateIDs, @StateTypeStateIDs);
                }
            }
        }

        # we have to do an IN seasrch in this case
        $Operator = 'IN';
    }
    elsif ( $Param{Search}->{Field} eq 'StateTypeID' ) {

        # get all StateIDs for the given StateTypeIDs
        my @StateTypeIDs = ( $Value );
        if ( IsArrayRef($Value) ) {
            @StateTypeIDs = @{$Value};
        }

        foreach my $StateTypeID ( @StateTypeIDs ) {
            my $StateType = $Kernel::OM->Get('State')->StateTypeLookup(
                StateTypeID => $StateTypeID,
            );
            if ( !$StateType ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "No StateType with ID $StateTypeID!",
                );
                return;
            }
            my @StateTypeStateIDs = $Kernel::OM->Get('State')->StateGetStatesByType(
                StateType => $StateType,
                Result    => 'ID',
            );

            push(@StateIDs, @StateTypeStateIDs);
        }

        # we have to do an IN seasrch in this case
        $Operator = 'IN';
    }
    elsif ( $Param{Search}->{Field} eq 'State' ) {
        my @StateList = ( $Param{Search}->{Value} );
        if ( IsArrayRef($Param{Search}->{Value}) ) {
            @StateList = @{$Param{Search}->{Value}}
        }
        foreach my $State ( @StateList ) {
            my $StateID = $Kernel::OM->Get('State')->StateLookup(
                State => $State,
            );
            if ( !$StateID ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown state $State!",
                );
                return;
            }

            push( @StateIDs, $StateID );
        }
    }
    else {
        @StateIDs = ( $Param{Search}->{Value} );
        if ( IsArrayRef($Param{Search}->{Value}) ) {
            @StateIDs = @{$Param{Search}->{Value}}
        }
    }

    my @SQLWhere;
    my @Where = $Self->GetOperation(
        Operator  => $Operator,
        Column    => 'st.ticket_state_id',
        Value     => \@StateIDs,
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

    # map search attributes to table attributes
    my %AttributeMapping = (
        State    => 'COALESCE(tl.value, ts.name) AS TranslateState',
        StateID  => 'st.ticket_state_id',
    );

    my %OrderMapping = (
        State    => 'TranslateState',
        StateID  => 'st.ticket_state_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'State' ) {
        $Join{Join} = [
            'INNER JOIN ticket_state ts ON ts.id = st.ticket_state_id',
	        'LEFT OUTER JOIN translation_pattern tlp ON tlp.value = ts.name',
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
