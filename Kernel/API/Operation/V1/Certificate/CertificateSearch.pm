# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Certificate::CertificateSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Certificate::CertificateSearch - API Certificate Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->SUPER::Init(%Param);

    $Self->{HandleSortInCORE} = 1;

    return $Result;
}

=item Run()

perform ChannelSearch Operation. This will return a Certificate list.

    my $Result = $OperationObject->Run(
        Data => {}
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Certificate => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Certificate search
    my @CertificateList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Certificate',
        UserID     => $Self->{Authorization}->{UserID},
        UserType   => $Self->{Authorization}->{UserType},
        Result     => 'ARRAY',
        Search     => $Self->{Search}->{Certificate},
        Limit      => $Self->{SearchLimit}->{Certificate} || $Self->{SearchLimit}->{'__COMMON'},
        Sort       => $Self->{Sort}->{Certificate},
    );

	# get already prepared Certificate data from CertificateGet operation
    if ( scalar(@CertificateList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Certificate::CertificateGet',
            SuppressPermissionErrors => 1,
            Data                     => {
                CertificateID => join(q{,}, @CertificateList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Certificate} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Certificate})
                ? @{$GetResult->{Data}->{Certificate}}
                : ( $GetResult->{Data}->{Certificate} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Certificate => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Certificate => [],
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
