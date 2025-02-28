# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
        my %OrganisationData = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID            => $ID,
            DynamicFields => $Param{Data}->{include}->{DynamicFields},
        );

        if ( !IsHashRefWithData( \%OrganisationData ) ) {

            return $Self->_Error(
                Code => 'Object.NotFound'
            );
        }

        if ( $Param{Data}->{include}->{DynamicFields} ) {
            my @DynamicFields;

            # inform API caching about a new dependency
            $Self->AddCacheDependency(Type => 'DynamicField');

            # remove all dynamic fields from organisation hash and set them into an array.
            ATTRIBUTE:
            for my $Attribute ( sort keys %OrganisationData ) {

                if ( $Attribute =~ m{\A DynamicField_(.*) \z}msx ) {
                    if ( $OrganisationData{$Attribute} ) {
                        my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
                            Name => $1,
                        );
                        if ( IsHashRefWithData($DynamicFieldConfig) ) {

                            # ignore DFs which are not visible for the customer, if the user session is a Customer session
                            next ATTRIBUTE if $Self->{Authorization}->{UserType} eq 'Customer' && !$DynamicFieldConfig->{CustomerVisible};

                            my $PreparedValue = $Self->_GetPrepareDynamicFieldValue(
                                Config          => $DynamicFieldConfig,
                                Value           => $OrganisationData{$Attribute},
                                NoDisplayValues => [ split(',', $Param{Data}->{NoDynamicFieldDisplayValues}||'') ]
                            );

                            if (IsHashRefWithData($PreparedValue)) {
                                push(@DynamicFields, $PreparedValue);
                            }
                        }
                    }
                    delete $OrganisationData{$Attribute};
                }
            }

            # add dynamic fields array into 'DynamicFields' hash key if any
            if (@DynamicFields) {
                $OrganisationData{DynamicFields} = \@DynamicFields;
            }
            else {
                $OrganisationData{DynamicFields} = [];
            }
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
            $TicketStats{NewCount} = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'Ticket',
                Search     => {
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
                UserID   => $Self->{Authorization}->{UserID},
                UserType => $Self->{Authorization}->{UserType},
                Result   => 'COUNT',
            );
            # open tickets
            $TicketStats{OpenCount} = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'Ticket',
                Search     => {
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
                UserID   => $Self->{Authorization}->{UserID},
                UserType => $Self->{Authorization}->{UserType},
                Result   => 'COUNT',
            );
            # pending tickets
            $TicketStats{PendingReminderCount} = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'Ticket',
                Search     => {
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
                UserID   => $Self->{Authorization}->{UserID},
                UserType => $Self->{Authorization}->{UserType},
                Result   => 'COUNT',
            );

            $OrganisationData{TicketStats} = \%TicketStats;

            # inform API caching about a new dependency
            $Self->AddCacheDependency(Type => 'Ticket');
            $Self->AddCacheDependency( Type => 'User' );
            $Self->AddCacheDependency( Type => 'Contact' );
        }

        # include assigned config items if requested
        if ( $Param{Data}->{include}->{AssignedConfigItems} ) {

            my @ItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'ConfigItem',
                Result     => 'ARRAY',
                Search     => {
                    AND => [
                        {
                            Field    => 'AssignedOrganisation',
                            Operator => 'EQ',
                            Type     => 'NUMERIC',
                            Value    => $OrganisationData{ID}
                        }
                    ]
                },
                UserID   => $Self->{Authorization}->{UserID},
                UserType => $Self->{Authorization}->{UserType}
            );

            # filter for customer assigned config items if necessary
            my @ConfigItemIDList = $Self->_FilterCustomerUserVisibleObjectIds(
                ObjectType   => 'ConfigItem',
                ObjectIDList => \@ItemIDs
            );

            $OrganisationData{AssignedConfigItems} = \@ConfigItemIDList;

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
