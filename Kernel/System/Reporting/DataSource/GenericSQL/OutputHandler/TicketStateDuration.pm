# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::TicketStateDuration;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::Common);

our @ObjectDependencies = (
    'DB',
    'Log',
    'State',
    'Ticket',
);

=head1 NAME

Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::TicketStateDuration - an output handler for reporting lib data source GenericSQL

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Init()

Initialize this output handler module.

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    my %StateList = $Kernel::OM->Get('State')->StateList(
        Valid  => 0,
        UserID => 1,
    );
    $Self->{StateIDLookup} = \%StateList;

    return 1;
}

=item Describe()

Describe this output handler module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Resolves the duration of a ticket in a state.'));
    $Self->AddOption(
        Name        => 'Columns',
        Label       => Kernel::Language::Translatable('Columns'),
        Description => Kernel::Language::Translatable('The columns in the raw data containing the TicketID to resolve.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'States',
        Label       => Kernel::Language::Translatable('States'),
        Description => Kernel::Language::Translatable('The names of the States corresponding with the column config.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'OutputZeroAsEmptyString',
        Label       => Kernel::Language::Translatable('Output zero as empty string'),
        Description => Kernel::Language::Translatable('If count for a state is zero output as empty string.'),
        Required    => 0,
    );

    return;
}

=item ValidateConfig()

Validates the required config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # required
    );

=cut

sub ValidateConfig {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Config} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Got no Config!',
            );
        }
        return;
    }

    return if !$Self->SUPER::ValidateConfig( %Param );

    # validate the columns
    for my $Option ( qw(Columns States) ) {
        if ( !IsArrayRefWithData( $Param{Config}->{ $Option } ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "TicketStateDuration: $Option is not an ARRAY ref or doesn't contain any configuration!",
                );
            }
            return;
        }
    }

    if ( scalar @{ $Param{Config}->{Columns} } != scalar @{ $Param{Config}->{States} } ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "TicketStateDuration: number of list items in Columns and States is different!",
            );
        }
        return;
    }

    return 1;
};

=item Run()

Run this module. Returns an ArrayRef with the result if successful, otherwise undef.

Example:
    my $Result = $Object->Run(
        Config => { },         # optional
        Data   => {
            Columns => [],
            Data    => [
            {...},
            {...},
        ],        # the row array containing the data
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # map columns to teams
    my %ColumnToState;
    my $Index = 0;
    foreach my $Column ( @{ $Param{Config}->{Columns} } ) {
        my $Column = $Self->_ReplaceParametersInString(
            String => $Column,
        );
        $ColumnToState{ $Column } = $Param{Config}->{States}->[$Index++]
    }

    # init hash with resolved durations
    my %TicketStateDurations = ();

    ROW:
    for my $Row ( @{ $Param{Data}->{Data} || [] } ) {
        COLUMN:
        for my $Column ( @{ $Param{Config}->{Columns} }) {
            next COLUMN if (
                !exists( $Row->{ $Column } )
                || !defined( $Row->{ $Column } )
            );

            # check for prepared data for requested ticket
            if ( ref( $TicketStateDurations{ $Row->{ $Column } } ) ne 'HASH' ) {
                $TicketStateDurations{ $Row->{ $Column } } = $Self->_PrepareTicketStateDurations(
                    TicketID => $Row->{ $Column }
                );
            }

            # get prepared value
            my $Value = $TicketStateDurations{ $Row->{ $Column } }->{ $ColumnToState{ $Column } } || '0';

            # special handling for zero value
            if (
                $Value eq '0'
                && $Param{Config}->{OutputZeroAsEmptyString}
            ) {
                $Value = '';
            }

            # override value
            $Row->{ $Column } = $Value;
        }
    }

    return $Param{Data};
}

sub _PrepareTicketStateDurations {
    my ( $Self, %Param ) = @_;

    # init state counts
    my %StateDurations = ();

    my @History = $Kernel::OM->Get('Ticket')->HistoryGet(
        TicketID => $Param{TicketID},
        UserID   => 1,
    );
    return \%StateDurations if ( !@History );

    # init variables
    my $StartTimeStamp;
    my $StateID;
    ENTRY:
    for my $Entry ( @History ) {
        # initialize with first entry
        if (
            !$StartTimeStamp
            || !$StateID
        ) {
            $StartTimeStamp = $Entry->{CreateTime};
            $StateID        = $Entry->{StateID};
        }
        # handle changed state
        elsif ( $StateID ne $Entry->{StateID} ) {
            my $StartTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                String => $StartTimeStamp,
            );
            my $EndTime   = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                String => $Entry->{CreateTime},
            );

            # add duration for previous state
            if ( defined( $StateDurations{ $Self->{StateIDLookup}->{ $StateID } } ) ) {
                $StateDurations{ $Self->{StateIDLookup}->{ $StateID } } += ( $EndTime - $StartTime );
            }
            else {
                $StateDurations{ $Self->{StateIDLookup}->{ $StateID } } = ( $EndTime - $StartTime );
            }

            # update start time and state
            $StartTimeStamp = $Entry->{CreateTime};
            $StateID        = $Entry->{StateID};
        }
    }

    # add duration for current state
    my $StartTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => $StartTimeStamp,
    );
    my $EndTime   = $Kernel::OM->Get('Time')->SystemTime();
    if ( defined( $StateDurations{ $Self->{StateIDLookup}->{ $StateID } } ) ) {
        $StateDurations{ $Self->{StateIDLookup}->{ $StateID } } += ( $EndTime - $StartTime );
    }
    else {
        $StateDurations{ $Self->{StateIDLookup}->{ $StateID } } = ( $EndTime - $StartTime );
    }

    return \%StateDurations;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
