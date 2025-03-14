# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectTag::ObjectTagLinkSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::ObjectTag::ObjectTagLinkSearch - API ObjectTagLink Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ObjectTagLinkSearch Operation. This will return a ObjectTagLink list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ObjectTagLink => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ObjectTagIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'ObjectTagLink',
        Search     => $Self->{Search}->{ObjectTagLink},
        UserID     => $Self->{Authorization}->{UserID},
        UserType   => $Self->{Authorization}->{UserType},
        Limit      => $Self->{SearchLimit}->{ObjectTagLink} || $Self->{ObjectTagLink}->{'__COMMON'},
        Sort       => $Self->{Sort}->{ObjectTagLink},
        Result     => 'ARRAY'
    );

    # get already prepared object tag data from ObjectTagGet operation
    if ( scalar(@ObjectTagIDs) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::ObjectTag::ObjectTagGet',
            SuppressPermissionErrors => 1,
            Data                     => {
                ObjectTagID => join(q{,}, @ObjectTagIDs),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ObjectTag} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ObjectTag})
                ? @{$GetResult->{Data}->{ObjectTag}}
                : ( $GetResult->{Data}->{ObjectTag} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ObjectTagLink => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ObjectTagLink => [],
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
