# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

$Kernel::OM->Get('Cache')->CleanUp();

my @Tests = (
    {
        CreateData => [
            {
                TicketCreate => {
                    Title        => 'HistoryCreateTitle',
                    Queue        => 'Junk',
                    Lock         => 'unlock',
                    PriorityID   => '3',
                    State        => 'new',
                    CustomerID   => '1',
                    Contact      => 'customer@example.com',
                    OwnerID      => 1,
                    UserID       => 1,
                },
            },
            {
                ArticleCreate => {
                    Channel        => 'note',
                    SenderType     => 'agent',
                    From           => 'Some Agent <email@example.com>',
                    To             => 'Some Customer A <customer-a@example.com>',
                    Subject        => 'some short description',
                    Body           => 'the message text',
                    Charset        => 'ISO-8859-15',
                    MimeType       => 'text/plain',
                    HistoryType    => 'OwnerUpdate',
                    HistoryComment => 'Some free text!',
                    UserID         => 1,
                },
            },
            {
                ArticleCreate => {
                    Channel        => 'note',
                    SenderType     => 'agent',
                    From           => 'Some other Agent <email2@example.com>',
                    To             => 'Some Customer A <customer-a@example.com>',
                    Subject        => 'some short description',
                    Body           => 'the message text',
                    Charset        => 'UTF-8',
                    MimeType       => 'text/plain',
                    HistoryType    => 'OwnerUpdate',
                    HistoryComment => 'Some free text!',
                    UserID         => 1,
                },
            },
        ],
    },
    {
        ReferenceData => [
            {
                TicketIndex => 0,
                HistoryGet  => [
                    {
                        CreateBy    => 1,
                        HistoryType => 'NewTicket',
                        Queue       => 'Junk',
                        OwnerID     => 1,
                        PriorityID  => 3,
                        State       => 'new',
                        HistoryType => 'NewTicket',
                        Type        => 'Unclassified',
                    },
                    {
                        CreateBy    => 1,
                        HistoryType => 'OwnerUpdate',
                        Queue       => 'Junk',
                        OwnerID     => 1,
                        PriorityID  => 3,
                        State       => 'new',
                        HistoryType => 'OwnerUpdate',
                        Type        => 'Unclassified',
                    },
                    {
                        CreateBy    => 1,
                        HistoryType => 'OwnerUpdate',
                        Queue       => 'Junk',
                        OwnerID     => 1,
                        PriorityID  => 3,
                        State       => 'new',
                        HistoryType => 'OwnerUpdate',
                        Type        => 'Unclassified',
                    },
                ],
            },
        ],
    },

    # Bug 10856 - TicketHistoryGet() dynamic field values
    {
        CreateData => [
            {
                TicketCreate => {
                    Title                => 'HistoryCreateTitle',
                    Queue                => 'Junk',
                    Lock                 => 'unlock',
                    PriorityID           => '3',
                    State                => 'new',
                    CustomerID           => '1',
                    Contact              => 'customer@example.com',
                    OwnerID              => 1,
                    UserID               => 1,
                    DynamicFieldBug10856 => 'TestValue',
                },

                # history entry for a dynamic field update of OTRS 3.3
                HistoryAdd => {
                    HistoryType => 'TicketDynamicFieldUpdate',
                    Name =>
                        "\%\%FieldName\%\%DynamicFieldBug10856"
                        . "\%\%Value\%\%TestValue",
                    CreateUserID => 1,
                },
            },
        ],
    },

    # Bug 10856 - TicketHistoryGet() dynamic field values
    {
        CreateData => [
            {
                TicketCreate => {
                    Title                => 'HistoryCreateTitle',
                    Queue                => 'Junk',
                    Lock                 => 'unlock',
                    PriorityID           => '3',
                    State                => 'new',
                    CustomerID           => '1',
                    Contact              => 'customer@example.com',
                    OwnerID              => 1,
                    UserID               => 1,
                    DynamicFieldBug10856 => 'TestValue',
                },

                # history entry for a dynamic field update of OTRS 4
                HistoryAdd => {
                    HistoryType => 'TicketDynamicFieldUpdate',
                    Name =>
                        "\%\%FieldName\%\%DynamicFieldBug10856"
                        . "\%\%Value\%\%TestValue"
                        . "\%\%OldValue",
                    CreateUserID => 1,
                },
            },
        ],
    },
);

my @HistoryCreateTicketIDs;
for my $Test (@Tests) {
    my $HistoryCreateTicketID;
    my @HistoryCreateArticleIDs;

    if ( $Test->{CreateData} ) {
        for my $CreateData ( @{ $Test->{CreateData} } ) {

            if ( $CreateData->{TicketCreate} ) {
                $HistoryCreateTicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
                    %{ $CreateData->{TicketCreate} },
                );
                $Self->True(
                    $HistoryCreateTicketID,
                    'HistoryGet - TicketCreate()',
                );

                if ($HistoryCreateTicketID) {
                    push @HistoryCreateTicketIDs, $HistoryCreateTicketID;
                }
            }

            if ( $CreateData->{ArticleCreate} ) {
                my $HistoryCreateArticleID = $Kernel::OM->Get('Ticket')->ArticleCreate(
                    TicketID => $HistoryCreateTicketID,
                    %{ $CreateData->{ArticleCreate} },
                );
                $Self->True(
                    $HistoryCreateArticleID,
                    'HistoryGet - ArticleCreate()',
                );
                if ($HistoryCreateArticleID) {
                    push @HistoryCreateArticleIDs, $HistoryCreateArticleID;
                }
            }

            if ( $CreateData->{HistoryAdd} ) {
                my $Success = $Kernel::OM->Get('Ticket')->HistoryAdd(
                    %{ $CreateData->{HistoryAdd} },
                    TicketID => $HistoryCreateTicketID,
                );

                $Self->True(
                    $Success,
                    'HistoryAdd() - Create raw history entry',
                );
            }

            if ( $CreateData->{TicketCreate} ) {
                my %ComputedTicketState = $Kernel::OM->Get('Ticket')->HistoryTicketGet(
                    StopDay   => 1,
                    StopMonth => 1,
                    StopYear  => 1990,
                    TicketID  => $HistoryCreateTicketID,
                );

                $Self->False(
                    %ComputedTicketState ? 1 : 0,
                    "HistoryTicketGet() - state before ticket was created",
                );

                my %ComputedTicketStateCached = $Kernel::OM->Get('Ticket')->HistoryTicketGet(
                    StopDay   => 1,
                    StopMonth => 1,
                    StopYear  => 1990,
                    TicketID  => $HistoryCreateTicketID,
                );

                $Self->IsDeeply(
                    \%ComputedTicketStateCached,
                    \%ComputedTicketState,
                    "HistoryTicketGet() - cached ticket data before ticket was created",
                );

                %ComputedTicketState = $Kernel::OM->Get('Ticket')->HistoryTicketGet(
                    StopDay   => 1,
                    StopMonth => 1,
                    StopYear  => 2990,
                    TicketID  => $HistoryCreateTicketID,
                );

                for my $Key (qw(OwnerID PriorityID Queue State DynamicFieldBug10856)) {

                    $Self->Is(
                        $ComputedTicketState{$Key},
                        $CreateData->{TicketCreate}->{$Key},
                        "HistoryTicketGet() - uncached value $Key",
                    );
                }

                %ComputedTicketStateCached = $Kernel::OM->Get('Ticket')->HistoryTicketGet(
                    StopDay   => 1,
                    StopMonth => 1,
                    StopYear  => 2990,
                    TicketID  => $HistoryCreateTicketID,
                );

                $Self->IsDeeply(
                    \%ComputedTicketStateCached,
                    \%ComputedTicketState,
                    "HistoryTicketGet() - cached ticket data",
                );
            }
        }
    }

    if ( $Test->{ReferenceData} ) {

        REFERENCEDATA:
        for my $ReferenceData ( @{ $Test->{ReferenceData} } ) {

            $HistoryCreateTicketID = $HistoryCreateTicketIDs[ $ReferenceData->{TicketIndex} ];

            next REFERENCEDATA if !$ReferenceData->{HistoryGet};
            my @ReferenceResults = @{ $ReferenceData->{HistoryGet} };

            my @HistoryGet = $Kernel::OM->Get('Ticket')->HistoryGet(
                UserID   => 1,
                TicketID => $HistoryCreateTicketID,
            );

            my %LookForHistoryTypes = (
                NewTicket      => 1,
                OwnerUpdate    => 1,
                CustomerUpdate => 1,
            );

            @HistoryGet = grep { $LookForHistoryTypes{ $_->{HistoryType} } } @HistoryGet;

            $Self->True(
                scalar @HistoryGet,
                'HistoryGet - HistoryGet()',
            );

            next REFERENCEDATA if !@HistoryGet;

            for my $ResultCount ( 0 .. ( ( scalar @ReferenceResults ) - 1 ) ) {
                my $Result = $ReferenceData->{HistoryGet}->[$ResultCount];

                RESULTENTRY:
                for my $ResultEntry ( sort keys %{$Result} ) {
                    next RESULTENTRY if !$Result->{$ResultEntry};

                    if ( $ResultEntry eq 'Queue' ) {
                        my $HistoryQueueID = $Kernel::OM->Get('Queue')->QueueLookup(
                            Queue => $Result->{$ResultEntry},
                        );

                        $ResultEntry = 'QueueID';
                        $Result->{$ResultEntry} = $HistoryQueueID;
                    }

                    if ( $ResultEntry eq 'State' ) {
                        my %HistoryState = $Kernel::OM->Get('State')->StateGet(
                            Name => $Result->{$ResultEntry},
                        );
                        $ResultEntry = 'StateID';
                        $Result->{$ResultEntry} = $HistoryState{ID};
                    }

                    if ( $ResultEntry eq 'HistoryType' ) {
                        my $HistoryTypeID = $Kernel::OM->Get('Ticket')->HistoryTypeLookup(
                            Type => $Result->{$ResultEntry},
                        );
                        $ResultEntry = 'HistoryTypeID';
                        $Result->{$ResultEntry} = $HistoryTypeID;
                    }

                    if ( $ResultEntry eq 'Type' ) {
                        my $TypeID = $Kernel::OM->Get('Type')->TypeLookup(
                            Type => $Result->{$ResultEntry},
                        );
                        $ResultEntry = 'TypeID';
                        $Result->{$ResultEntry} = $TypeID;
                    }

                    $Self->Is(
                        $Result->{$ResultEntry},
                        $HistoryGet[$ResultCount]->{$ResultEntry},
                        "HistoryGet - Check returned content $ResultEntry",
                    );
                }
            }
        }
    }
}

# rollback transaction on database
$Helper->Rollback();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
