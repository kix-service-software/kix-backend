# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SenderType::SenderTypeSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::SenderType::SenderTypeGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SenderType::SenderTypeSearch - API SenderType Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform SenderTypeSearch Operation. This will return a SenderType ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SenderType => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform SenderType search
    my %SenderTypeList = $Kernel::OM->Get('Ticket')->ArticleSenderTypeList(
        Result => 'HASH',
    );

	# get already prepared SenderType data from SenderTypeGet operation
    if ( IsHashRefWithData(\%SenderTypeList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::SenderType::SenderTypeGet',
            SuppressPermissionErrors => 1,
            Data      => {
                SenderTypeID => join(',', sort keys %SenderTypeList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{SenderType} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{SenderType}) ? @{$GetResult->{Data}->{SenderType}} : ( $GetResult->{Data}->{SenderType} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                SenderType => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SenderType => [],
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
