# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::PostMaster::Filter::ExtendedFollowUp;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'DynamicField',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    # get our config
    $Self->{Config} = $Kernel::OM->Get('Config')->Get('ExtendedFollowUp');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # no config --> no mapping
    return if (
        !$Self->{Config}
        || ref( $Self->{Config} ) ne 'HASH'
        || ref( $Self->{Config}->{Identifier} ) ne 'HASH'
        || ref( $Self->{Config}->{SenderEmail} ) ne 'HASH'
        || ref( $Self->{Config}->{ExternalReference} ) ne 'HASH'
        || ref( $Self->{Config}->{DynamicFieldMapping} ) ne 'HASH'
    );

    my %ExistingTicket;
    if ( $Param{TicketID} ) {
        %ExistingTicket = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1
        )
    }

    my %FilterKeys = %{ $Self->{Config}->{Identifier} };

    # process configured filters
    for my $FilterKey ( sort( keys( %FilterKeys ) ) ) {
        # next if not all config values for the key are set
        next if (
            !$Self->{Config}->{SenderEmail}->{ $FilterKeys{ $FilterKey } }
            || !$Self->{Config}->{ExternalReference}->{ $FilterKeys{ $FilterKey } }
            || !$Self->{Config}->{DynamicFieldMapping}->{ $FilterKeys{ $FilterKey } }
        );

        # get config values for filter
        my $DynamicField      = $Self->{Config}->{DynamicFieldMapping}->{ $FilterKeys{ $FilterKey } };
        my $SenderEmail       = $Self->{Config}->{SenderEmail}->{ $FilterKeys{ $FilterKey } };
        my $ExternalReference = $Self->{Config}->{ExternalReference}->{ $FilterKeys{ $FilterKey } };

        # next if configured dynamic field does not exist
        my $TicketDynamicFields = $Kernel::OM->Get('DynamicField')->DynamicFieldList(
            ObjectType => 'Ticket',
            ResultType => 'HASH',
        );
        my %DynamicFieldHash = reverse( %{ $TicketDynamicFields } );
        next if ( !defined( $DynamicFieldHash{ $DynamicField } ) );

        # next if in the existing ticket the dynamic field is not empty
        next if (
            %ExistingTicket
            && $ExistingTicket{ 'DynamicField_' . $DynamicField }
        );

        # sender email doesnt match
        next if ( $Param{GetParam}->{From} !~ /$SenderEmail/ );

        my $ReferenceNumber = '';
        if ( $Param{GetParam}->{Subject} =~ /$ExternalReference/ ) {
            $ReferenceNumber = $1;
        }

        if ( $ReferenceNumber ) {
            # remember found reference number at ticket
            $Param{GetParam}->{ 'X-KIX-DynamicField-' . $DynamicField }          = $ReferenceNumber;
            $Param{GetParam}->{ 'X-KIX-FollowUp-DynamicField-' . $DynamicField } = $ReferenceNumber;

            # if no ticket was found by followup search on by external reference_number
            if ( !$Param{TicketID} ) {
                # prepare sort param
                my %Sort = (
                    Field     => 'CreateTime',
                    Direction => 'ascending',
                );
                if (
                    $Self->{Config}->{SortByAgeOrder}
                    && $Self->{Config}->{SortByAgeOrder} eq 'Up'
                ) {
                    $Sort{Direction} = 'descending';
                }

                # search for possible follow up
                my @TicketIDs = $Kernel::OM->Get('Ticket')->TicketSearch(
                    Result => 'ARRAY',
                    Search => {
                        AND => [
                            {
                                Field    => 'DynamicField_' . $DynamicField,
                                Operator => 'EQ',
                                Value    => $ReferenceNumber
                            }
                        ]
                    },
                    Sort   => [
                        \%Sort
                    ],
                    UserID => 1,
                );

                if ( scalar( @TicketIDs ) > 0 ) {
                    # init variable for ticket number lookup
                    my $TicketNumber = '';

                    # if ticket statetype isn't relevant
                    if ( $Self->{Config}->{AllTicketStateTypesIncluded} ) {
                        $TicketNumber = $Kernel::OM->Get('Ticket')->TicketNumberLookup(
                            TicketID => $TicketIDs[0],
                            UserID   => 1,
                        );
                    }
                    # filter by viewable state types first, fall back to closed tickets
                    else {
                        # filter previous tickets by viewable state type
                        my @ViewableTicketIDs = $Kernel::OM->Get('Ticket')->TicketSearch(
                            Result => 'ARRAY',
                            Search => {
                                AND => [
                                    {
                                        Field    => 'TicketID',
                                        Operator => 'IN',
                                        Value    => \@TicketIDs
                                    },
                                    {
                                        Field    => 'StateType',
                                        Operator => 'IN',
                                        Value    => 'Open'
                                    },
                                ]
                            },
                            Sort   => [
                                \%Sort
                            ],
                            UserID => 1,
                            Limit  => 1,
                        );
                        if ( scalar( @ViewableTicketIDs ) > 0 ) {
                            $TicketNumber = $Kernel::OM->Get('Ticket')->TicketNumberLookup(
                                TicketID => $ViewableTicketIDs[0],
                                UserID   => 1,
                            );
                        }

                        # if none ticket found, use closed ticket
                        if ( !$TicketNumber ) {
                            $TicketNumber = $Kernel::OM->Get('Ticket')->TicketNumberLookup(
                                TicketID => $TicketIDs[0],
                                UserID   => 1,
                            );
                        }
                    }

                    if ($TicketNumber) {
                        $Param{GetParam}->{'Subject'} = $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
                            TicketNumber => $TicketNumber,
                            Subject      => $Param{GetParam}->{'Subject'},
                            Type         => 'New',
                            NoCleanup    => 1,
                        );
                    }
                }
            }
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
