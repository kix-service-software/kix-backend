# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::GeneralCatalog::GeneralCatalogItemDelete - API GeneralCatalog GeneralCatalogItemDelete Operation backend

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
        'GeneralCatalogItemID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform GeneralCatalogItemDelete Operation. This will return {}.

    my $Result = $OperationObject->Run(
        Data => {
            GeneralCatalogItemID  => '...',
        },		
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    
    # start loop
    foreach my $GeneralCatalogItemID ( @{$Param{Data}->{GeneralCatalogItemID}} ) {

        my $ConfigItemID = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemSearch(
            ClassIDs     => [$GeneralCatalogItemID],
        );
	    
        if ( $ConfigItemID->[0] ) {
            return $Self->_Error(
                Code    => 'Object.DependingObjectExists',
                Message => 'Can not delete GeneralCatalogItem. A ConfigItem with this GeneralCatalogItem already exists.',
            );
        } 

        my $ServiceList = $Kernel::OM->Get('Kernel::System::Service')->ServiceSearch(
            TypeIDs => [$GeneralCatalogItemID],
            UserID  => $Self->{Authorization}->{UserID},
        );
	    
        if ( $ServiceList) {
            return $Self->_Error(
                Code    => 'Object.DependingObjectExists',
                Message => 'Can not delete GeneralCatalogItem. A Service with this GeneralCatalogItem already exists.',
            );
        }
         	    
        my %SLAList = $Kernel::OM->Get('Kernel::System::SLA')->SLAList(
            Valid     => 1,  
            UserID  => $Self->{Authorization}->{UserID},
        );
                  
        foreach my $ID (keys %SLAList) {
	        my %SLAData = $Kernel::OM->Get('Kernel::System::SLA')->SLAGet(
	            SLAID => $ID,
	            UserID  => $Self->{Authorization}->{UserID},
	        );
	                	    	
            if ( $SLAData{TypeID} == $GeneralCatalogItemID) {

                return $Self->_Error(
                    Code    => 'Object.DependingObjectExists',
                    Message => 'Can not delete GeneralCatalogItem. A SLA with this GeneralCatalogItem already exists.',
                );
            }    	
        }
   
        # delete GeneralCatalog	    
        my $Success = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->GeneralCatalogItemDelete(
            GeneralCatalogItemID  => $GeneralCatalogItemID,
            UserID  => $Self->{Authorization}->{UserID},
        );
 
        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete GeneralCatalogItem, please contact the system administrator',
            );
        }
    }

    # return result
    return $Self->_Success();
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
