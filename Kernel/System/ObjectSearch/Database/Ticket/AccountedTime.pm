# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::AccountedTime;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = (
    'Log'
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::AccountedTime - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        'Property' => {
            IsSearchable => 0|1,
            IsSortable   => 0|1,
            Operators    => []
        }
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    $Self->{Supported} = {
        AccountedTime => {
            IsSearchable => 1,
            IsSortable   => 1,
            Operators    => ['EQ','LT','GT','LTE','GTE'],
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

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    if ( $Param{Search}->{Value} !~ m/^-?\d+$/sm ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Invalid search value ($Param{Search}->{Value})!",
            );
        }
        return;
    }

    my @SQLWhere;
    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => 'st.accounted_time',
        Value     => $Param{Search}->{Value},
        Supported => $Self->{Supported}->{$Param{Search}->{Field}}->{Operators},
        Silent    => $Param{Silent}
    );
    return if !@Where;

    push( @SQLWhere, @Where );

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
        Select  => [ ],          # optional
        OrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    # check params
    return if ( !$Self->_CheckSortParams(%Param) );

    return {
        Select  => [ 'st.accounted_time' ],
        OrderBy => [ 'st.accounted_time' ]
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
