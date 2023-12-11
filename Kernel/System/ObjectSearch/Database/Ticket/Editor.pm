# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Editor;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Editor - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Property => {
            IsSortable   => 0|1,
            IsSearchable => 0|1,
            Operators    => []
        },
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    $Self->{Supported} = {
        CreateBy => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'Integer'
        },
        ChangeBy => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => ['EQ','NE','IN','!IN'],
            ValueType    => 'Integer'
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

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my %AttributeMapping = (
        'CreateBy' => 'st.create_by',
        'ChangeBy' => 'st.change_by',
    );

    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{$Param{Search}->{Field}},
        Value     => $Param{Search}->{Value},
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

    my %AttributeMapping = (
        CreateBy => ['ccr.lastname', 'ccr.firstname'],
        ChangeBy => ['cch.lastname', 'cch.firstname'],
    );

    my %Join;
    if ( $Param{Attribute} eq 'CreateBy' ) {
        $Join{Join} = [
            'INNER JOIN contact ccr ON ccr.user_id = st.create_by'
        ];
    }
    elsif ( $Param{Attribute} eq 'ChangeBy' ) {
        $Join{Join} = [
            'INNER JOIN contact cch ON cch.user_id = st.change_by'
        ];
    }

    return {
        Select   => $AttributeMapping{$Param{Attribute}},
        OrderBy  => $AttributeMapping{$Param{Attribute}},
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
