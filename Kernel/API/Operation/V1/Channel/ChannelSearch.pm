# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
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
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Channel::ChannelGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ChannelID => join(',', sort keys %ChannelList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Channel} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Channel}) ? @{$GetResult->{Data}->{Channel}} : ( $GetResult->{Data}->{Channel} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Channel => \@ResultList,
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
