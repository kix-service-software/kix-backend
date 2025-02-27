# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::TicketTeamCount;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::Common);

our @ObjectDependencies = (
    'DB',
    'Log',
    'Queue',
    'Ticket',
);

=head1 NAME

Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::TicketTeamCount - an output handler for reporting lib data source GenericSQL

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

    return 1;
}

=item Describe()

Describe this output handler module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Resolves the count a ticket was in a team.'));
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
                    Message  => "TicketTeamCount: $Option is not an ARRAY ref or doesn't contain any configuration!",
                );
            }
            return;
        }
    }

    if ( scalar @{ $Param{Config}->{Columns} } != scalar @{ $Param{Config}->{Teams} } ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "TicketTeamCount: number of list items in Columns and Teams is different!",
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
    my %TicketTeamCounts = ();

    ROW:
    for my $Row ( @{ $Param{Data}->{Data} || [] } ) {
        COLUMN:
        for my $Column ( @{ $Param{Config}->{Columns} }) {
            next COLUMN if (
                !exists( $Row->{ $Column } )
                || !defined( $Row->{ $Column } )
            );

            # check for prepared data for requested ticket
            if ( ref( $TicketTeamCounts{ $Row->{ $Column } } ) ne 'HASH' ) {
                $TicketTeamCounts{ $Row->{ $Column } } = $Self->_PrepareTicketTeamCounts(
                    TicketID => $Row->{ $Column }
                );
            }

            # get prepared value
            my $Value = $TicketTeamCounts{ $Row->{ $Column } }->{ $ColumnToTeam{ $Column } } || '0';

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

sub _PrepareTicketTeamCounts {
    my ( $Self, %Param ) = @_;

    # init team counts
    my %TeamCounts = ();

    my @History = $Kernel::OM->Get('Ticket')->HistoryGet(
        TicketID => $Param{TicketID},
        UserID   => 1,
    );
    return \%TeamCounts if ( !@History );

    # init variables
    my $QueueID;
    ENTRY:
    for my $Entry ( @History ) {
        # initialize with first entry
        if ( !$QueueID ) {
            $QueueID = $Entry->{QueueID};

            $TeamCounts{ $Self->{TeamIDLookup}->{ $QueueID } } = 1;
        }
        # handle changed queue
        elsif ( $QueueID ne $Entry->{QueueID} ) {
            $QueueID = $Entry->{QueueID};

            # increment count for new team
            if ( defined( $TeamCounts{ $Self->{TeamIDLookup}->{ $QueueID } } ) ) {
                $TeamCounts{ $Self->{TeamIDLookup}->{ $QueueID } } += 1;
            }
            else {
                $TeamCounts{ $Self->{TeamIDLookup}->{ $QueueID } } = 1;
            }
        }
    }

    return \%TeamCounts;
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
