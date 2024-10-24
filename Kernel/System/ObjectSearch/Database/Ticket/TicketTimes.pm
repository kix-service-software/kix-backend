# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
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
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'
        },
        CreateTime     => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        },
        PendingTime    => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        },
        LastChangeTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        Age            => {
            Column    => 'st.create_time_unix',
            ValueType => 'NUMERIC',
            Convert   => 'Age'
        },
        CreateTime     => {
            Column    => 'st.create_time_unix',
            ValueType => 'NUMERIC',
            Convert   => 'TimeStamp2SystemTime'
        },
        PendingTime    => {
            Column    => 'st.until_time',
            ValueType => 'NUMERIC',
            Convert   => 'TimeStamp2SystemTime'
        },
        LastChangeTime => {
            Column    => 'st.change_time',
        }
    );

    # prepare given values as array ref and convert if required
    my $Values = [];
    if ( !IsArrayRef( $Param{Search}->{Value} ) ) {
        push( @{ $Values },  $Param{Search}->{Value}  );
    }
    else {
        $Values =  $Param{Search}->{Value} ;
    }
    if ( $AttributeMapping{ $Param{Search}->{Field} }->{Convert} ) {
        for my $Value ( @{ $Values } ) {
            if ( $AttributeMapping{ $Param{Search}->{Field} }->{Convert} eq 'Age' ) {
                # calculate unixtime
                $Value = $Kernel::OM->Get('Time')->SystemTime() - $Value;

                # remember that this is a relative search
                $Param{Search}->{IsRelative} = 1;
            }
            elsif ( $AttributeMapping{ $Param{Search}->{Field} }->{Convert} eq 'TimeStamp2SystemTime' ) {
                $Value = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                    String => $Value
                );
            }
        }
    }

    # prepare condition
    my $Condition = $Self->_GetCondition(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{ $Param{Search}->{Field} }->{Column},
        ValueType => $AttributeMapping{ $Param{Search}->{Field} }->{ValueType},
        Value     => $Values,
        Silent    => $Param{Silent}
    );
    return if ( !$Condition );

    # return search def
    return {
        Where      => [ $Condition ],
        IsRelative => $Param{Search}->{IsRelative}
    };
}

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams( %Param ) );

    # init mapping
    my %AttributeMapping = (
        Age            => 'st.create_time_unix',
        CreateTime     => 'st.create_time_unix',
        PendingTime    => 'st.until_time',
        LastChangeTime => 'st.change_time'
    );

    # return sort def
    return {
        Select        => [ $AttributeMapping{ $Param{Attribute} } ],
        OrderBy       => [ $AttributeMapping{ $Param{Attribute} } ],
        OrderBySwitch => ( $Param{Attribute} eq 'Age' ) ? 1 : undef
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
