# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::Queue;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Config
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::Queue - attribute module for database object search

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

    $Self->{SupportedSearch} = {
        'Queue'   => ['EQ','IN','!IN','NE','LT','LTE','GT','GTE'],
        'QueueID' => ['EQ','IN','!IN','NE','LT','LTE','GT','GTE']
    };

    $Self->{SupportedSort} = [
        'Queue',
        'QueueID',
    ];

    return {
        Search => $Self->{SupportedSearch},
        Sort   => $Self->{SupportedSort}
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

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    my @QueueIDs;
    if ( $Param{Search}->{Field} eq 'Queue' ) {
        my @QueueList = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @QueueList = @{$Param{Search}->{Value}}
        }
        foreach my $Queue ( @QueueList ) {
            my $QueueID = $Kernel::OM->Get('Queue')->QueueLookup(
                Queue => $Queue,
            );
            if ( !$QueueID ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown queue $Queue!",
                );
                return;
            }

            push( @QueueIDs, $QueueID );
        }
    }
    else {
        @QueueIDs = ( $Param{Search}->{Value} );
        if ( IsArrayRefWithData($Param{Search}->{Value}) ) {
            @QueueIDs = @{$Param{Search}->{Value}}
        }
    }

    my @SQLWhere;
    my @Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => 'st.ticket_queue_id',
        Value     => \@QueueIDs,
        Type      => 'NUMERIC',
        Supported => $Self->{SupportedSearch}->{$Param{Search}->{Field}}
    );

    return if !@Where;

    push( @SQLWhere, @Where);

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
        Queue    => 'sq.name',
        QueueID  => 'st.queue_id',
    );

    my %Join;
    if ( $Param{Attribute} eq 'Queue' ) {
        $Join{SQLJoin} = [
            'INNER JOIN queue sq ON sq.id = st.queue_id'
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
