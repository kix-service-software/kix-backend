# --
# Kernel/API/Operation/Queue/QueueCreate.pm - API Queue Create operation backend
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

package Kernel::API::Operation::V1::Queue::QueueSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Queue::QueueGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Queue::QueueSearch - API Queue Search Operation backend

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

perform QueueSearch Operation. This will return a Queue ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Queue => [
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

    # perform Queue search
    my %QueueList = $Kernel::OM->Get('Kernel::System::Queue')->QueueList();

	# get already prepared Queue data from QueueGet operation
    if ( IsHashRefWithData(\%QueueList) ) {  	
        my $QueueGetResult = $Self->ExecOperation(
            OperationType => 'V1::Queue::QueueGet',
            Data      => {
                QueueID => join(',', sort keys %QueueList),
            }
        );    

        if ( !IsHashRefWithData($QueueGetResult) || !$QueueGetResult->{Success} ) {
            return $QueueGetResult;
        }

        my @QueueDataList = IsArrayRefWithData($QueueGetResult->{Data}->{Queue}) ? @{$QueueGetResult->{Data}->{Queue}} : ( $QueueGetResult->{Data}->{Queue} );

        if ( IsArrayRefWithData(\@QueueDataList) ) {
            return $Self->_Success(
                Queue => \@QueueDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Queue => [],
    );
}

1;