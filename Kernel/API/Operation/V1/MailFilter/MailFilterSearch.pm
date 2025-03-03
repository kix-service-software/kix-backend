# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::MailFilter::MailFilterSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::MailFilter::MailFilterGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::API::Operation::V1::Common);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::MailFilter::MailFilterSearch - API MailFilter Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform MailFilterSearch Operation. This will return a MailFilter list.

    my $Result = $OperationObject->Run(
        Data => { }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            MailFilter => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform MailFilter search
    my %MailFilterList = $Kernel::OM->Get('PostMaster::Filter')->FilterList();

    # get already prepared MailFilter data from MailFilterGet operation
    if ( IsHashRefWithData( \%MailFilterList ) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::MailFilter::MailFilterGet',
            SuppressPermissionErrors => 1,
            Data          => {
                MailFilterID => join( ',', sort keys %MailFilterList )
                }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{MailFilter} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{MailFilter}) ? @{$GetResult->{Data}->{MailFilter}} : ( $GetResult->{Data}->{MailFilter} );
        }

        if ( IsArrayRefWithData( \@ResultList ) ) {
            return $Self->_Success(
                MailFilter => \@ResultList,
            );
        }
    }

    # return result
    return $Self->_Success(
        MailFilter => [],
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
