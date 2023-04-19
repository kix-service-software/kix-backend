# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Lock::LockSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Lock::LockGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Lock::LockSearch - API Lock Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform LockSearch Operation. This will return a Lock ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Lock => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Lock search
    my %LockList = $Kernel::OM->Get('Lock')->LockList(
        UserID => $Self->{Authorization}->{UserID},
    );

	# get already prepared Lock data from LockGet operation
    if ( IsHashRefWithData(\%LockList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Lock::LockGet',
            SuppressPermissionErrors => 1,
            Data      => {
                LockID => join(',', sort keys %LockList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Lock} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Lock}) ? @{$GetResult->{Data}->{Lock}} : ( $GetResult->{Data}->{Lock} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Lock => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Lock => [],
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
