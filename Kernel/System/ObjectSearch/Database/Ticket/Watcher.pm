# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Watcher;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Config
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Watcher - attribute module for database object search

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
        'WatcherUserID' => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','IN','!IN','NE','GT','GTE','LT','LTE']
        },
    };

    return $Self->{Supported};
}

=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        BoolOperator => 'AND' | 'OR',
        Search       => {}
    );

    $Result = {
        Join    => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    # check if we have to add a join
    if (
        !$Param{Flags}->{WatcherJoined}
        || !$Param{Flags}->{WatcherJoined}->{$Param{BoolOperator}}
    ) {
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLJoin, 'LEFT OUTER JOIN watcher tw_left ON st.id = tw_left.object_id' );
            push( @SQLJoin, 'RIGHT OUTER JOIN watcher tw_right ON st.id = tw_right.object_id' );
        } else {
            push( @SQLJoin, 'INNER JOIN watcher tw ON st.id = tw.object_id' );
        }
        $Param{Flags}->{WatcherJoined}->{$Param{BoolOperator}} = 1;
    }

    my $Column;
    if ( $Param{BoolOperator} eq 'OR') {
        $Column = [
            'tw_left.user_id',
            'tw_right.user_id'
        ];
    } else {
        $Column = 'tw.user_id';
    }

    my @SQLWhere;
    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => $Column,
        Value     => $Param{Search}->{Value},
        Prepare   => 1,
        Type      => 'NUMERIC',
        Supported => $Self->{Supported}->{$Param{Search}->{Field}}->{Operators}
    );

    return if !@Where;

    push( @SQLWhere, @Where);

    return {
        Join  => \@SQLJoin,
        Where => \@SQLWhere,
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
