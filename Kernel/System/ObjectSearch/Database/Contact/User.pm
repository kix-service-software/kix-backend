# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Contact::User;

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

Kernel::System::ObjectSearch::Database::Contact::User - attribute module for database object search

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
        UserID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        AssignedUserID => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','IN','!IN']
        },
        Login => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
        },
        UserLogin => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','NE','STARTSWITH','ENDSWITH','CONTAINS','LIKE','IN','!IN']
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
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLWhere;
    my @SQLJoin;

    # check params
    return if !$Self->_CheckSearchParams(%Param);

    my %GetParams = (
        Column => 'c.user_id',
        Type   => 'NUMERIC'
    );
    if ( $Param{Search}->{Field} =~ m/Login$/sm ){
        my $TableAlias = 'u';
        if ( !$Param{Flags}->{UserJoin}->{$Param{BoolOperator}} ) {
            my $Count = $Param{Flags}->{UserCounter}++;
            $TableAlias .= $Count;
            push(
                @SQLJoin,
                "LEFT JOIN users $TableAlias ON c.user_id = $TableAlias.id"
            );
            $Param{Flags}->{UserJoin}->{$Param{BoolOperator}} = $TableAlias;
        }
        %GetParams = (
            Column        => "$TableAlias.login",
            Type          => 'STRING',
            Prepare       => 1,
            CaseSensitive => 1,
        );
    }

    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Value     => $Param{Search}->{Value},
        Supported => $Self->{Supported}->{$Param{Search}->{Field}}->{Operators},
        %GetParams
    );

    return if !@Where;

    push( @SQLWhere, @Where);

    return {
        Where => \@SQLWhere,
        Join  => \@SQLJoin,
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
    return if !$Self->_CheckSortParams(%Param);

    my @SQLJoin;
    my $TableAlias = $Param{Flags}->{UserJoin}->{AND} // 'u';
    if ( $Param{Attribute} =~ m/Login$/sm ){
        if ( !$Param{Flags}->{UserJoin}->{AND} ) {
            my $Count = $Param{Flags}->{UserCounter}++;
            $TableAlias .= $Count;
            push(
                @SQLJoin,
                "LEFT JOIN users $TableAlias ON c.user_id = $TableAlias.id"
            );
            $Param{Flags}->{UserJoin}->{AND} = $TableAlias;
        }
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        UserID         => 'c.user_id',
        AssignedUserID => 'c.user_id',
        Login          => "$TableAlias.login",
        UserLogin      => "$TableAlias.login",
    );

    return {
        Select  => [$AttributeMapping{$Param{Attribute}}],
        OrderBy => [$AttributeMapping{$Param{Attribute}}],
        Join    => \@SQLJoin
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
