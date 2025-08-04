# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::TicketTimes;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::TicketTimes - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Age            => {
            IsSelectable   => 0,
            IsSearchable   => 0,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => []
        },
        CreateTime     => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        },
        PendingTime    => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        },
        LastChangeTime => {
            IsSelectable   => 1,
            IsSearchable   => 1,
            IsSortable     => 1,
            IsFulltextable => 0,
            Operators      => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType      => 'DATETIME'
        }
    };
}

sub AttributePrepare {
    my ( $Self, %Param ) = @_;

    # init Definition
    my %AttributeDefinition = (
        Age            => {
            Column => 'st.create_time_unix',
        },
        CreateTime     => {
            Column       => 'st.create_time_unix',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        PendingTime    => {
            Column       => 'st.until_time',
            ConditionDef => {
                ValueType => 'NUMERIC'
            }
        },
        LastChangeTime => {
            Column       => 'st.change_time',
            ConditionDef => {}
        }
    );

    my %Attribute = (
        Column => $AttributeDefinition{ $Param{Attribute} }->{Column}
    );
    if ( $Param{PrepareType} eq 'Condition' ) {
        $Attribute{ConditionDef} = $AttributeDefinition{ $Param{Attribute} }->{ConditionDef};
    }
    elsif ( $Param{PrepareType} eq 'Sort' ) {
        if ( $Param{Attribute} eq 'Age' ) {
            $Attribute{SQLDef} = {
                OrderBySwitch => 1
            };
        }
    }

    return \%Attribute;
}

sub ValuePrepare {
    my ($Self, %Param) = @_;

    return if !$Param{Search}->{Value};

    return $Param{Search}->{Value} if (
        $Param{Search}->{Field} ne 'CreateTime'
        && $Param{Search}->{Field} ne 'PendingTime'
    );

    # prepare given values as array ref and convert if required
    my $Values = [];
    if ( !IsArrayRef( $Param{Search}->{Value} ) ) {
        push( @{ $Values }, $Param{Search}->{Value} );
    }
    else {
        $Values = $Param{Search}->{Value};
    }

    # convert timestamp to system time
    for my $Value ( @{ $Values } ) {
        $Value = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => $Value
        );
        if ( !$Value ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid date format found in parameter $Param{Search}->{Field}!",
            );
            return;
        }

        $Value = $Kernel::OM->Get('DB')->Quote( $Value );
    }

    return $Values;
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
