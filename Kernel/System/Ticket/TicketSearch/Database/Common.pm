# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::Common;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::Common - base attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{DBObject} = $Kernel::OM->Get('Kernel::System::DB');
    
    return $Self;
}

=item Init()

empty method to be overridden by specific attribute module if necessary

    $Object->Init();

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # reset module data
    $Self->{ModuleData} = {};

    return;
}

=item GetSupportedAttributes()

empty method to be overridden by specific attribute module

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Filter => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Filter => [],
        Sort   => []
    };
}

=item Filter()

empty method to be overridden by specific attribute module

    my $Result = $Object->Filter(
        Filter => {}
    );

    $Result = {
        SQLAttrs   => [ ],          # optional
        SQLFrom    => [ ],          # optional
        SQLJoin    => [ ],          # optional
        SQLWhere   => [ ],          # optional
        SQLOrderBy => [ ]           # optional
    };

=cut

sub Filter {
    my ( $Self, %Param ) = @_;

    return;        
}

=item Sort()

empty method to be overridden by specific attribute module

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

    return;        
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
