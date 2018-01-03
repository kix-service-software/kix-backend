# --
# Kernel/API/Operation/Salutation/SalutationSearch.pm - API Salutation Search operation backend
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

package Kernel::API::Operation::V1::Salutation::SalutationSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Salutation::SalutationGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Salutation::SalutationSearch - API Salutation Search Operation backend

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

perform SalutationSearch Operation. This will return a Salutation ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Salutation => [
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

    # perform Salutation search
    my %SalutationList = $Kernel::OM->Get('Kernel::System::Salutation')->SalutationList(
        Valid => 1,
    );

    # get already prepared Salutation data from SalutationGet operation
    if ( IsHashRefWithData(\%SalutationList) ) {  	
        my $SalutationGetResult = $Self->ExecOperation(
            OperationType => 'V1::Salutation::SalutationGet',
            Data      => {
                SalutationID => join(',', sort keys %SalutationList),
            }
        );    

        if ( !IsHashRefWithData($SalutationGetResult) || !$SalutationGetResult->{Success} ) {
            return $SalutationGetResult;
        }

        my @SalutationDataList = IsArrayRefWithData($SalutationGetResult->{Data}->{Salutation}) ? @{$SalutationGetResult->{Data}->{Salutation}} : ( $SalutationGetResult->{Data}->{Salutation} );

        if ( IsArrayRefWithData(\@SalutationDataList) ) {
            return $Self->_Success(
                Salutation => \@SalutationDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Salutation => [],
    );
}

1;