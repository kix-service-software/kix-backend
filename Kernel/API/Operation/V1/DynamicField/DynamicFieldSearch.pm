# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::DynamicField::DynamicFieldSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::DynamicField::DynamicFieldGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::DynamicField::DynamicFieldSearch - API DynamicField Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform DynamicFieldSearch Operation. This will return a DynamicField ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            DynamicField => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform DynamicField search
    my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldList(Valid => 0);

	# get already prepared DynamicField data from DynamicFieldGet operation
    if ( IsArrayRefWithData($DynamicFieldList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::DynamicField::DynamicFieldGet',
            SuppressPermissionErrors => 1,
            Data      => {
                DynamicFieldID => join(',', sort @{$DynamicFieldList}),
                include        => $Param{Data}->{include},
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{DynamicField} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{DynamicField}) ? @{$GetResult->{Data}->{DynamicField}} : ( $GetResult->{Data}->{DynamicField} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                DynamicField => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        DynamicField => [],
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
