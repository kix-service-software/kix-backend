# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::Job::Ticket;

use strict;
use warnings;

use List::Util qw(any);

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::Job::Common);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Automation::Job::Ticket - job type for automation lib

=head1 SYNOPSIS

Handles ticket based jobs.

=head1 PUBLIC INTERFACE

=over 4

=cut


sub _Run {
    my ( $Self, %Param ) = @_;

    my $Filters = $Param{Filter};

    # nothing to check for event based call without filter
    if (
        $Param{IsEventBased}
        && !IsArrayRefWithData( $Filters )
        && IsHashRefWithData( $Param{Data} )
        && $Param{Data}->{TicketID}
    ) {
        return ( $Param{Data}->{TicketID} );
    }

    # check possible filters for event based calls
    my $PossibleFilters = [];
    if (
        $Param{IsEventBased}
        && IsArrayRefWithData( $Filters )
        && IsHashRefWithData( $Param{Data} )
        && $Param{Data}->{TicketID}
    ) {
        if ( ref( $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} } ) ne 'HASH' ) {
            $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} } = {};
        }

        # gather used filter and required dynamic fields
        my %FilterFields = ();
        FILTER:
        for my $Filter ( @{ $Filters } ) {
            # check ticket data directly for simple cases
            if (
                IsArrayRefWithData( $Filter->{AND} )
                && !IsArrayRefWithData( $Filter->{OR} )
            ) {
                CRITERION:
                for my $Criterion ( @{ $Filter->{AND} } ) {
                    my $Field    = $Criterion->{Field}    // q{};
                    my $Operator = $Criterion->{Operator} // q{};

                    # catch invalid filter
                    next FILTER if (
                        !$Field
                        || !$Operator
                    );

                    # handle not so simple operators
                    if (
                        $Operator ne 'EQ'
                        && $Operator ne 'IN'
                    ) {
                        next CRITERION;
                    }

                    # skip already fetched data
                    if ( defined( $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} }->{ $Field } ) ) {
                        next CRITERION;
                    }

                    $FilterFields{ $Criterion->{Field} } = 1;

                    # add state id in case a viewable state type is used
                    if ( $Criterion->{Field} eq 'StateType' ) {
                        $FilterFields{StateID} = 1;
                    }
                }
            }
        }

        if ( %FilterFields ) {
            # extract missing dynamic fields from filter fields
            my @FilterDynamicFields = ();
            for my $Field ( keys( %FilterFields ) ) {
                if (
                    $Field =~ m/^DynamicField_(.+)$/
                    && !defined( $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} }->{ $Field } ) 
                ) {
                    push( @FilterDynamicFields, $1 );
                }
            }

            if ( $Param{Data}->{ArticleID} ) {
                my %Article = $Kernel::OM->Get('Ticket')->ArticleGet(
                    ArticleID     => $Param{Data}->{ArticleID},
                    DynamicFields => scalar( @FilterDynamicFields ) ? \@FilterDynamicFields : 0,
                    UserID        => 1,
                );

                # clone relevant data before manipulations
                for my $Field ( keys( %FilterFields ) ) {
                    if (
                        defined( $Article{ $Field } )
                        && (
                            ref( $Article{ $Field } ) eq ''
                            || ref( $Article{ $Field } ) eq 'ARRAY'
                        )
                    ) {
                        $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} }->{ $Field } = $Article{ $Field };
                    }
                }
            }

            my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
                TicketID      => $Param{Data}->{TicketID},
                DynamicFields => scalar( @FilterDynamicFields ) ? \@FilterDynamicFields : 0,
                UserID        => 1,
            );

            # clone relevant data before manipulations
            for my $Field ( keys( %FilterFields ) ) {
                if (
                    defined( $Ticket{ $Field } )
                    && (
                        ref( $Ticket{ $Field } ) eq ''
                        || ref( $Ticket{ $Field } ) eq 'ARRAY'
                    )
                ) {
                    $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} }->{ $Field } = $Ticket{ $Field };
                }
            }
        }

        FILTER:
        for my $Filter ( @{ $Filters } ) {
            # check ticket data directly for simple cases
            if (
                IsArrayRefWithData( $Filter->{AND} )
                && !IsArrayRefWithData( $Filter->{OR} )
            ) {
                my $Match = 1;
                CRITERION:
                for my $Criterion ( @{ $Filter->{AND} } ) {
                    my $Field    = $Criterion->{Field}    // q{};
                    my $Operator = $Criterion->{Operator} // q{};
                    my $Value    = $Criterion->{Value}    // q{};

                    # catch invalid filter
                    next FILTER if (
                        !$Field
                        || !$Operator
                    );

                    # handle not so simple operators
                    if (
                        $Operator ne 'EQ'
                        && $Operator ne 'IN'
                    ) {
                        $Match = undef;         # undef = unknown, use fallback
                        next CRITERION;         # check other criterions for not matching values
                    }

                    # prepare values for check
                    my @CheckValues = ref( $Value ) eq 'ARRAY' ? @{$Value} : ($Value);

                    # special handling for StateType Open and Closed
                    if (
                        $Field eq 'StateType'
                        && any { $_ eq 'Open' || $_ eq 'Closed' } @CheckValues
                    ) {
                        # prepare viewable state type, if not done before
                        if ( !$Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} }->{ViewableStateType} ) {
                            my %ViewableStateList = $Kernel::OM->Get('State')->StateGetStatesByType(
                                Type   => 'Viewable',
                                Result => 'HASH',
                            );

                            $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} }->{ViewableStateType} =
                                $ViewableStateList{ $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} }->{StateID} } ? 'Open' : 'Closed';
                        }

                        # use prepared field for check
                        $Field = 'ViewableStateType';
                    }

                    # handle unknown data field
                    if ( !exists( $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} }->{ $Field } ) ) {
                        $Match = undef;         # undef = unknown, use fallback
                        next CRITERION;         # check other criterions for not matching values
                    }

                    # get data value
                    my $DataVal = $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} }->{ $Field };

                    # prepare data values for check
                    my @DataVals  = ref( $DataVal ) eq 'ARRAY' ? @{ $DataVal } : ($DataVal);
                    my %DataValSet = map { $_ => 1 } @DataVals;

                    # check for matching ticket value
                    if ( !any { $DataValSet{ $_ } } @CheckValues ) {
                        next FILTER;
                    }
                }

                # when all criterions could be handled and matched, we have a match
                if ( $Match ) {
                    # delete check data, job execution could update data
                    delete( $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} } );

                    return ( $Param{Data}->{TicketID} );
                }
            }

            # remember filter as still possible
            push( @{ $PossibleFilters }, $Filter );
        }
    }
    # use all filters as possible filter
    elsif ( IsArrayRefWithData( $Filters ) ) {
        $PossibleFilters = $Filters;
    }

    # no possible filter left after direct check
    if (
        IsArrayRefWithData( $Filters )
        && !IsArrayRefWithData( $PossibleFilters )
    ) {
        return ();
    }

    # extend the filter with the ArticleID or TicketID
    if (
        IsHashRefWithData( $Param{Data} )
        && $Param{Data}->{ArticleID}
    ) {
        # add ArticleID to filter
        $PossibleFilters = $Self->_ExtendFilter(
            Filters => $PossibleFilters,
            Extend  => {
                Field    => 'ArticleID',
                Operator => 'EQ',
                Value    => $Param{Data}->{ArticleID}
            }
        );
    }
    elsif (
        IsHashRefWithData( $Param{Data} )
        && $Param{Data}->{TicketID}
    ) {
        # add TicketID to filter
        $PossibleFilters = $Self->_ExtendFilter(
            Filters => $PossibleFilters,
            Extend  => {
                Field    => 'TicketID',
                Operator => 'EQ',
                Value    => $Param{Data}->{TicketID}
            }
        )
    }

    my @TicketIDs;

    # do the search
    if ( IsArrayRefWithData( $PossibleFilters ) ) {
        SEARCH:
        for my $Search ( @{ $PossibleFilters } ) {
            my @TicketIDsPart = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'Ticket',
                Result     => 'ARRAY',
                Search     => $Search,
                Sort       => $Param{Sort},
                UserID     => 1,
                UserType   => 'Agent'
            );
            push(@TicketIDs, @TicketIDsPart);

            # break on match for specific ticket
            if (
                scalar( @TicketIDs )
                && IsHashRefWithData( $Param{Data} )
                && $Param{Data}->{TicketID}
            ) {
                last SEARCH;
            }
        }
        if ( scalar( @TicketIDs ) > 1 ) {
            @TicketIDs = $Kernel::OM->Get('Main')->GetUnique( @TicketIDs );
        }

        # do additional "search" to sort all results combined, if needed
        if (
            scalar( @TicketIDs ) > 1
            && IsArrayRefWithData( $Param{Sort} )
            && scalar( @{ $PossibleFilters } ) > 1
        ) {
            @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'Ticket',
                Result     => 'ARRAY',
                Search     => {
                    AND => [
                        {
                            Field    => 'TicketID',
                            Operator => 'IN',
                            Value    => \@TicketIDs
                        }
                    ]
                },
                Sort       => $Param{Sort},
                UserID     => 1,
                UserType   => 'Agent'
            );
        }
    } else {
        @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Ticket',
            Result     => 'ARRAY',
            Sort       => $Param{Sort},
            UserID     => 1,
            UserType   => 'Agent'
        );
    }

    # check for matching object search filter for event based execution
    if (
        $Param{IsEventBased}
        && IsHashRefWithData( $Param{Data} )
        && $Param{Data}->{TicketID}
        && scalar( @TicketIDs )
    ) {
        # delete check data, job execution could update data
        delete( $Self->{ObjectCheckData}->{ $Param{Data}->{TicketID} } );
    }

    return @TicketIDs;
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
