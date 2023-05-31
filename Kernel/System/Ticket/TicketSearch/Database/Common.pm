# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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

    $Self->{DBObject} = $Kernel::OM->Get('DB');

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
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [],
        Sort   => []
    };
}

=item Search()

empty method to be overridden by specific attribute module

    my $Result = $Object->Search(
        Search => {}
    );

    $Result = {
        SQLAttrs   => [ ],          # optional
        SQLFrom    => [ ],          # optional
        SQLJoin    => [ ],          # optional
        SQLWhere   => [ ],          # optional
        SQLOrderBy => [ ]           # optional
    };

=cut

sub Search {
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

=begin Internal:

=cut

sub _PrepareFieldAndValue {
    my ( $Self, %Param ) = @_;

    my $Field = $Param{Field};
    my $Value = $Param{Value};

    # check if database supports LIKE in large text types
    if ( $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
        if ( $Self->{DBObject}->GetDatabaseFunction('LcaseLikeInLargeText') ) {
            $Field = "LCASE(st.title)";
            $Value = "LCASE('$Value')";
        }
        else {
            $Field = "LOWER(st.title)";
            $Value = "LOWER('$Value')";
        }
    }
    else {
        $Value = "'$Value'";
    }

    return ($Field, $Value);
}

=end Internal:

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
