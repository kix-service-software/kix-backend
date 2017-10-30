# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::TicketFlag;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::TicketFlag - attribute module for database ticket search

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
            'TicketFlag',
        ],
        Sort => []
    };
}


=item Filter()

run this module and return the SQL extensions

    my $Result = $Object->Filter(
        Filter => {}
    );

    $Result = {
        SQLJoin    => [ ],
        SQLWhere   => [ ],
    };

=cut

sub Filter {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Filter} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Filter!",
        );
        return;
    }

    if ( !IsArrayRefWithData($Param{Filter}->{Value}) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Invalid filter value!",
        );
        return;
    }

    if ( $Param{Filter}->{Operator} eq 'EQ' ) {
        my $Index = 1;
        foreach my $FilterValue ( sort @{ $Param{Filter}->{Value} } ) {
            if ( !IsHashRefWithData($FilterValue) ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid filter value!",
                );
                return;
            }
            
            if ( !$Param{Filter}->{Not} ) {
                push( @SQLJoin, "INNER JOIN ticket_flag tf$Index ON st.id = tf$Index.ticket_id" );
                push( @SQLWhere, "tf$Index.ticket_key = '$FilterValue->{Flag}'" );
            }
            else {
                push( @SQLJoin, "LEFT JOIN ticket_flag ntf$Index ON st.id = ntf$Index.ticket_id" );
                push( @SQLWhere, "ntf$Index.ticket_key = '$FilterValue->{Flag}'" );
            }

            # add value restriction if given
            if ( $FilterValue->{Value} ) {
                if ( !$Param{Filter}->{Not} ) {
                    push( @SQLWhere, "tf$Index.ticket_value = '$FilterValue->{Value}'" );
                }
                else {
                    push( @SQLWhere, "(ntf$Index.ticket_value IS NULL OR ntf$Index.ticket_value <> '$FilterValue->{Value}')" );
                }
            }

            # add user restriction if given
            if ( $FilterValue->{UserID} ) {
                if ( !$Param{Filter}->{Not} ) {
                    push( @SQLWhere, "tf$Index.create_by = $FilterValue->{UserID}" );
                }
                else {
                    push( @SQLWhere, "ntf$Index.create_by = $FilterValue->{UserID}" );                    
                }
            }
            $Index++;
        }
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Filter}->{Operator}!",
        );
        return;
    }

    return {
        SQLJoin  => \@SQLJoin,
        SQLWhere => \@SQLWhere,
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
