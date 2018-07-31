# --
# Kernel/API/Operation/AddressBook/AddressBookCreate.pm - API AddressBook Create operation backend
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

package Kernel::API::Operation::V1::AddressBook::AddressSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::AddressBook::AddressGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::AddressBook::AddressSearch - API AddressBook Search Operation backend

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

perform AddressSearch Operation. This will return a Address list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Address => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform AddressBook search
    my %AddressList = $Kernel::OM->Get('Kernel::System::AddressBook')->AddressList(
        Search => '',               
    );

	# get already prepared AddressBook data from AddressGet operation
    if ( IsHashRefWithData(\%AddressList) ) {  	
        my $AddressBookGetResult = $Self->ExecOperation(
            OperationType => 'V1::AddressBook::AddressGet',
            Data      => {
                AddressID => join(',', sort keys %AddressList),
            }
        );    

        if ( !IsHashRefWithData($AddressBookGetResult) || !$AddressBookGetResult->{Success} ) {
            return $AddressBookGetResult;
        }

        my @AddressDataList = IsArrayRefWithData($AddressBookGetResult->{Data}->{Address}) ? @{$AddressBookGetResult->{Data}->{Address}} : ( $AddressBookGetResult->{Data}->{Address} );

        if ( IsArrayRefWithData(\@AddressDataList) ) {
            return $Self->_Success(
                Address => \@AddressDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Address => [],
    );
}

1;