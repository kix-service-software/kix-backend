# --
# Kernel/API/Operation/Contact/ContactGet.pm - API Contact Get operation backend
# based upon Kernel/API/Operation/Ticket/TicketGet.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Contact::ContactGet - API Contact Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Contact::ContactGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Contact::ContactGet');

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
        'ContactID' => {
            Type     => 'ARRAY',
            Required => 1
        }                
    }
}

=item Run()

perform ContactGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ContactID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
        Data         => {
            Contact => [
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

    my @ContactList;
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get('CustomerUser');
  
    # start loop
    foreach my $ContactID ( @{$Param{Data}->{ContactID}} ) {

        # get the Contact data
        my %ContactData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $ContactID,
        );

        if ( !IsHashRefWithData( \%ContactData ) ) {

            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No Contact data found for ContactID $ContactID.",
            );
        }

        # map UserID to ContactID
        $ContactData{ContactID} = $ContactData{UserID};
        delete $ContactData{UserID};

        # map Source to SourceID
        $ContactData{SourceID} = $ContactData{Source};
        delete $ContactData{Source};

        my $AttributeWhitelist = $Self->{Config}->{AttributeWhitelist};

        # add attributes from Map to whitelist
        foreach my $Field ( @{$ContactData{Config}->{Map}} ) {
            next if !$Field->{Exposed};
            $AttributeWhitelist->{$Field->{Attribute}} = 1;
        }

        # add required attributes to whitelist
        foreach my $Attr ( qw(SourceID ContactID CreateBy CreateTime ChangeBy ChangeTime ValidID DisplayValue UserCustomerIDs) ) {
            $AttributeWhitelist->{$Attr} = 1;
        } 

        # always add UserCustomerIDs (override existing one)
        my @CustomerIDs = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerIDs(
            User => $ContactID,
        );
        $ContactData{UserCustomerIDs} = \@CustomerIDs;

        # filter valid attributes
        if ( IsHashRefWithData($AttributeWhitelist) ) {
            foreach my $Attr (sort keys %ContactData) {
                delete $ContactData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
            }
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeBlacklist}) ) {
            foreach my $Attr (sort keys %ContactData) {
                delete $ContactData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
            }
        }

        # include Tickets if requested
        if ( $Param{Data}->{include}->{Tickets} ) {
            # execute ticket search
            my @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Filter => {
                    AND => [
                        {
                            Field    => 'CustomerUserID',
                            Operator => 'EQ',
                            Value    => $ContactID,
                        }
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'ARRAY',
            );
            $ContactData{Tickets} = \@TicketIDs;
        }

        # include TicketStats if requested
        if ( $Param{Data}->{include}->{TicketStats} ) {
            # execute ticket searches
            my %TicketStats;
            # new tickets
            $TicketStats{NewCount} = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Filter => {
                    AND => [
                        {
                            Field    => 'CustomerUserID',
                            Operator => 'EQ',
                            Value    => $ContactID,
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
                Filter => {
                    AND => [
                        {
                            Field    => 'CustomerUserID',
                            Operator => 'EQ',
                            Value    => $ContactID,
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
                Filter => {
                    AND => [
                        {
                            Field    => 'CustomerUserID',
                            Operator => 'EQ',
                            Value    => $ContactID,
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
                Filter => {
                    AND => [
                        {
                            Field    => 'CustomerUserID',
                            Operator => 'EQ',
                            Value    => $ContactID,
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
            $ContactData{TicketStats} = \%TicketStats;
        }

        # add
        push(@ContactList, \%ContactData);
    }

    if ( scalar(@ContactList) == 1 ) {
        return $Self->_Success(
            Contact => $ContactList[0],
        );    
    }

    return $Self->_Success(
        Contact => \@ContactList,
    );
}

1;
