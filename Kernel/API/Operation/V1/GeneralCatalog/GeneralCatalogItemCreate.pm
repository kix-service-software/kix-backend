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

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemCreate - API GeneralCatalogItem Create Operation backend

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
        'GeneralCatalogItem' => {
            Type     => 'HASH',
            Required => 1
        },
        'GeneralCatalogItem::Class' => {
            Required => 1
        },
        'GeneralCatalogItem::Name' => {
            Required => 1
        },                             
    }
}

=item Run()

perform GeneralCatalogItemCreate Operation. This will return the created GeneralCatalogItemItemID.

    my $Result = $OperationObject->Run(
        Data => {
            GeneralCatalogItem  => {                
                Class   => 'ITSM::Service::Type',
                Name    => 'Item Name',
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
            GeneralCatalogItemID  => '',    # ID of the created GeneralCatalogItem
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim GeneralCatalogItem parameter
    my $GeneralCatalogItem = $Self->_Trim(
        Data => $Param{Data}->{GeneralCatalogItem}
    );

    my $ItemList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => $GeneralCatalogItem->{Class},
    );

    foreach my $Item ( keys %$ItemList ) {
    	if ( $ItemList->{$Item} eq $GeneralCatalogItem->{Name} ) {
	        return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Can not create GeneralCatalog item. GeneralCatalog item with same name '$GeneralCatalogItem->{Name}' already exists.",
	        );    		
    	}
    }

    # create GeneralCatalog
    my $GeneralCatalogItemID = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemAdd(
        Class    => $GeneralCatalogItem->{Class},
        Name     => $GeneralCatalogItem->{Name},
        Comment  => $GeneralCatalogItem->{Comment} || '',
        ValidID  => $GeneralCatalogItem->{ValidID} || 1,
        UserID   => $Self->{Authorization}->{UserID},              
    );

    if ( !$GeneralCatalogItemID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create GeneralCatalog item, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        GeneralCatalogItemID => $GeneralCatalogItemID,
    );    
}


1;
