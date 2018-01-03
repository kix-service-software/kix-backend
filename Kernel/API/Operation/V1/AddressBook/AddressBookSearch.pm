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

package Kernel::API::Operation::V1::AddressBook::AddressBookSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::AddressBook::AddressBookGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::AddressBook::AddressBookSearch - API AddressBook Search Operation backend

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

perform AddressBookSearch Operation. This will return a Address ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            AddressBook => [
                {},
                {}
            ]
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

    # perform AddressBook search
    my %AddressBookList = $Kernel::OM->Get('Kernel::System::AddressBook')->AddressList(
        Search => '',               
    );

	# get already prepared AddressBook data from AddressBookGet operation
    if ( IsHashRefWithData(\%AddressBookList) ) {  	
        my $AddressBookGetResult = $Self->ExecOperation(
            OperationType => 'V1::AddressBook::AddressBookGet',
            Data      => {
                AddressID => join(',', sort keys %AddressBookList),
            }
        );    

        if ( !IsHashRefWithData($AddressBookGetResult) || !$AddressBookGetResult->{Success} ) {
            return $AddressBookGetResult;
        }

        my @AddressBookDataList = IsArrayRefWithData($AddressBookGetResult->{Data}->{AddressBook}) ? @{$AddressBookGetResult->{Data}->{AddressBook}} : ( $AddressBookGetResult->{Data}->{AddressBook} );

        if ( IsArrayRefWithData(\@AddressBookDataList) ) {
            return $Self->_Success(
                AddressBook => \@AddressBookDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        AddressBook => [],
    );
}

1;