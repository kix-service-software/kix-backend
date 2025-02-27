# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemUpdate - API ConfigItem Update Operation backend

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
            Required => 1,
        },
        'ConfigItem' => {
            Required => 1,
            Type     => 'HASH'
        },
    }
}

=item Run()

perform ConfigItemUpdate Operation. This will return the created ConfigItemLogin.

    my $Result = $OperationObject->Run(
        Data => {
            ConfigItem => {
                ...
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ConfigItemID  => '',                    # ConfigItemID
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get config item data
    my $ConfigItem = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemGet(
        ConfigItemID => $Param{Data}->{ConfigItemID}
    );

    # check if ConfigItem exists
    if ( !$ConfigItem ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # isolate and trim ConfigItem parameter
    $ConfigItem = $Self->_Trim(
        Data => $Param{Data}->{ConfigItem}
    );

    # check ConfigItem attribute values
    my $ConfigItemCheck = $Self->_CheckConfigItem(
        ConfigItem => $ConfigItem
    );

    if ( !$ConfigItemCheck->{Success} ) {
        return $Self->_Error(
            %{$ConfigItemCheck},
        );
    }

    # update config item
    my $ConfigItemID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemUpdate(
        ConfigItemID   => $Param{Data}->{ConfigItemID},
        %{$ConfigItem},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$ConfigItemID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Configuration Item could not be updated, please contact the system administrator',
        );
    }

    return $Self->_Success(
        ConfigItemID => 0 + $Param{Data}->{ConfigItemID},
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
