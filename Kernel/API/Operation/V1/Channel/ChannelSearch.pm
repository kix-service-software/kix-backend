# --
# Kernel/API/Operation/Channel/ChannelCreate.pm - API Channel Create operation backend
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

package Kernel::API::Operation::V1::Channel::ChannelSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Channel::ChannelSearch - API Channel Search Operation backend

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

perform ChannelSearch Operation. This will return a Channel ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Channel => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Channel search
    my %ChannelList = $Kernel::OM->Get('Kernel::System::Channel')->ChannelList();

	# get already prepared Channel data from ChannelGet operation
    if ( IsHashRefWithData(\%ChannelList) ) {  	
        my $ChannelGetResult = $Self->ExecOperation(
            OperationType => 'V1::Channel::ChannelGet',
            Data      => {
                ChannelID => join(',', sort keys %ChannelList),
            }
        );    

        if ( !IsHashRefWithData($ChannelGetResult) || !$ChannelGetResult->{Success} ) {
            return $ChannelGetResult;
        }

        my @ChannelDataList = IsArrayRefWithData($ChannelGetResult->{Data}->{Channel}) ? @{$ChannelGetResult->{Data}->{Channel}} : ( $ChannelGetResult->{Data}->{Channel} );

        if ( IsArrayRefWithData(\@ChannelDataList) ) {
            return $Self->_Success(
                Channel => \@ChannelDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Channel => [],
    );
}

1;