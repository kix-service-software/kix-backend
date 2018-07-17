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

    # prepare filter if given
    my %SearchFilter;
    if ( IsArrayRefWithData($Self->{Filter}->{Contact}->{AND}) ) {
        foreach my $FilterItem ( @{$Self->{Filter}->{Contact}->{AND}} ) {
            # ignore everything that we don't support in the core DB search (the rest will be done in the generic API filtering)
            next if ($FilterItem->{Operator} ne 'EQ');

            if ($FilterItem->{Field} =~ /^(CustomerID|UserLogin)$/g) {
                $SearchFilter{$FilterItem->{Field}} = $FilterItem->{Value};
            }
            elsif ($FilterItem->{Field} =~ /^(ValidID)$/g) {
                $SearchFilter{Valid} = $FilterItem->{Value};
            }
            else {
                $SearchFilter{Search} = $FilterItem->{Value};
            }
        }
    }

    # perform Contact search
    my %ContactList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
        %SearchFilter,
    );

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
