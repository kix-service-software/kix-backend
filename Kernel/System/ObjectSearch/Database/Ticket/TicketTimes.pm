# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::TicketTimes;

use strict;
use warnings;

use base qw(
    Kernel::System::ObjectSearch::Database::Common
);

our @ObjectDependencies = qw(
    Config
    Log
);

=head1 NAME

Kernel::System::ObjectSearch::Database::Ticket::TicketTimes - attribute module for database object search

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
        'Age'            => ['EQ','LT','GT','LTE','GTE'],
        'CreateTime'     => ['EQ','LT','GT','LTE','GTE'],
        'PendingTime'    => ['EQ','LT','GT','LTE','GTE'],
        'LastChangeTime' => ['EQ','LT','GT','LTE','GTE'],
    };

    $Self->{SupportedSort} = [
        'Age',
        'CreateTime',
        'PendingTime',
        'LastChangeTime',
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

    # map search attributes to table attributes
    my %AttributeMapping = (
        Age             => 'st.create_time_unix',
        CreateTime      => 'st.create_time_unix',
        PendingTime     => 'st.until_time',
        LastChangeTime  => 'st.change_time',
    );

    my $Value;
    if ( $Param{Search}->{Field} eq 'Age' ) {
        # calculate unixtime
        $Value = $Kernel::OM->Get('Time')->SystemTime() - $Param{Search}->{Value};
    }
    else {
        # convert to unix time and check
        $Value = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => $Param{Search}->{Value},
            Silent => 1,
        );
        if ( !$Value ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Invalid Date '$Param{Search}->{Value}'!",
            );

            return;
        }

        if ( $Param{Search}->{Field} !~ /^(Create|Pending)/ ) {
            # convert back to timestamp (relative calculations have been done above)
            $Value = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
                SystemTime => $Value
            );

            $Value = "'$Value'";
        }
    }

    my @SQLWhere;
    my $Where = $Self->GetOperation(
        Operator  => $Param{Search}->{Operator},
        Column    => $AttributeMapping{$Param{Search}->{Field}},
        Value     => $Value,
        Supported => $Self->{SupportedSearch}->{$Param{Search}->{Field}}
    );

    return if !$Where;

    push( @SQLWhere, $Where);

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
