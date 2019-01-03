# --
# Kernel/API/Operation/GeneralCatalog/GeneralCatalogItemCreate.pm - API GeneralCatalogItem Create operation backend
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

package Kernel::API::Operation::V1::CMDB::ClassCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ClassCreate - API Class Create Operation backend

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
        'ConfigItemClass' => {
            Type     => 'HASH',
            Required => 1
        },
        'ConfigItemClass::Name' => {
            Required => 1
        },                             
    }
}

=item Run()

perform ClassCreate Operation. This will return the created ClassID.

    my $Result = $OperationObject->Run(
        Data => {
            ConfigItemClass  => {                
                Name    => 'class name',
                ValidID => 1,
                Comment => 'Comment',              # (optional)
            },
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      # 
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            ConfigItemClassID  => '',       # ID of the created ConfigItemClassID
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim ConfigItemClass parameter
    my $ConfigItemClass = $Self->_Trim(
        Data => $Param{Data}->{ConfigItemClass}
    );

    my $ItemList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'ITSM::ConfigItem::Class',
    );

    foreach my $Item ( keys %$ItemList ) {
    	if ( $ItemList->{$Item} eq $ConfigItemClass->{Name} ) {
	        return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Cannot create class. A class with the same name '$ConfigItemClass->{Name}' already exists.",
	        );    		
    	}
    }

    # create class
    my $GeneralCatalogItemID = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemAdd(
        Class    => 'ITSM::ConfigItem::Class',
        Name     => $ConfigItemClass->{Name},
        Comment  => $ConfigItemClass->{Comment} || '',
        ValidID  => $ConfigItemClass->{ValidID} || 1,
        UserID   => $Self->{Authorization}->{UserID},              
    );

    if ( !$GeneralCatalogItemID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create class, please contact the system administrator',
        );
    }
    
    if ( $ConfigItemClass->{DefinitionString} ) {
        my $Result = $Self->ExecOperation(
            OperationType => 'V1::CMDB::ClassDefinitionCreate',
            Data          => {
                ClassID                   => $GeneralCatalogItemID,
                ConfigItemClassDefinition => {
                    DefinitionString => $ConfigItemClass->{DefinitionString}
                }
            }
        );
        
        if ( !$Result->{Success} ) {
            return $Self->_Error(
                ${$Result},
            )
        }
    }

    # return result    
    return $Self->_Success(
        Code              => 'Object.Created',
        ConfigItemClassID => $GeneralCatalogItemID,
    );    
}


1;
