# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::Type;

use strict;
use warnings;

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::Type - attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Filter => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Filter => [
            'TypeID',
        ],
        Sort => [
            'TypeID',
        ]
    };
}

=item Filter()

run this module and return the SQL extensions

    my $Result = $Object->Filter(
        Filter => {}
    );

    $Result = {
        SQLWhere   => [ ],
    };

=cut

sub Filter {
    my ( $Self, %Param ) = @_;
    my @SQLWhere;

    # check params
    if ( !$Param{Filter} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Filter!",
        );
        return;
    }

    my @TypeIDs;
    if ( $Param{Filter}->{Field} eq 'Type' ) {
        my @TypeList = ( $Param{Filter}->{Value} );
        if ( IsArrayRefWithData($Param{Filter}->{Value}) ) {
            @TypeList = @{$Param{Filter}->{Value}}
        }
        foreach my $Type ( @TypeList ) {
            my $TypeID = $Kernel::OM->Get('Kernel::System::Type')->TypeLookup(
                Type => $Type,
            );
            if ( !$TypeID ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown Type $Type!",
                );
                return;
            }                

            push( @TypeIDs, $TypeID );
        }
    }
    else {
        @TypeIDs = ( $Param{Filter}->{Value} );
        if ( IsArrayRefWithData($Param{Filter}->{Value}) ) {
            @TypeIDs = @{$Param{Filter}->{Value}}
        }
    }

    if ( $Param{Filter}->{Operator} eq 'EQ' ) {
        push( @SQLWhere, 'st.type_id = '.$TypeIDs[0] );
    }
    elsif ( $Param{Filter}->{Operator} eq 'IN' ) {
        push( @SQLWhere, 'st.type_id IN ('.(join(',', @TypeIDs)).')' );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Filter}->{Operator}!",
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
            'st.type_id'
        ],
        SQLOrderBy => [
            'st.type_id'
        ],
    };       
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
