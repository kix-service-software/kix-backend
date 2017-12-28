# --
# Kernel/API/Operation/Signature/SignatureSearch.pm - API Signature Search operation backend
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

package Kernel::API::Operation::V1::Signature::SignatureSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Signature::SignatureGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Signature::SignatureSearch - API Signature Search Operation backend

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

perform SignatureSearch Operation. This will return a Signature ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Signature => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebServiceID},
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

    # perform Signature search
    my %SignatureList = $Kernel::OM->Get('Kernel::System::Signature')->SignatureList(
        Valid => 1,
    );

    # get already prepared Signature data from SignatureGet operation
    if ( IsHashRefWithData(\%SignatureList) ) {  	
        my $SignatureGetResult = $Self->ExecOperation(
            OperationType => 'V1::Signature::SignatureGet',
            Data      => {
                SignatureID => join(',', sort keys %SignatureList),
            }
        );    

        if ( !IsHashRefWithData($SignatureGetResult) || !$SignatureGetResult->{Success} ) {
            return $SignatureGetResult;
        }

        my @SignatureDataList = IsArrayRefWithData($SignatureGetResult->{Data}->{Signature}) ? @{$SignatureGetResult->{Data}->{Signature}} : ( $SignatureGetResult->{Data}->{Signature} );

        if ( IsArrayRefWithData(\@SignatureDataList) ) {
            return $Self->_Success(
                Signature => \@SignatureDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Signature => {},
    );
}

1;