# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::JobTypeSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Automation::JobTypeSearch - API Automation Job Type Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform JobTypeSearch Operation. This will return a list job types.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            JobType => [
                ...
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get job types
    my $JobTypes = $Kernel::OM->Get('Config')->Get('Automation::JobType');

    if ( IsHashRefWithData($JobTypes) ) {
        my @JobTypeList;
        foreach my $Key ( sort keys %{$JobTypes} ) {
            push @JobTypeList, { Name => $Key, DisplayName => $JobTypes->{$Key}->{DisplayName} };
        }
        return $Self->_Success(
            JobType => \@JobTypeList,
        )
    }

    # return result
    return $Self->_Success(
        JobType => [],
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
