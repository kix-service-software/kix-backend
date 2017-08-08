# --
# Kernel/GenericInterface/Operation/Customer/CustomerSearch.pm - GenericInterface Customer Search operation backend
# based upon Kernel/GenericInterface/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Customer::CustomerSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
    Kernel::API::Operation::V1::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Customer::CustomerSearch - GenericInterface Customer Search Operation backend

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

    return $Self;
}

=item Run()

perform CustomerSearch Operation. This will return a Customer ID list.

    my $Result = $OperationObject->Run(
        Data => {
            SessionID    => 123,                                          # required
            ChangedAfter => '2006-01-09 00:00:01',                        # (optional)            
            OrderBy      => 'Down|Up',                                    # (optional) Default: Up                       
            Limit        => 122,                                          # (optional) Default: 500
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data         => {
            TicketID => [ 1, 2, 3, 4 ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    my ( $CustomerID, $CustomerType ) = $Self->Auth(
        %Param,
    );

    return $Self->ReturnError(
        ErrorCode    => 'CustomerSearch.AuthFail',
        ErrorMessage => "CustomerSearch: Authorization failing!",
    ) if !$CustomerID;

    # all needed variables
    $Self->{ChangedAfter} = $Param{Data}->{ChangedAfter}
        || undef;
    $Self->{Limit} = $Param{Data}->{Limit}
        || 500;
    $Self->{OrderBy} = $Param{Data}->{OrderBy}
        || 'Up';

    # perform company search
    my %CompanyList = $Kernel::OM->Get('Kernel::System::Customer')->CustomerList();

    if (IsHashRefWithData(\%CompanyList)) {
        my @CompanyIDs = sort keys %CompanyList;
        
        if ($Self->{ChangedAfter}) {
            my $ChangedAfterUnixtime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                String => $Self->{ChangedAfter},
            );
            
            # filter list
            my @FilteredCompanyIDs;
            foreach my $CompanyID (@CompanyIDs) {
                my %CompanyData = $Kernel::OM->Get('Kernel::System::Customer')->CustomerGet(
                    CustomerID => $CompanyID,
                ); 
                next if !IsHashRefWithData(\%CompanyData);
                
                # filter change time
                my $ChangeTimeUnix = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                    String => $CompanyData{ChangeTime},
                );
                next if $ChangeTimeUnix < $ChangedAfterUnixtime;
                
                # limit list
                last if scalar(@FilteredCompanyIDs) > $Self->{Limit};
                
                push(@FilteredCompanyIDs, $CompanyID);                                
            }
            
            @CompanyIDs = @FilteredCompanyIDs; 
        }
        else {
            # limit list
            @CompanyIDs = splice(@CompanyIDs, 0, $Self->{Limit}); 
        }

        # do we have to sort downwards ?
        @CompanyIDs = reverse @CompanyIDs if ($Self->{OrderBy} eq 'Down');        

        if (IsArrayRefWithData(\@CompanyIDs)) {
            return {
                Success => 1,
                Data    => {
                    CustomerID => \@CompanyIDs,
                },
            };
        }
    }

    # return result
    return {
        Success => 1,
        Data    => {},
    };
}

1;
