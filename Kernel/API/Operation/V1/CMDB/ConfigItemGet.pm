# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemGet - API ConfigItemGet Operation backend

=head1 SYNOPSIS

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
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item PreRun()

some code to run before actual execution

    my $Success = $CommonObject->PreRun(
        ...
    );

    returns:

    $Success = {
        Success => 1,                     # if everything is OK
    }

    $Success = {
        Code    => 'Forbidden',           # if error
        Message => 'Error description',
    }

=cut

sub PreRun {
    my ( $Self, %Param ) = @_;

    # filter config item ids for customer
    if ($Param{Data}->{ConfigItemID}) {
        my @ConfigItemIDs = $Self->_FilterCustomerUserVisibleObjectIds(
            ObjectType             => 'ConfigItem',
            ObjectIDList           => $Param{Data}->{ConfigItemID},
            RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID},
            LogFiltered => 1
        );
        if (@ConfigItemIDs) {
            $Param{Data}->{ConfigItemID} = \@ConfigItemIDs;
        } else {
            return $Self->_Error(
                Code => 'Forbidden',
                Message => @{$Param{Data}->{ConfigItemID}} == 1 ?
                "Could not access ConfigItem with id $Param{Data}->{ConfigItemID}->[0]" :
                "Could not access any ConfigItem"
            );
        }
    }

    return $Self->_Success();
}

=item Run()

perform ConfigItemGet Operation.

    my $Result = $OperationObject->Run(
        ConfigItemID => 1,                                # required
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            ConfigItem => [
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ConfigItemList;
    foreach my $ConfigItemID ( @{$Param{Data}->{ConfigItemID}} ) {

        my $ConfigItem = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemGet(
            ConfigItemID => $ConfigItemID,
        );

        if (!IsHashRefWithData($ConfigItem)) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # include CurrentVersion if requested
        if ( $Param{Data}->{include}->{CurrentVersion} ) {
            # get already prepared data of current version from VersionSearch operation
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::CMDB::ConfigItemVersionGet',
                Data          => {
                    ConfigItemID  => $ConfigItemID,
                    VersionID     => $ConfigItem->{LastVersionID},
                }
            );

            if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                $ConfigItem->{CurrentVersion} = $Result->{Data}->{ConfigItemVersion};
            }
        }

        # add link count
        if ( $Param{Data}->{include}->{LinkCount} ) {
            $ConfigItem->{LinkCount} = 0 + $Kernel::OM->Get('LinkObject')->LinkCount(
                Object => 'ConfigItem',
                Key    => $ConfigItemID
            );
        }

        push(@ConfigItemList, $ConfigItem);
    }

    if ( scalar(@ConfigItemList) == 0 ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }
    elsif ( scalar(@ConfigItemList) == 1 ) {
        return $Self->_Success(
            ConfigItem => $ConfigItemList[0],
        );
    }

    return $Self->_Success(
        ConfigItem => \@ConfigItemList,
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
