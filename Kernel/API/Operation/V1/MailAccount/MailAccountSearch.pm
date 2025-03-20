# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::MailAccount::MailAccountSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::MailAccount::MailAccountGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::MailAccount::MailAccountSearch - API MailAccount Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform MailAccountSearch Operation. This will return a MailAccount list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            MailAccount => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform MailAccount search
    my %MailAccountList = $Kernel::OM->Get('MailAccount')->MailAccountList();

    # get already prepared MailAccount data from MailAccountGet operation
    if ( IsHashRefWithData( \%MailAccountList ) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::MailAccount::MailAccountGet',
            SuppressPermissionErrors => 1,
            Data          => {
                MailAccountID => join( ',', sort keys %MailAccountList ),
                }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{MailAccount} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{MailAccount}) ? @{$GetResult->{Data}->{MailAccount}} : ( $GetResult->{Data}->{MailAccount} );
        }

        if ( IsArrayRefWithData( \@ResultList ) ) {
            return $Self->_Success(
                MailAccount => \@ResultList,
            );
        }
    }

    # return result
    return $Self->_Success(
        MailAccount => [],
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
