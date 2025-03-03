# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Console::ConsoleCommandSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Console::ConsoleCommandSearch - API ConsoleCommand Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ConsoleCommandSearch Operation. This will return a ConsoleCommand list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ConsoleCommand => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get command list
    my @CommandList = $Kernel::OM->Get('Console')->CommandList();

	# get already prepared Command data from CommandGet operation
    if ( IsArrayRefWithData(\@CommandList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Console::ConsoleCommandGet',
            SuppressPermissionErrors => 1,
            Data      => {
                Command => join(',', sort @CommandList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ConsoleCommand} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ConsoleCommand}) ? @{$GetResult->{Data}->{ConsoleCommand}} : ( $GetResult->{Data}->{ConsoleCommand} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ConsoleCommand => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ConsoleCommand => [],
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
