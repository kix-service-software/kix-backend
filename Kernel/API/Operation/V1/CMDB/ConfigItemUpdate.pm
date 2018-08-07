# --
# Kernel/API/Operation/ConfigItem/ConfigItemUpdate.pm - API ConfigItem Create operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

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

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

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
    my $ConfigItem = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemGet(
        ConfigItemID => $Param{Data}->{ConfigItemID}
    );

    # check if ConfigItem exists
    if ( !$ConfigItem ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Could not get data for ConfigItem $Param{Data}->{ConfigItemID}",
        );
    }

    # check create permissions
    my $Permission = $Self->CheckCreatePermission(
        ConfigItem => $ConfigItem,
        UserID     => $Self->{Authorization}->{UserID},
        UserType   => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to update ConfigItems for this class!",
        );
    }

    # isolate and trim ConfigItem parameter
    my $ConfigItem = $Self->_Trim(
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
    my $ConfigItemID = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemUpdate(        
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
        ConfigItemID => $Param{Data}->{ConfigItemID},
    );
}

1;
