# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::TicketNumber;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::Ticket::Common
);

our @ObjectDependencies = (
    'Config',
    'Log',
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::TicketNumber - attribute module for database object search

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
            'TicketNumber',
        ],
        Sort => [
            'TicketNumber',
        ]
    }
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

    if ( $Param{Search}->{Operator} eq 'EQ' ) {
        push( @SQLWhere, "st.tn = '$Param{Search}->{Value}'" );
    }
    elsif ( $Param{Search}->{Operator} eq 'STARTSWITH' ) {
        push( @SQLWhere, "st.tn LIKE '$Param{Search}->{Value}%'" );
    }
    elsif ( $Param{Search}->{Operator} eq 'ENDSWITH' ) {
        push( @SQLWhere, "st.tn LIKE '%$Param{Search}->{Value}'" );
    }
    elsif ( $Param{Search}->{Operator} eq 'CONTAINS' ) {
        push( @SQLWhere, "st.tn LIKE '%$Param{Search}->{Value}%'" );
    }
    elsif ( $Param{Search}->{Operator} eq 'LIKE' ) {
        my $Value = $Param{Search}->{Value};
        $Value =~ s/\*/%/g;
        push( @SQLWhere, "st.tn LIKE '$Value'" );
    }
    elsif ( $Param{Search}->{Operator} eq 'IN' ) {
        push( @SQLWhere, "st.tn IN ('".(join("','", @{$Param{Search}->{Value}}))."')" );
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

    return {
        SQLAttrs => [
            'st.tn'
        ],
        SQLOrderBy => [
            'st.tn'
        ],
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
