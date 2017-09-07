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

Kernel::API::Operation::V1::TicketType::TicketTypeCreate - GenericInterface TicketType TicketTypeCreate Operation backend

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
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::TicketTypeCreate');

    return $Self;
}

=item TicketTypeCreate()

create a new ticket Tickettype

    my $Result = $OperationObject->Run(
        Data => {
            Authorization => {
                ...
            },
            
    TicketType(
        Name    => '...',
        ValidID => '...',
        UserID  => '...',
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TicketTypeID  => '',                          # TicketTypeID 
            Error => {                              # should not return errors
                    ErrorCode    => 'TicketType.Create.ErrorCode'
                    ErrorMessage => 'Error Description'
            },
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
        $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'TicketTypeID' => {
                Type     => 'HASH',
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

    # get relevant function	
    my $TicketTypeID;
    my %TicketTypeData ={};
        	
    # check if tickettype exists
    my $Exists = $Kernel::OM->Get('Kernel::System::Type')->NameExistsCheck(
        Name => $Param{Data}->{Name},
    );
    
    if ( $Exists ) {
        return $Self->ReturnError(
            ErrorCode    => 'TicketTypeCreate.LoginExists',
            ErrorMessage => "Can not create user. TicketType with same name '$Param{Data}->{Name}' already exists.",
        );
    }

    $TicketTypeID = $Kernel::OM->Get('Kernel::System::Type')->TypeAdd(
        Name    => $Param{Data}->{Name},
        ValidID => 1,
        UserID  => $Param{Data}->{Authorization}->{UserID},
    );

    if ( !$TicketTypeID ) {
        return $Self->ReturnError(
            ErrorCode    => 'TicketTypeCreate.UnknownError',
            ErrorMessage => 'Could not create type, please contact the system administrator',
        );
    }
    
    return $Self->ReturnSuccess(
        TicketTypeID => $TicketTypeID,
    );    
}