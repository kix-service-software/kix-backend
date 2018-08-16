# --
# Kernel/API/Operation/CMDB/CMDBCreate.pm - API CMDB Create operation backend
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

package Kernel::API::Operation::V1::CMDB::ConfigItemImageSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::CMDB::ConfigItemImageSearch - API CMDB Search Operation backend

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
    for my $Needed (qw(DebuggerObject WebserviceID)) {
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
            DataType => 'NUMERIC',
            Required => 1
        },
    }
}

=item Run()

perform ConfigItemImageSearch Operation.

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
            Image => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check if ConfigItem exists
    my $ConfigItem = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemGet(
        ConfigItemID => $Param{Data}->{ConfigItemID},
    );

    if (!IsHashRefWithData($ConfigItem)) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Could not get data for ConfigItemID $Param{Data}->{ConfigItemID}",
        );
    }
    
    # get ConfigItem versions
    my $ImageList = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ImageList(
        ConfigItemID => $Param{Data}->{ConfigItemID},
        UserID       => $Self->{Authorization}->{UserID},
    );

	# get already prepared CI version data from ConfigItemImageGet operation
    if ( IsArrayRefWithData($ImageList) ) {  	

        my $GetResult = $Self->ExecOperation(
            OperationType => 'V1::CMDB::ConfigItemImageGet',
            Data      => {
                ConfigItemID => $Param{Data}->{ConfigItemID},
                ImageID    => join(',', sort @{$ImageList}),
            }
        );    

        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @DataList = IsArrayRefWithData($GetResult->{Data}->{Image}) ? @{$GetResult->{Data}->{Image}} : ( $GetResult->{Data}->{ConfigItemVersion} );

        if ( IsArrayRefWithData(\@DataList) ) {
            return $Self->_Success(
                Image => \@DataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Image => [],
    );
}

1;