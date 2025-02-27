# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectSearch::Database::Article::Times;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::CommonAttribute
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::ObjectSearch::Database::Article::Times - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        ArticleCreateTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        },
        IncomingTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','LT','GT','LTE','GTE'],
            ValueType    => 'NUMERIC'

        },
        CreateTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        },
        ChangeTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','LT','GT','LTE','GTE'],
            ValueType    => 'DATETIME'
        }
    };
}

sub Search {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    return q{} if !$Param{Search}->{Value};

    # init mapping
    my %AttributeMapping = (
        ArticleCreateTime => {
            Column    => 'a.incoming_time',
            ValueType => 'NUMERIC',
            Convert   => 'TimeStamp2SystemTime'
        },
        IncomingTime => {
            Column    => 'a.incoming_time',
            ValueType => 'NUMERIC'
        },
        CreateTime => {
            Column    => 'a.create_time',
            ValueType => 'DATETIME'
        },
        ChangeTime => {
            Column    => 'a.change_time',
            ValueType => 'DATETIME',
        },
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
            if ( $AttributeMapping{ $Param{Search}->{Field} }->{Convert} eq 'TimeStamp2SystemTime' ) {
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
        ArticleCreateTime => 'a.incoming_time',
        IncomingTime      => 'a.incoming_time',
        CreateTime        => 'a.create_time',
        ChangeTime        => 'a.change_time',
    );

    return {
        Select  => [ $AttributeMapping{ $Param{Attribute} } ],
        OrderBy => [ $AttributeMapping{ $Param{Attribute} } ]
    };
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
