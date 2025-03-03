# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ObjectIcon::ObjectIconSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::ObjectIcon::ObjectIconGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::ObjectIcon::ObjectIconSearch - API ObjectIcon Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform ObjectIconSearch Operation. This will return a ObjectIcon list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                           # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ObjectIcon => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform ObjectIcon search
    my $ObjectIconList = $Kernel::OM->Get('ObjectIcon')->ObjectIconList();

	# get already prepared ObjectIcon data from ObjectIconGet operation
    if ( IsArrayRefWithData($ObjectIconList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::ObjectIcon::ObjectIconGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ObjectIconID => join(',', sort @{$ObjectIconList}),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ObjectIcon} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ObjectIcon}) ? @{$GetResult->{Data}->{ObjectIcon}} : ( $GetResult->{Data}->{ObjectIcon} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ObjectIcon => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ObjectIcon => [],
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
