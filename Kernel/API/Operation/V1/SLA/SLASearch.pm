# --
# Kernel/API/Operation/SLA/SLACreate.pm - API SLA Create operation backend
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

package Kernel::API::Operation::V1::SLA::SLASearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::SLA::SLAGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SLA::SLASearch - API SLA Search Operation backend

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

perform SLASearch Operation. This will return a SLA ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SLA => [
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

    # perform SLA search
    my %SLAList = $Kernel::OM->Get('Kernel::System::SLA')->SLAList(
        UserID  => $Self->{Authorization}->{UserID},
    );

	# get already prepared SLA data from SLAGet operation
    if ( IsHashRefWithData(\%SLAList) ) {  	
        my $SLAGetResult = $Self->ExecOperation(
            OperationType => 'V1::SLA::SLAGet',
            Data      => {
                SLAID => join(',', sort keys %SLAList),
            }
        );    

        if ( !IsHashRefWithData($SLAGetResult) || !$SLAGetResult->{Success} ) {
            return $SLAGetResult;
        }

        my @SLADataList = IsArrayRefWithData($SLAGetResult->{Data}->{SLA}) ? @{$SLAGetResult->{Data}->{SLA}} : ( $SLAGetResult->{Data}->{SLA} );

        if ( IsArrayRefWithData(\@SLADataList) ) {
            return $Self->_Success(
                SLA => \@SLADataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SLA => [],
    );
}

1;