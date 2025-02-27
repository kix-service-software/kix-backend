# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemHistorySearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::CMDB::ConfigItemHistorySearch - API CMDB Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'ConfigItemID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform ConfigItemHistorySearch Operation.

    my $Result = $OperationObject->Run(
        Data => {
            ConfigItemID => 1                   # required
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ConfigItemHistory => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if ConfigItem exists
    my $Exist = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
        ConfigItemID => $Param{Data}->{ConfigItemID},
    );

    if (!$Exist) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # get ConfigItem history
    my $HistoryList = $Kernel::OM->Get('ITSMConfigItem')->HistoryGet(
        ConfigItemID => $Param{Data}->{ConfigItemID},
        UserID       => $Self->{Authorization}->{UserID},
    );

	# get already prepared CI history data from ConfigItemHistoryGet operation
    if ( IsArrayRefWithData($HistoryList) ) {

        # prepare ID list
        my @HistoryIDs;
        foreach my $History (@{$HistoryList}) {
            push(@HistoryIDs, $History->{HistoryEntryID});
        }

        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::CMDB::ConfigItemHistoryGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ConfigItemID => $Param{Data}->{ConfigItemID},
                HistoryID    => join(',', sort @HistoryIDs),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ConfigItemHistory} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ConfigItemHistory}) ? @{$GetResult->{Data}->{ConfigItemHistory}} : ( $GetResult->{Data}->{ConfigItemHistory} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ConfigItemHistory => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ConfigItemHistory => [],
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
