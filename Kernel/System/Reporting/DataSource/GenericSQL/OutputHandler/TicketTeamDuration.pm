# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::TicketTeamDuration;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::Common);

our @ObjectDependencies = (
    'DB',
    'Log',
    'Queue',
    'State',
    'Ticket',
    'Time',
);

=head1 NAME

Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::TicketTeamDuration - an output handler for reporting lib data source GenericSQL

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Init()

Initialize this output handler module.

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    my %QueueList = $Kernel::OM->Get('Queue')->QueueList(
        Valid => 0,
    );
    $Self->{TeamIDLookup} = \%QueueList;

    my %StateList = $Kernel::OM->Get('State')->StateList(
        Valid  => 0,
        UserID => 1,
    );
    $Self->{StateLookup} = { reverse( %StateList ) };

    return 1;
}

=item Describe()

Describe this output handler module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Resolves the duration of a ticket in a team.'));
    $Self->AddOption(
        Name        => 'Columns',
        Label       => Kernel::Language::Translatable('Columns'),
        Description => Kernel::Language::Translatable('The columns in the raw data containing the TicketID to resolve.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Teams',
        Label       => Kernel::Language::Translatable('Teams'),
        Description => Kernel::Language::Translatable('The names of the Teams corresponding with the column config. Special handling with "<Current>" and "<Create>"'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'RelevantStates',
        Label       => Kernel::Language::Translatable('Relevant states'),
        Description => Kernel::Language::Translatable('The names of ticket states that are relevant for the duration calulation.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'StopStates',
        Label       => Kernel::Language::Translatable('Stop states'),
        Description => Kernel::Language::Translatable('The names of ticket states that stop the duration calulation.'),
        Required    => 0,
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
    for my $Option ( qw(Columns Teams) ) {
        if ( !IsArrayRefWithData( $Param{Config}->{ $Option } ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "TicketTeamDuration: $Option is not an ARRAY ref or doesn't contain any configuration!",
                );
            }
            return;
        }
    }
    for my $Option ( qw(RelevantStates StopStates) ) {
        if ( 
            defined( $Param{Config}->{ $Option } )
            && !IsArrayRefWithData( $Param{Config}->{ $Option } )
        ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "TicketTeamDuration: $Option is defined but not an ARRAY ref or doesn't contain any configuration!",
                );
            }
            return;
        }
    }

    if ( scalar @{ $Param{Config}->{Columns} } != scalar @{ $Param{Config}->{Teams} } ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "TicketTeamDuration: number of list items in Columns and Teams is different!",
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
    my %ColumnToTeam;
    my $Index = 0;
    foreach my $Column ( @{ $Param{Config}->{Columns} } ) {
        my $Column = $Self->_ReplaceParametersInString(
            String => $Column,
        );
        $ColumnToTeam{ $Column } = $Param{Config}->{Teams}->[$Index++]
    }

    # init hash with resolved durations
    my %TicketTeamDurations = ();

    ROW:
    for my $Row ( @{ $Param{Data}->{Data} || [] } ) {
        COLUMN:
        for my $Column ( @{ $Param{Config}->{Columns} }) {
            next COLUMN if (
                !exists( $Row->{ $Column } )
                || !defined( $Row->{ $Column } )
            );

            # check for prepared data for requested ticket
            if ( ref( $TicketTeamDurations{ $Row->{ $Column } } ) ne 'HASH' ) {
                $TicketTeamDurations{ $Row->{ $Column } } = $Self->_PrepareTicketTeamDurations(
                    TicketID       => $Row->{ $Column },
                    RelevantStates => $Param{Config}->{RelevantStates},
                    StopStates     => $Param{Config}->{StopStates},
                );
            }

            # get prepared value
            my $Value = $TicketTeamDurations{ $Row->{ $Column } }->{ $ColumnToTeam{ $Column } } || '0';

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

sub _PrepareTicketTeamDurations {
    my ( $Self, %Param ) = @_;

    # init team durations
    my %TeamDurations = ();

    my @History = $Kernel::OM->Get('Ticket')->HistoryGet(
        TicketID => $Param{TicketID},
        UserID   => 1,
    );
    return \%TeamDurations if ( !@History );

    # init variables
    my $StartTimeStamp;
    my $QueueID;
    my $StateID;
    my $CreateTeam;
    my $TeamDuration;
    my $Stopped;
    ENTRY:
    for my $Entry ( @History ) {
        if (
            !$StartTimeStamp
            || !$QueueID
            || !$StateID
        ) {
            # init values
            $QueueID      = $Entry->{QueueID};
            $StateID      = $Entry->{StateID};
            $CreateTeam   = 1;
            $TeamDuration = 0;

            # special handling when ticket is created in a stop state
            if (
                ref( $Param{StopStates} ) eq 'ARRAY'
                && grep( { $Self->{StateLookup}->{$_} && $Self->{StateLookup}->{$_} eq $StateID } @{ $Param{StopStates} } )
            ) {
                $Stopped = 1;

                last ENTRY;
            }

            # init values for calculations
            $StartTimeStamp = $Entry->{CreateTime};
            $Stopped        = 0;
        }
        # handle state changes
        elsif (
            !$Stopped
            && $StateID ne $Entry->{StateID}
        ) {
            # check if previous state was relevant
            if (
                ref( $Param{RelevantStates} ) ne 'ARRAY'
                || grep( { $Self->{StateLookup}->{$_} && $Self->{StateLookup}->{$_} eq $StateID } @{ $Param{RelevantStates} } )
            ) {
                my $StartTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                    String => $StartTimeStamp,
                );
                my $EndTime   = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                    String => $Entry->{CreateTime},
                );
                $TeamDuration += ( $EndTime - $StartTime );
            }

            # update start time and state
            $StartTimeStamp = $Entry->{CreateTime};
            $StateID        = $Entry->{StateID};

            # check if new state is a stop state
            if (
                ref( $Param{StopStates} ) eq 'ARRAY'
                && grep( { $Self->{StateLookup}->{$_} && $Self->{StateLookup}->{$_} eq $StateID } @{ $Param{StopStates} } )
            ) {
                $Stopped = 1;
            }
        }
        # handle team changes
        elsif ( $QueueID ne $Entry->{QueueID} ) {
            # update team duration if relevant
            if (
                !$Stopped
                && (
                    ref( $Param{RelevantStates} ) ne 'ARRAY'
                    || grep( { $Self->{StateLookup}->{$_} && $Self->{StateLookup}->{$_} eq $StateID } @{ $Param{RelevantStates} } )
                )
            ) {
                my $StartTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                    String => $StartTimeStamp,
                );
                my $EndTime   = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                    String => $Entry->{CreateTime},
                );
                $TeamDuration += ( $EndTime - $StartTime );
            }

            # set duration to '<Create>' for first team
            if ( $CreateTeam ) {
                $TeamDurations{'<Create>'} = $TeamDuration;

                $CreateTeam = 0;
            }

            # add duration to current team
            if ( defined( $TeamDurations{ $Self->{TeamIDLookup}->{ $QueueID } } ) ) {
                $TeamDurations{ $Self->{TeamIDLookup}->{ $QueueID } } += $TeamDuration;
            }
            else {
                $TeamDurations{ $Self->{TeamIDLookup}->{ $QueueID } } = $TeamDuration;
            }

            # reset team duration
            $TeamDuration = 0;

            # update start time and queue
            $StartTimeStamp = $Entry->{CreateTime};
            $QueueID        = $Entry->{QueueID};
        }
    }

    # update team duration if relevant
    if (
        !$Stopped
        && (
            ref( $Param{RelevantStates} ) ne 'ARRAY'
            || grep( { $Self->{StateLookup}->{$_} && $Self->{StateLookup}->{$_} eq $StateID } @{ $Param{RelevantStates} } )
        )
    ) {
        my $StartTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
            String => $StartTimeStamp,
        );
        my $EndTime   = $Kernel::OM->Get('Time')->SystemTime();
        $TeamDuration += ( $EndTime - $StartTime );
    }

    # set duration to '<Create>' for first team
    if ( $CreateTeam ) {
        $TeamDurations{'<Create>'} = $TeamDuration;
    }

    # add duration to current team
    if ( defined( $TeamDurations{ $Self->{TeamIDLookup}->{ $QueueID } } ) ) {
        $TeamDurations{ $Self->{TeamIDLookup}->{ $QueueID } } += $TeamDuration;
    }
    else {
        $TeamDurations{ $Self->{TeamIDLookup}->{ $QueueID } } = $TeamDuration;
    }

    # set duration to '<Current>' for current team
    $TeamDurations{'<Current>'} = $TeamDuration;

    return \%TeamDurations;
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
