# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Migration::MigrationSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Migration::MigrationSearch - API Migration Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform MigrationSearch Operation. This will return a Migration ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data         => {
            Migration => [
                {
                },
                {
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @MigrationList = $Kernel::OM->Get('Installation')->MigrationList();

    if (IsArrayRefWithData(\@MigrationList)) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Migration::MigrationGet',
            SuppressPermissionErrors => 1,
            Data      => {
                MigrationID => join(',', map { $_->{ID} } @MigrationList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Migration} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Migration}) ? @{$GetResult->{Data}->{Migration}} : ( $GetResult->{Data}->{Migration} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Migration => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Migration => [],
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
