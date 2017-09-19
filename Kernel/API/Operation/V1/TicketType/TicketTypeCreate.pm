# --
# Kernel/API/Operation/TicketType/TicketTypeCreate.pm - API TicketType Create operation backend
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

package Kernel::API::Operation::V1::TicketType::TicketTypeCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::TicketType::TicketTypeCreate - API TicketType TicketTypeCreate Operation backend

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

=item Run()

perform TicketTypeCreate Operation. This will return the created TypeID.

    my $Result = $OperationObject->Run(
        Data => {
	    	TicketType  => {
	        	Name    => '...',
	        	ValidID => '...',	
	    	},
	    },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TypeID  => '',                          # TypeID 
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

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'TicketType' => {
                Type     => 'HASH',
                Required => 1
            },
            'TicketType::Name' => {
                Required => 1
            },
            'TicketType::ValidID' => {
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

    # isolate TicketType parameter
    my $TicketType = $Param{Data}->{TicketType};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$TicketType} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $TicketType->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $TicketType->{$Attribute} =~ s{\s+\z}{};
        }
    }   
        	
    # check if tickettype exists
    my $Exists = $Kernel::OM->Get('Kernel::System::Type')->NameExistsCheck(
        Name => $TicketType->{Name},
    );
    
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'TicketTypeCreate.TicketTypeExists',
            Message => "Can not create TicketType. TicketType with same name '$TicketType->{Name}' already exists.",
        );
    }

    # create tickettype
    my $TicketTypeID = $Kernel::OM->Get('Kernel::System::Type')->TypeAdd(
        Name    => $TicketType->{Name},
        ValidID => $TicketType->{ValidID},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$TicketTypeID ) {
        return $Self->_Error(
            Code    => 'TicketTypeCreate.UnableToCreate',
            Message => 'Could not create type, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        TicketTypeID => $TicketTypeID,
    );    
}

1;
