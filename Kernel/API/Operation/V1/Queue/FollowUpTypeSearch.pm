# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Queue::FollowUpTypeSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Queue::FollowUpTypeSearch - API FollowUp Type Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform FollowUpTypeSearch Operation. This will return a FollowUpType list.

    my $Result = $OperationObject->Run(
        Data => {
            RoleID => 123
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            FollowUpType => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform search
    my %FollowUpTypeList = $Kernel::OM->Get('Queue')->FollowUpTypeList();

	# get prepare
    if ( IsHashRefWithData(\%FollowUpTypeList) ) {

        my @Result;
        foreach my $TypeID ( sort keys %FollowUpTypeList ) {
            my %TypeData = $Kernel::OM->Get('Queue')->FollowUpTypeGet(
                ID => $TypeID,
            );

            push(@Result, \%TypeData);
        }

        return $Self->_Success(
            FollowUpType => \@Result,
        )
    }

    # return result
    return $Self->_Success(
        FollowUpType => [],
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
