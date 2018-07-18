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

package Kernel::API::Operation::V1::CMDB::ClassDefinitionSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::CMDB::ClassDefinitionSearch - API CMDB Search Operation backend

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

=item Run()

perform ClassDefinitionSearch Operation. This will return a class list.

    my $Result = $OperationObject->Run(
        Data => {
            ClassID => 123                      # required
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ConfigItemClassDefinition => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'ClassID' => {
                DataType => 'NUMERIC',
                Required => 1
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # check if ClassID exists in GeneralCatalog
    my $ItemData = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemGet(
        ItemID  => $Param{Data}->{ClassID},
    );

use Data::Dumper;
print STDERR Dumper($ItemData);

    if (!IsHashRefWithData($ItemData) || $ItemData->{Class} ne 'ITSM::ConfigItem::Class') {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Could not get data for ClassID $Param{Data}->{ClassID}",
        );
    }

    # get definitions for given class
    my $DefinitionList = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->DefinitionList(
        ClassID => $Param{Data}->{ClassID}
    );

	# get already prepared definition data from ClassDefinitionGet operation
    if ( IsArrayRefWithData($DefinitionList) ) {  	
        # prepare ID list
        my @DefinitionIDs;
        foreach my $Definition (@{$DefinitionList}) {
            push(@DefinitionIDs, $Definition->{DefinitionID});
        }

        my $GetResult = $Self->ExecOperation(
            OperationType => 'V1::CMDB::ClassDefinitionGet',
            Data      => {
                ClassID      => $Param{Data}->{ClassID},
                DefinitionID => join(',', sort @DefinitionIDs),
            }
        );    

        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ClassDataList = IsArrayRefWithData($GetResult->{Data}->{ConfigItemClassDefinition}) ? @{$GetResult->{Data}->{ConfigItemClassDefinition}} : ( $GetResult->{Data}->{ConfigItemClassDefinition} );

        if ( IsArrayRefWithData(\@ClassDataList) ) {
            return $Self->_Success(
                ConfigItemClassDefinition => \@ClassDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ConfigItemClass => [],
    );
}

1;