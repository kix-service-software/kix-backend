# --
# Kernel/API/Operation/Customer/CustomerGet.pm - API Customer Get operation backend
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

package Kernel::API::Operation::V1::Customer::CustomerGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Customer::CustomerGet - API Customer Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Customer::CustomerGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Customer::CustomerGet');

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
        'CustomerID' => {
            Type     => 'ARRAY',
            Required => 1
        }                
    }
}

=item Run()

perform CustomerGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            CustomerID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
        Data         => {
            Customer => [
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

    my @CustomerList;

    # start loop
    foreach my $CustomerID ( @{$Param{Data}->{CustomerID}} ) {

        # get the Customer data
        my %CustomerData = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanyGet(
            CustomerID => $CustomerID,
        );

        if ( !IsHashRefWithData( \%CustomerData ) ) {

            return $Self->_Error(
                Code => 'Object.NotFound'
            );
        }

        # map Source to SourceID
        $CustomerData{SourceID} = $CustomerData{Source};
        delete $CustomerData{Source};

        my $AttributeWhitelist = $Self->{Config}->{AttributeWhitelist};

        # add attributes from Map to whitelist
        foreach my $Field ( @{$CustomerData{Config}->{Map}} ) {
            next if !$Field->{Exposed};
            $AttributeWhitelist->{$Field->{Attribute}} = 1;
        }

        # add required attributes to whitelist
        foreach my $Attr ( qw(SourceID CustomerID CreateBy CreateTime ChangeBy ChangeTime ValidID DisplayValue) ) {
            $AttributeWhitelist->{$Attr} = 1;
        } 

        # filter valid attributes
        if ( IsHashRefWithData($AttributeWhitelist) ) {
            foreach my $Attr (sort keys %CustomerData) {
                delete $CustomerData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
            }
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeBlacklist}) ) {
            foreach my $Attr (sort keys %CustomerData) {
                delete $CustomerData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
            }
        }

        # include Contacts if requested
        if ( $Param{Data}->{include}->{Contacts} ) {
            # execute customer user search
            my %CustomerUserList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
                CustomerID => $CustomerID,
            );
            $CustomerData{Contacts} = [ sort keys %CustomerUserList ];

            # inform API caching about a new dependency
            $Self->AddCacheDependency(Type => 'CustomerUser');
        }

        # include Tickets if requested
        if ( $Param{Data}->{include}->{Tickets} ) {
            # execute ticket search
            my @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
                Search => {
                    AND => [
                        {
                            Field    => 'CustomerID',
                            Operator => 'EQ',
                            Value    => $CustomerID,
                        }
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'ARRAY',
            );
            $CustomerData{Tickets} = \@TicketIDs;

            # inform API caching about a new dependency
            $Self->AddCacheDependency(Type => 'Ticket');
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
                            Field    => 'CustomerID',
                            Operator => 'EQ',
                            Value    => $CustomerID,
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
                            Field    => 'CustomerID',
                            Operator => 'EQ',
                            Value    => $CustomerID,
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
                            Field    => 'CustomerID',
                            Operator => 'EQ',
                            Value    => $CustomerID,
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
                            Field    => 'CustomerID',
                            Operator => 'EQ',
                            Value    => $CustomerID,
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
            $CustomerData{TicketStats} = \%TicketStats;

            # inform API caching about a new dependency
            $Self->AddCacheDependency(Type => 'Ticket');
        }

        # add
        push(@CustomerList, \%CustomerData);
    }

    if ( scalar(@CustomerList) == 1 ) {
        return $Self->_Success(
            Customer => $CustomerList[0],
        );    
    }

    return $Self->_Success(
        Customer => \@CustomerList,
    );
}

1;
