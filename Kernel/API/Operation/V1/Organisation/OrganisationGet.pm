# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Organisation::OrganisationGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Organisation::OrganisationGet - API Organisation Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Organisation::OrganisationGet->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Organisation::OrganisationGet');

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
        'OrganisationID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }                
    }
}

=item Run()

perform OrganisationGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            OrganisationID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
        Data         => {
            Organisation => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @OrganisationSearch;

    # start loop
    foreach my $ID ( @{$Param{Data}->{OrganisationID}} ) {

        # get the Organisation data
        my %OrganisationData = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationGet(
            ID => $ID,
        );

        if ( !IsHashRefWithData( \%OrganisationData ) ) {

            return $Self->_Error(
                Code => 'Object.NotFound'
            );
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeWhitelist}) ) {
            foreach my $Attr (sort keys %OrganisationData) {
                delete $OrganisationData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
            }
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeBlacklist}) ) {
            foreach my $Attr (sort keys %OrganisationData) {
                delete $OrganisationData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
            }
        }

        # include TicketStats if requested
        if ( $Param{Data}->{include}->{TicketStats} ) {
            # execute ticket searches
            my %TicketStats;
            # new tickets
            $TicketStats{NewCount} = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Search => {
                    AND => [
                        {
                            Field    => 'OrganisationID',
                            Operator => 'EQ',
                            Value    => $ID,
                        },
                        {
                            Field    => 'StateType',
                            Operator => 'EQ',
                            Value    => 'new',
                        },
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );
            # open tickets
            $TicketStats{OpenCount} = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Search => {
                    AND => [
                        {
                            Field    => 'OrganisationID',
                            Operator => 'EQ',
                            Value    => $ID,
                        },
                        {
                            Field    => 'StateType',
                            Operator => 'EQ',
                            Value    => 'open',
                        },
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );
            # pending tickets
            $TicketStats{PendingReminderCount} = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Search => {
                    AND => [
                        {
                            Field    => 'OrganisationID',
                            Operator => 'EQ',
                            Value    => $ID,
                        },
                        {
                            Field    => 'StateType',
                            Operator => 'EQ',
                            Value    => 'pending reminder',
                        },
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );
            # escalated tickets
            $TicketStats{EscalatedCount} = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Search => {
                    AND => [
                        {
                            Field    => 'OrganisationID',
                            Operator => 'EQ',
                            Value    => $ID,
                        },
                        {
                            Field    => 'EscalationTime',
                            Operator => 'LT',
                            DataType => 'NUMERIC',
                            Value    => $Kernel::OM->Get('Kernel::System::Time')->CurrentTimestamp(),
                        },
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );
            $OrganisationData{TicketStats} = \%TicketStats;

            # inform API caching about a new dependency
            $Self->AddCacheDependency(Type => 'Ticket');
            $Self->AddCacheDependency( Type => 'User' );
            $Self->AddCacheDependency( Type => 'Contact' );
        }

        # include assigned config items if requested
        if ( $Param{Data}->{include}->{AssignedConfigItems} ) {

            my $ItemIDs = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->GetAssignedConfigItemsForObject(
                ObjectType => 'Organisation',
                Object     => \%OrganisationData
            );

            $OrganisationData{AssignedConfigItems} = IsArrayRef($ItemIDs) ? $ItemIDs : [];

            # inform API caching about a new dependency
            $Self->AddCacheDependency(Type => 'ITSMConfigurationManagement');
        }

        # add
        push(@OrganisationSearch, \%OrganisationData);
    }

    if ( scalar(@OrganisationSearch) == 1 ) {
        return $Self->_Success(
            Organisation => $OrganisationSearch[0],
        );    
    }

    return $Self->_Success(
        Organisation => \@OrganisationSearch,
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
