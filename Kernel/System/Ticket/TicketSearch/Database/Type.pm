# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::Type;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = qw(
    Config
    Log
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
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [
            'TypeID',
        ],
        Sort => [
            'TypeID',
            'Type'
        ]
    };
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

    my @TypeIDs;
    if ( $Param{Search}->{Field} eq 'Type' ) {
        my @TypeList = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @TypeList = @{$Param{Search}->{Value}}
        }
        foreach my $Type ( @TypeList ) {
            my $TypeID = $Kernel::OM->Get('Type')->TypeLookup(
                Type => $Type,
            );
            if ( !$TypeID ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown Type $Type!",
                );
                return;
            }

            push( @TypeIDs, $TypeID );
        }
    }
    else {
        @TypeIDs = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @TypeIDs = @{$Param{Search}->{Value}}
        }
    }

    if ( $Param{Search}->{Operator} eq 'EQ' ) {
        push( @SQLWhere, 'st.type_id = '.$TypeIDs[0] );
    }
    elsif ( $Param{Search}->{Operator} eq 'NE' ) {
        push( @SQLWhere, 'st.type_id != '.$TypeIDs[0] );
    }
    elsif ( $Param{Search}->{Operator} eq 'IN' ) {
        push( @SQLWhere, 'st.type_id IN ('.(join(q{,}, @TypeIDs)).q{)} );
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

    # map search attributes to table attributes
    my %AttributeMapping = (
        Type    => 'tt.name',
        TypeID  => 'st.type_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'Type' ) {
        $Join{SQLJoin} = [
            'INNER JOIN ticket_type tt ON tt.id = st.type_id'
        ];
    }
    return {
        SQLAttrs => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLOrderBy => [
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
