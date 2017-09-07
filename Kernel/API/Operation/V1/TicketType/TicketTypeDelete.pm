# --
# Kernel/API/Operation/TicketType/TicketTypeDelete.pm - API TicketType Delete operation backend
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

package Kernel::API::Operation::V1::TicketType::TicketTypeDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use Kernel::System::Ticket::TicketSearch;

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketType::TicketypeDelete - GenericInterface TicketType TicketTypeDelete Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketTypeDelete');

    return $Self;
}

=item TicketTypeDelete()

delete a Tickettype

    my $ID = $TicketTypeObject->TypeDelete(
        TypeID    => 'New TicketType',
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'TicketType' => {
                Type     => 'ARRAY',
                Required => 1
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->ReturnError(
            ErrorCode    => 'TicketTypeCreate.PrepareDataError',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    my $ErrorMessage = '';
    my @TicketTypeList;

    # start type loop
    TYPE:    
    foreach my $TicketTypeID ( @{$Param{Data}->{TicketTypeID}} ) {
         	
	    # check if tickettype exists
	    my $TicketTypeData = $Kernel::OM->Get('Kernel::System::Type')->TypeLookup(
	        TypeID => $TicketTypeID,
	    );
	  
	    if ( !$TicketTypeData ) {
	    	$ErrorMessage = 'Could not exist TicketType $TicketTypeID'
	            . ' in Kernel::API::Operation::V1::TicketType::TicketTypeDelete::Run()';
	
	        return $Self->ReturnError(
	            ErrorCode    => 'TicketTypeDelete.NotTypeLookup',
	            ErrorMessage => "TicketTypeDelete: $ErrorMessage",
	        );
	    }
	           
	    my $ResultTicketSearch = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
	        Result => 'COUNT',
	        TypeIDs => [$TicketTypeID],
	        UserID => $Param{Data}->{Authorization}->{UserID},
	    );
	    
	    if ( $ResultTicketSearch ) {
	    	$ErrorMessage = 'Ticket with TicketType $TicketTypeID exist'
	            . ' in Kernel::API::Operation::V1::TicketType::TicketTypeDelete::Run()';
	
	        return $Self->ReturnError(
	            ErrorCode    => 'TicketTypeDelete.NotTicketSearch',
	            ErrorMessage => "TicketTypeDelete: $ErrorMessage",
	    } 

	    my $Success = $Kernel::OM->Get('Kernel::System::Type')->TypeDelete(
	        TypeID  => $TicketTypeID,
	        ValidID => 1,
	        UserID  => $Param{Data}->{Authorization}->{UserID},
	    );

	    if ( !$Success ) {
	        $ErrorMessage = 'Could not delete TicketType $TicketTypeID'
	            . ' in Kernel::API::Operation::V1::TicketType::TicketTypeGet::Run()';
	
	        return $Self->ReturnError(
	            ErrorCode    => 'TicketTypeDelete.NotTypeDelete',
	            ErrorMessage => "TicketTypeDelete: $ErrorMessage",
	        );
	    }
	    else {
	        push(@TicketTypeList, $TicketTypeID);	    	
	    }
    }

    if ( scalar(@TicketTypeList) == 1 ) {
        return $Self->ReturnSuccess(
            TicketType => $TicketTypeList[0],
        );    
    }

    return $Self->ReturnSuccess(
        TicketType => \@TicketTypeList,
    );
}