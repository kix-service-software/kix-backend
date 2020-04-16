# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemVersionSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::CMDB::ConfigItemVersionSearch - API CMDB Search Operation backend

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

perform ConfigItemVersionSearch Operation.

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
            ConfigItemVersion => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # if necessary check if config item is accessible for current customer user
    my $CustomerCheck = $Self->_CheckCustomerAssignedConfigItem(
        ConfigItemIDList => $Param{Data}->{ConfigItemID}
    );
    if ( !$CustomerCheck->{Success} ) {
        return $Self->_Error(
            %{$CustomerCheck},
        );
    }

    # check if ConfigItem exists
    my $ConfigItem = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemGet(
        ConfigItemID => $Param{Data}->{ConfigItemID},
    );

    if (!IsHashRefWithData($ConfigItem)) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }
    
    # get ConfigItem versions
    my $VersionList = $Kernel::OM->Get('ITSMConfigItem')->VersionList(
        ConfigItemID => $Param{Data}->{ConfigItemID},
        UserID       => $Self->{Authorization}->{UserID},
    );

	# get already prepared CI version data from ConfigItemVersionGet operation
    if ( IsArrayRefWithData($VersionList) ) {  	

        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::CMDB::ConfigItemVersionGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ConfigItemID => $Param{Data}->{ConfigItemID},
                VersionID    => join(',', sort @{$VersionList}),
            }
        );    

        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @DataList = IsArrayRef($GetResult->{Data}->{ConfigItemVersion}) ? @{$GetResult->{Data}->{ConfigItemVersion}} : ( $GetResult->{Data}->{ConfigItemVersion} );

        if ( IsArrayRefWithData(\@DataList) ) {
            return $Self->_Success(
                ConfigItemVersion => \@DataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ConfigItemVersion => [],
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
