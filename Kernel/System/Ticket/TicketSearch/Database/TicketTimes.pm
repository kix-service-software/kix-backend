# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::TicketTimes;

use strict;
use warnings;

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Config',
    'Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::TicketTimes - attribute module for database ticket search

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
            'Age',
            'CreateTime',
            'PendingTime',
            'LastChangeTime',
        ],
        Sort => [
            'Age',
            'CreateTime',
            'PendingTime',
            'LastChangeTime',
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
    my $Value;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    # map search attributes to table attributes
    my %AttributeMapping = (
        Age             => 'st.create_time_unix',
        CreateTime      => 'st.create_time_unix',
        PendingTime     => 'st.until_time',
        LastChangeTime  => 'st.change_time',
    );

    # convert to unix time and check
    $Value = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => $Param{Search}->{Value},
    );

    if ( $Param{Search}->{Field} !~ /^(Create|Pending)/ ) {
        # convert back to timestamp (relative calculations have been done above)
        $Value = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
            SystemTime => $Value
        );

        $Value = "'$Value'";
    }

    my %OperatorMap = (
        'EQ'  => '=',
        'LT'  => '<',
        'GT'  => '>',
        'LTE' => '<=',
        'GTE' => '>='
    );

    if ( $Param{Search}->{Field} eq 'Age' ) {
        # calculate unixtime
        $Value = $Kernel::OM->Get('Time')->SystemTime() - $Param{Search}->{Value};

        # invert operators since we "go back in time"
        %OperatorMap = (
            'EQ'  => '=',
            'LT'  => '>',
            'GT'  => '<',
            'LTE' => '>=',
            'GTE' => '<='
        );
    }

    if ( !$OperatorMap{$Param{Search}->{Operator}} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Search}->{Operator}!",
        );
        return;
    }

    push( @SQLWhere, $AttributeMapping{$Param{Search}->{Field}}.' '.$OperatorMap{$Param{Search}->{Operator}}.' '.$Value );

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
        Age                    => 'st.create_time_unix',
        CreateTime             => 'st.create_time_unix',
        PendingTime            => 'st.until_time',
        LastChangeTime         => 'st.change_time',
    );

    return {
        SQLAttrs => [
            $AttributeMapping{$Param{Attribute}}
        ],
        SQLOrderBy => [
            $AttributeMapping{$Param{Attribute}}
        ],
        OrderBySwitch => ($Param{Attribute} eq 'Age') ? 1 : undef
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
