# --
# Kernel/API/Operation/Contact/ContactSearch.pm - API Contact Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Contact::ContactSearch - API Contact Search Operation backend

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

perform ContactSearch Operation. This will return a Contact ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Contact => [
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
    my %ContactList;

    # prepare filter if given
    my %SearchFilter;
    if ( IsHashRefWithData($Self->{Filter}->{Contact}) ) {
        foreach my $FilterType ( keys %{$Self->{Filter}->{Contact}} ) {
            my %FilterTypeResult;
            foreach my $FilterItem ( @{$Self->{Filter}->{Contact}->{$FilterType}} ) {
                my $Value = $FilterItem->{Value};

                if ( $FilterItem->{Operator} eq 'CONTAINS' ) {
                   $Value = '*' . $Value . '*';
                }
                elsif ( $FilterItem->{Operator} eq 'STARTSWITH' ) {
                   $Value = $Value . '*';
                }
                if ( $FilterItem->{Operator} eq 'ENDSWITH' ) {
                   $Value = '*' . $Value;
                }

                if ($FilterItem->{Field} =~ /^(CustomerID|UserLogin)$/g) {
                    $SearchFilter{$FilterItem->{Field}} = $Value;
                }
                elsif ($FilterItem->{Field} =~ /^(ValidID)$/g) {
                    $SearchFilter{Valid} = $Value;
                }
                else {
                    $SearchFilter{Search} = $Value;
                }

                # perform Contact search
                my %SearchResult = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
                   %SearchFilter,
                );

                if ( $FilterType eq 'AND' ) {
                    if ( !%FilterTypeResult ) {
                        %FilterTypeResult = %SearchResult;
                    }
                    else {
                        # remove all IDs from type result that we don't have in this search
                        foreach my $Key ( keys %FilterTypeResult ) {
                            delete $FilterTypeResult{$Key} if !exists $SearchResult{$Key};
                        }
                    }
                }
                elsif ( $FilterType eq 'OR' ) {
                    # merge results
                    %FilterTypeResult = (
                        %FilterTypeResult,
                        %SearchResult,
                    );
                }
            }

            if ( !%ContactList ) {
                %ContactList = %FilterTypeResult;
            }
            else {
                # combine both results by AND
                # remove all IDs from type result that we don't have in this search
                foreach my $Key ( keys %ContactList ) {
                    delete $ContactList{$Key} if !exists $FilterTypeResult{$Key};
                }
            }
        }
    }
    else {
        # perform Contact search without any filter
        %ContactList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch();
    }

    if (IsHashRefWithData(\%ContactList)) {

        # get already prepared Contact data from ContactGet operation
        my $ContactGetResult = $Self->ExecOperation(
            OperationType => 'V1::Contact::ContactGet',
            Data          => {
                ContactID => join(',', sort keys %ContactList),
            }
        );
        if ( !IsHashRefWithData($ContactGetResult) || !$ContactGetResult->{Success} ) {
            return $ContactGetResult;
        }

        my @ResultList = IsArrayRefWithData($ContactGetResult->{Data}->{Contact}) ? @{$ContactGetResult->{Data}->{Contact}} : ( $ContactGetResult->{Data}->{Contact} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Contact => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Contact => [],
    );
}

1;
