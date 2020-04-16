# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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
    my %ChannelList = $Kernel::OM->Get('Channel')->ChannelList();

	# get already prepared Channel data from ChannelGet operation
    if ( IsHashRefWithData(\%ChannelList) ) {  	
        my $ChannelGetResult = $Self->ExecOperation(
            OperationType            => 'V1::Channel::ChannelGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ChannelID => join(',', sort keys %ChannelList),
            }
        );    

        if ( !IsHashRefWithData($ChannelGetResult) || !$ChannelGetResult->{Success} ) {
            return $ChannelGetResult;
        }

        my @ChannelDataList = IsArrayRef($ChannelGetResult->{Data}->{Channel}) ? @{$ChannelGetResult->{Data}->{Channel}} : ( $ChannelGetResult->{Data}->{Channel} );

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
=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
