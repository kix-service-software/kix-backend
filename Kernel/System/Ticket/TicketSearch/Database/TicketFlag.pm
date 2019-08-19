# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [
            'TicketFlag',
        ],
        Sort => []
    };
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        BoolOperator => 'AND' | 'OR',
        Search       => {}
    );

    $Result = {
        SQLJoin    => [ ],
        SQLWhere   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    if ( !IsArrayRefWithData($Param{Search}->{Value}) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Invalid Search value!",
        );
        return;
    }

    my %JoinType = (
        'AND' => 'INNER',
        'OR'  => 'FULL OUTER'
    );

    if ( $Param{Search}->{Operator} eq 'EQ' ) {
        my $Index = 1;
        foreach my $SearchValue ( sort @{ $Param{Search}->{Value} } ) {
            if ( !IsHashRefWithData($SearchValue) ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid Search value!",
                );
                return;
            }
            
            if ( !$Param{Search}->{Not} ) {
                push( @SQLJoin, $JoinType{$Param{BoolOperator}}." JOIN ticket_flag tf$Index ON st.id = tf$Index.ticket_id" );
                push( @SQLWhere, "tf$Index.ticket_key = '$SearchValue->{Flag}'" );
            }
            else {
                push( @SQLJoin, "LEFT JOIN ticket_flag ntf$Index ON st.id = ntf$Index.ticket_id" );
                push( @SQLWhere, "ntf$Index.ticket_key = '$SearchValue->{Flag}'" );
            }

            # add value restriction if given
            if ( $SearchValue->{Value} ) {
                if ( !$Param{Search}->{Not} ) {
                    push( @SQLWhere, "tf$Index.ticket_value = '$SearchValue->{Value}'" );
                }
                else {
                    push( @SQLWhere, "(ntf$Index.ticket_value IS NULL OR ntf$Index.ticket_value <> '$SearchValue->{Value}')" );
                }
            }

            # add user restriction if given
            if ( $SearchValue->{UserID} ) {
                if ( !$Param{Search}->{Not} ) {
                    push( @SQLWhere, "tf$Index.create_by = $SearchValue->{UserID}" );
                }
                else {
                    push( @SQLWhere, "ntf$Index.create_by = $SearchValue->{UserID}" );                    
                }
            }
            $Index++;
        }
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Search}->{Operator}!",
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
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
