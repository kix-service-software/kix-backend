# --
# Kernel/API/Operation/SystemAddress/SystemAddressCreate.pm - API SystemAddress Create operation backend
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

package Kernel::API::Operation::V1::SystemAddress::SystemAddressSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::SystemAddress::SystemAddressGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SystemAddress::SystemAddressSearch - API SystemAddress Search Operation backend

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

perform SystemAddressSearch Operation. This will return a SystemAddress ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SystemAddress => [
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
            Code    => 'WebService.InvalidConfiguration',
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

    # perform SystemAddress search
    my %SystemAddressList = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressList(
        Valid => 1,
    );

	# get already prepared SystemAddress data from SystemAddressGet operation
    if ( IsHashRefWithData(\%SystemAddressList) ) {  	
        my $SystemAddressGetResult = $Self->ExecOperation(
            OperationType => 'V1::SystemAddress::SystemAddressGet',
            Data      => {
                SystemAddressID => join(',', sort keys %SystemAddressList),
            }
        );    

        if ( !IsHashRefWithData($SystemAddressGetResult) || !$SystemAddressGetResult->{Success} ) {
            return $SystemAddressGetResult;
        }

        my @SystemAddressDataList = IsArrayRefWithData($SystemAddressGetResult->{Data}->{SystemAddress}) ? @{$SystemAddressGetResult->{Data}->{SystemAddress}} : ( $SystemAddressGetResult->{Data}->{SystemAddress} );

        if ( IsArrayRefWithData(\@SystemAddressDataList) ) {
            return $Self->_Success(
                SystemAddress => \@SystemAddressDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SystemAddress => [],
    );
}

1;