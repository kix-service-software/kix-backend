# --
# Kernel/API/Operation/Customer/CustomerSourceSearch.pm - API Customer Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Customer::CustomerSourceSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Customer::CustomerSourceSearch - API Customer Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

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

    return $Self;
}

=item Run()

perform CustomerSourceSearch Operation. This will return a Customer ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            CustomerSource => [
                {
                },
                {                    
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # perform search
    my %SourceListRW = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanySourceList(
        ReadOnly => 0
    );
    my %SourceListRO = $Kernel::OM->Get('Kernel::System::CustomerCompany')->CustomerCompanySourceList(
        ReadOnly => 1
    );

    if (IsHashRefWithData(\%SourceListRO) || IsHashRefWithData(\%SourceListRW) ) {
        
        my @ResultList;
        foreach my $Key (sort keys %SourceListRO) {
            push(@ResultList, {
                ID       => $Key,
                Name     => $SourceListRO{$Key},
                ReadOnly => 1,
            });
        }
        foreach my $Key (sort keys %SourceListRW) {
            push(@ResultList, {
                ID       => $Key,
                Name     => $SourceListRW{$Key},
                ReadOnly => 0,
            });
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                CustomerSource => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        CustomerSource => [],
    );
}

1;
