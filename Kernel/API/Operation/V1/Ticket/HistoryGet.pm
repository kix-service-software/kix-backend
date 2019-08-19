# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::HistoryGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::HistoryGet - API Ticket Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # Get mapping of history types to readable strings
    my %HistoryTypes;
    my %HistoryTypeConfig = %{ $Kernel::OM->Get('Kernel::Config')->Get('Ticket::Frontend::HistoryTypes') // {} };
    foreach my $Entry ( sort keys %HistoryTypeConfig ) {
        %HistoryTypes = (
            %HistoryTypes,
            %{ $HistoryTypeConfig{$Entry} },
        );
    }
    $Self->{HistoryTypes} = \%HistoryTypes;

    return $Self;
}

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'TicketID' => {
            Required => 1
        },
        'HistoryID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform HistoryGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID             => '1',                                           # required 
            HistoryID            => '32,33',                                       # required, could be coma separated IDs or an Array
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            History => [
                {
                    HistoryID
                    TicketID
                    ArticleID
                    Name
                    CreateBy
                    CreateTime
                    HistoryType
                    QueueID
                    OwnerID
                    PriorityID
                    StateID
                    HistoryTypeID
                    TypeID
                },
                {
                    #. . .
                },
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my @HistoryList = $TicketObject->HistoryGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
    );
    my %HistoryHash = map { $_->{HistoryID} => $_ } @HistoryList;

    my @HistoryItemList;

    # start loop
    for my $HistoryID ( sort @{$Param{Data}->{HistoryID}} ) {

        my $HistoryItem = $HistoryHash{$HistoryID};

        # replace text if needed
        if ( $HistoryItem->{Name} && $HistoryItem->{Name} =~ m/^%%/x ) {
            $HistoryItem->{Name} =~ s/^%%//xg;
            my @Values = split( /%%/x, $HistoryItem->{Name} );
            $HistoryItem->{Name} = $Kernel::OM->Get('Kernel::Language')->Translate(
                $Self->{HistoryTypes}->{ $HistoryItem->{HistoryType} },
                @Values,
            );

            # remove not needed place holder
            $HistoryItem->{Name} =~ s/\%s//xg;
        }

        # add
        push(@HistoryItemList, $HistoryItem);
    }

    if ( scalar(@HistoryItemList) == 1 ) {
        return $Self->_Success(
            History => $HistoryItemList[0],
        );    
    }

    return $Self->_Success(
        History => \@HistoryItemList,
    );
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
