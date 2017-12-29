# --
# Kernel/API/Operation/Salutation/SalutationCreate.pm - API Salutation Create operation backend
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

package Kernel::API::Operation::V1::Salutation::SalutationCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Salutation::SalutationCreate - API Salutation SalutationCreate Operation backend

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

perform SalutationCreate Operation. This will return the created SalutationID.

    my $Result = $OperationObject->Run(
        Data => {
            Salutation  => {
                Name        => 'New Salutation',
                Text        => "Some Salutation Infos",
                ValidID     => 1,                           # optional, default 1
                Comment     => '...',                       # optional
                ContentType => 'text/plain; charset=utf-8', # optional, default 'text/plain; charset=utf-8'
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            SalutationID  => '',                         # ID of the created Salutation
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webSalutation
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
            'Salutation' => {
                Type     => 'HASH',
                Required => 1
            },
            'Salutation::Name' => {
                Required => 1
            },
            'Salutation::Text' => {
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

    # isolate and trim Salutation parameter
    my $Salutation = $Self->_Trim(
        Data => $Param{Data}->{Salutation}
    );
     	
    # check if Salutation exists
    my %SalutationList = reverse ( $Kernel::OM->Get('Kernel::System::Salutation')->SalutationList() );

    if ( $SalutationList{$Salutation->{Name}} ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create Salutation. Salutation with same name '$Salutation->{Name}' already exists.",
        );
    }        

    # create Salutation
    my $SalutationID = $Kernel::OM->Get('Kernel::System::Salutation')->SalutationAdd(
        Name        => $Salutation->{Name},
        Text        => $Salutation->{Text},
        Comment     => $Salutation->{Comment} || '',
        ValidID     => $Salutation->{ValidID} || 1,
        ContentType => $Salutation->{ContentType} || 'text/plain; charset=utf-8',
        UserID      => $Self->{Authorization}->{UserID},              
    );

    if ( !$SalutationID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Salutation, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        SalutationID => $SalutationID,
    );    
}


1;
