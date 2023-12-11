# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectSearch::Database::Ticket::PendingReminder;

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

Kernel::System::ObjectSearch::Database::Ticket::PendingReminder - attribute module for database object search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Property => {
            IsSortable     => 0|1,
            IsSearchable => 0|1,
            Operators     => []
        },
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    $Self->{Supported} = {
        'PendingReminderRequired' => {
            IsSearchable => 1,
            IsSortable   => 0,
            Operators    => []
        },
    };

    return $Self->{Supported};
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        BoolOperator => 'AND' | 'OR',
        Search       => {}
    );

    $Result = {
        Where   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;
    my @SQLWhere;

    # check params
    return if ( !$Self->_CheckSearchParams( %Param ) );

    my $HistoryTypeID = $Kernel::OM->Get('Ticket')->HistoryTypeLookup(
        Type => 'SendAgentNotification',
    );

    my $BeginOfDay = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
        SystemTime => $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => '00:00:00'
        )
    );

    my $Now = $Kernel::OM->Get('Time')->SystemTime();

    push(
        @SQLWhere,
        <<"END"
st.until_time < $Now
    AND NOT EXISTS (
        SELECT id
        FROM ticket_history
        WHERE history_type_id = $HistoryTypeID
            AND ticket_id = st.id
            AND create_time >= '$BeginOfDay'
    )
END
    );

    return {
        Join  => \@SQLJoin,
        Where => \@SQLWhere,
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
