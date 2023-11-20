# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Lock;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Config
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Lock - attribute module for database object search

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
        'LockID' => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','IN','NE','!IN','LT','LTE','GT','GTE']
        },
        'Lock' => {
            IsSearchable => 0,
            IsSortable   => 1,
            Operators    => []
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

    if (
        IsArrayRefWithData($Param{Search}->{Value})
        && $Param{Search}->{Operator} !~ /IN/sm
    ) {
        $Param{Search}->{Operator} = 'IN';
    }

    my @SQLWhere;
    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => 'st.ticket_lock_id',
        Value     => $Param{Search}->{Value},
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
        Lock    => 'tlt.name',
        LockID  => 'st.ticket_lock_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'Lock' ) {
        $Join{Join} = [
            'INNER JOIN ticket_lock_type tlt ON tlt.id = st.ticket_lock_id'
        ];
    }
    return {
        Select => [
            $AttributeMapping{$Param{Attribute}}
        ],
        OrderBy => [
            $AttributeMapping{$Param{Attribute}}
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
