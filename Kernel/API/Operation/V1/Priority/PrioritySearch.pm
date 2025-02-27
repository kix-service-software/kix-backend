# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Priority::PrioritySearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Priority::PriorityGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Priority::PrioritySearch - API Priority Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform PrioritySearch Operation. This will return a Priority ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data         => {
            Priority => [
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

    # perform Priority search
    my %PriorityList = $Kernel::OM->Get('Priority')->PriorityList(
        Valid => 0
    );

    if (IsHashRefWithData(\%PriorityList)) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Priority::PriorityGet',
            SuppressPermissionErrors => 1,
            Data      => {
                PriorityID => join(',', sort keys %PriorityList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Priority} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Priority}) ? @{$GetResult->{Data}->{Priority}} : ( $GetResult->{Data}->{Priority} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Priority => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Priority => [],
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
