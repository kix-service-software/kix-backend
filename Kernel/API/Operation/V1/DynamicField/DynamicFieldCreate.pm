# --
# Kernel/API/Operation/DynamicField/DynamicFieldCreate.pm - API DynamicField Create operation backend
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

package Kernel::API::Operation::V1::DynamicField::DynamicFieldCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::DynamicField::DynamicFieldCreate - API DynamicField Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::DynamicFieldCreate');

    return $Self;
}

=item Run()

perform DynamicFieldCreate Operation. This will return the created DynamicFieldID.

    my $Result = $OperationObject->Run(
        Data => {
            DynamicFieldID => 123,
            DynamicField   => {
	            Name            => '...',            
	            Label           => '...',            
                FieldType       => '...',            
                DisplayGroupID  => 123,              
                ObjectType      => '...',            
                Config          => { }
	            InternalField   => 0|1,              # optional
	            ValidID         => 1,                # optional
            }
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            DynamicFieldID  => 123,             # ID of the Created DynamicField 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    my $GeneralCatalogItemList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'DynamicField::DisplayGroup',
    );
    my @DisplayGroupIDs;
    if ( IsHashRefWithData($GeneralCatalogItemList) ) {
       @DisplayGroupIDs = sort keys %{$GeneralCatalogItemList};
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data         => $Param{Data},
        Parameters   => {
            'DynamicField' => {
                Type => 'HASH',
                Required => 1
            },
            'DynamicField::Name' => {
                Required => 1
            },
            'DynamicField::Label' => {
                Required => 1
            },
            'DynamicField::FieldType' => {
                Required => 1
            },
            'DynamicField::DisplayGroupID' => {
                RequiresValueIfUsed => 1,
                OneOf => \@DisplayGroupIDs
            },
            'DynamicField::ObjectType' => {
                Required => 1
            },
            'DynamicField::Config' => {
                Type => 'HASH',
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

    # isolate and trim DynamicField parameter
    my $DynamicField = $Self->_Trim(
        Data => $Param{Data}->{DynamicField}
    );

    # check attribute values
    my $CheckResult = $Self->_CheckDynamicField( 
        DynamicField => $DynamicField
    );

    if ( !$CheckResult->{Success} ) {
        return $Self->_Error(
            %{$CheckResult},
        );
    }

    # check if name is duplicated
    my %DynamicFieldsList = %{
        $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldList(
            Valid      => 0,
            ResultType => 'HASH',
        )
    };

    %DynamicFieldsList = reverse %DynamicFieldsList;

    if ( $DynamicFieldsList{ $DynamicField->{Name} } ) {

        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Can not create DynamicField. Another DynamicField with same name already exists.',
        );
    }

    # create DynamicField
    my $ID = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldAdd(
        Name            => $DynamicField->{Name},
        Label           => $DynamicField->{Label},
        InternalField   => $DynamicField->{InternalField} || 0,
        FieldType       => $DynamicField->{FieldType},
        DisplayGroupID  => $DynamicField->{DisplayGroupID},
        ObjectType      => $DynamicField->{ObjectType},
        Config          => $DynamicField->{Config},
        ValidID         => $DynamicField->{ValidID} || 1,
        UserID          => $Self->{Authorization}->{UserID},
    );

    if ( !$ID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create DynamicField, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        DynamicFieldID => $ID,
    );    
}

