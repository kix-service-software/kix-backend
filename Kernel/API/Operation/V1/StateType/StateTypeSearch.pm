# --
# Kernel/API/Operation/StateType/StateTypeCreate.pm - API StateType Create operation backend
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

package Kernel::API::Operation::V1::StateType::StateTypeSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::StateType::StateTypeGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::StateType::StateTypeSearch - API StateType Search Operation backend

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

perform StateTypeSearch Operation. This will return a StateType ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            StateType => [
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

    # perform StateType search
    my %StateTypeList = $Kernel::OM->Get('Kernel::System::State')->StateTypeList(
        UserID => $Self->{Authorization}->{UserID},
        Valid => 1,
    );

	# get already prepared StateType data from StateTypeGet operation
    if ( IsHashRefWithData(\%StateTypeList) ) {  	
        my $StateTypeGetResult = $Self->ExecOperation(
            OperationType => 'V1::StateType::StateTypeGet',
            Data      => {
                StateTypeID => join(',', sort keys %StateTypeList),
            }
        );    

        if ( !IsHashRefWithData($StateTypeGetResult) || !$StateTypeGetResult->{Success} ) {
            return $StateTypeGetResult;
        }

        my @StateTypeDataList = IsArrayRefWithData($StateTypeGetResult->{Data}->{StateType}) ? @{$StateTypeGetResult->{Data}->{StateType}} : ( $StateTypeGetResult->{Data}->{StateType} );

        if ( IsArrayRefWithData(\@StateTypeDataList) ) {
            return $Self->_Success(
                StateType => \@StateTypeDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        StateType => [],
    );
}

1;