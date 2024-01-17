# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::StateSet;

use strict;
use warnings;
use utf8;

use String::ShellQuote;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = ( 'Log', 'State', 'Ticket', 'Time' );

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::StateSet - A module to set the ticket state

=head1 SYNOPSIS

All StateSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description( Kernel::Language::Translatable( 'Sets the state of a ticket.') );
    $Self->AddOption(
        Name        => 'State',
        Label       => Kernel::Language::Translatable( 'State'),
        Description => Kernel::Language::Translatable( 'The name of the state to be set.'),
        Required => 1,
    );
    $Self->AddOption(
        Name        => 'PendingTimeDiff',
        Label       => Kernel::Language::Translatable( 'Pending Time Difference'),
        Description => Kernel::Language::Translatable( '(Optional) The pending time in seconds. Will be added to the actual time when the macro action is executed. Used for pending states only.'),
        Required => 0,
    );
    $Self->AddOption(
        Name        => 'PendingDateTime',
        Label       => Kernel::Language::Translatable( 'Pending Date Time'),
        Description => Kernel::Language::Translatable( '(Optional) The pending time in format YYYY-MM-DD hh:mm:ss. This timestamp will be set as pending time. Setting "Pending Time Difference" will overwrite this parameter. Used for pending states only.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'TargetTime',
        Label       => Kernel::Language::Translatable( 'Target Time'),
        Description => Kernel::Language::Translatable( '(Optional) If pending time should be modified to fit BOB (begin of business day) or EOB (end of business day) of the specified date, select one of these options otherwise the provided/calculated time stamp is used without modification.'),
        Required => 0,
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            State           => 'pending reminder|new|open|...',
            PendingTimeDiff => 36000,  # OR:
            PendingDateTime => '<KIX_TICKET_DynamicField_DateOrDateTime>',
            TargetTime      => 'BOB|EOB',

        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my $TicketObject = $Kernel::OM->Get('Ticket');

    my %Ticket = $TicketObject->TicketGet( TicketID => $Param{TicketID} );

    if ( !%Ticket ) {
        return;
    }

    my $State = $Self->_ReplaceValuePlaceholder(
        %Param,
        Value => $Param{Config}->{State}
    );

    # set the new state
    my %State = $Kernel::OM->Get('State')->StateGet( Name => $State );

    if ( !%State || !$State{ID} ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - "
              . "can't find ticket state \"$Param{Config}->{State}\"!",
            UserID => $Param{UserID},
        );
        return;
    }

    my $Success = 1;

    # do nothing if the desired state is already set
    if ( $State{ID} ne $Ticket{StateID} ) {
        $Success = $TicketObject->TicketStateSet(
            TicketID => $Param{TicketID},
            StateID  => $State{ID},
            UserID   => $Param{UserID}
        );
    }

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - "
              . "setting the state \"$Param{Config}->{State}\" failed!",
            UserID => $Param{UserID},
        );
        return;
    }

    # set pending time
    if ( $State{TypeName} =~ m{\A pending}msxi ) {
        $Param{Config}->{PendingTimeDiff} = $Self->_ReplaceValuePlaceholder(
            %Param,
            Value => $Param{Config}->{PendingTimeDiff}
        );
        $Param{Config}->{PendingDateTime} = $Self->_ReplaceValuePlaceholder(
            %Param,
            Value => $Param{Config}->{PendingDateTime}
        );

        # get time object
        my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

        my $PendingTime;
        if ( defined $Param{Config}->{PendingTimeDiff} ) {
            # prepare system call
            my $SystemCall = 'echo ' . shell_quote( $Param{Config}->{PendingTimeDiff} ) . ' | bc 2>&1';

            # calculate if necessary - execute system call with quoted arguments
            my $PendingTimeDiffResult = `$SystemCall`;
            chomp $PendingTimeDiffResult;

            if ( !IsNumber($PendingTimeDiffResult) ) {
                $Kernel::OM->Get('Automation')->LogError(
                    Referrer => $Self,
                    Message  => "Couldn't update ticket $Param{TicketID} - "
                    . "setting pending time \"$Param{Config}->{PendingTimeDiff}\" is not valid!",
                    UserID => $Param{UserID},
                );
                return;
            }

            # get current time
            my $PendingSystemTime = $TimeObject->SystemTime();

            # add PendingTimeDiff
            $PendingSystemTime += $PendingTimeDiffResult;

            # convert pending time to time stamp
            $PendingTime = $TimeObject->SystemTime2TimeStamp( SystemTime => $PendingSystemTime );

        } elsif ( $Param{Config}->{PendingDateTime} ) {
            $PendingTime = $Param{Config}->{PendingDateTime};

            # TO DO - may be replaced by default placeholder if "Date" evaluates
            # to "YYYY-MM-DD hh:mm:ss"
            if ( $Param{Config}->{PendingDateTime} =~ /^(\d{4}-\d{2}-\d{2})(\s\d{2}\:\d{2}\:\d{2})?/ ) {
                if( $1 && !$2 ) {
                  $PendingTime = $Param{Config}->{PendingDateTime} . ' 00:00:00';
                }
            } else {
                $Kernel::OM->Get('Automation')->LogError(
                    Referrer => $Self,
                    Message  => "Couldn't update ticket $Param{TicketID} "
                      . "setting pending time - <$Param{Config}->{PendingDateTime}> "
                      . "no valid date/time!",
                    UserID => $Param{UserID},
                );
                return;
            }
        }

        if ($PendingTime) {

            # handle BOB and EOB
            if ( $Param{Config}->{TargetTime} && $Param{Config}->{TargetTime} =~ /^(?:BOB|EOB)$/g ) {
                my $Calendar;

                # get calendar from SLA
                if (
                    $Ticket{SLAID}
                    && $Kernel::OM->Get('Main')->Require('SLA', Silent => 1)
                ) {

                    # NOTE if "SLA by AffectedAsset", single SLAs are not
                    # evaluated but calendars assigned to "SLA by AffectedAsset"
                    my %SLA = $Kernel::OM->Get('SLA')->SLAGet(
                        SLAID  => $Ticket{SLAID},
                        UserID => 1,
                    );
                    $Calendar = $SLA{Calendar};
                }

                # get date parts
                my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
                    SystemTime => $TimeObject->TimeStamp2SystemTime(
                        String => $PendingTime,
                    )
                );

                # get BOB
                my $PendingTimeUnix = $TimeObject->DestinationTime(
                    StartTime => $TimeObject->TimeStamp2SystemTime(
                        String => "$Year-$Month-$Day 00:00:00",
                    ),
                    Time     => 2,   # at least 2 seconds needed, is substracted after next line
                    Calendar => $Calendar
                ) - 2;

                # get BOB date time string
                $PendingTime = $TimeObject->SystemTime2TimeStamp(
                    SystemTime => $PendingTimeUnix
                );

                # special handling for EOB
                if ( $Param{Config}->{TargetTime} eq 'EOB' ) {

                    # get date parts of BOB
                    my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
                        SystemTime => $TimeObject->TimeStamp2SystemTime(
                            String => $PendingTime,
                        )
                    );

                    # get working time of relevant day (seconds)
                    my $WorkingTime = $TimeObject->WorkingTime(
                        StartTime => $TimeObject->TimeStamp2SystemTime(
                            String => "$Year-$Month-$Day 00:00:01",
                        ),
                        StopTime  => $TimeObject->TimeStamp2SystemTime(
                            String => "$Year-$Month-$Day 23:59:59",
                        ),
                        Calendar  => $Calendar
                    );

                    # get EOB date time string (= BOB + working time for this day)
                    $PendingTime = $TimeObject->SystemTime2TimeStamp(
                        SystemTime => $PendingTimeUnix + $WorkingTime
                    );
                }
            }

            # set pending time
            $Success = $Kernel::OM->Get('Ticket')->TicketPendingTimeSet(
                UserID   => $Param{UserID},
                TicketID => $Param{TicketID},
                String   => $PendingTime,
            );
            if ( !$Success ) {
                $Kernel::OM->Get('Automation')->LogError(
                    Referrer => $Self,
                    Message  => "Couldn't update ticket $Param{TicketID} - "
                    . "setting pending time \"$PendingTime\" failed!",
                    UserID => $Param{UserID},
                );
                return;
            }
        }
    }

    return 1;
}

=item ValidateConfig()

Validates the parameters of the config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # required
    );

=cut

sub ValidateConfig {
    my ( $Self, %Param ) = @_;

    return if !$Self->SUPER::ValidateConfig(%Param);

    if ($Param{Config}->{State} !~ m/^(<|&lt;)KIX_.+>$/) {
        my %State = $Kernel::OM->Get('State')->StateGet( Name => $Param{Config}->{State} );

        # check for pending values
        if (
            %State &&
            $State{TypeName} =~ m{\A pending}msxi &&
            !$Param{Config}->{PendingTimeDiff} &&
            !$Param{Config}->{PendingDateTime}
        ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Either "PendingTimeDiff" or "PendingDateTime" has to be given!'
                );
            }
            return;
        }
    }

    return 1;
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
