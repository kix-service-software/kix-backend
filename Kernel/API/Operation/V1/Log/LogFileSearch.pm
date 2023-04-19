# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Log::LogFileSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Log::LogFileSearch - API LogFile Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform LogFileSearch Operation. This will return a LogFile ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            LogFile => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform LogFile search
    my %LogFileList = $Kernel::OM->Get('LogFile')->LogFileList();

	# get already prepared LogFile data from LogFileGet operation
    if ( IsHashRefWithData(\%LogFileList) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Log::LogFileGet',
            SuppressPermissionErrors => 1,
            Data      => {
                LogFileID => join(',', sort keys %LogFileList),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{LogFile} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{LogFile}) ? @{$GetResult->{Data}->{LogFile}} : ( $GetResult->{Data}->{LogFile} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                LogFile => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        LogFile => [],
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
