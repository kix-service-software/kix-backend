# --
# Kernel/API/Operation/Signature/SignatureUpdate.pm - API Signature Update operation backend
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

package Kernel::API::Operation::V1::Signature::SignatureUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Signature::SignatureUpdate - API Signature Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SignatureUpdate');

    return $Self;
}

=item Run()

perform SignatureUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            SignatureID => 123,
            Signature  => {
                Name        => 'New Signature',                 # optional
                Text        => "--\nSome Signature Infos",      # optional
                ContentType => 'text/plain; charset=utf-8',     # optional
                Comment     => 'some comment',                  # optional
                ValidID     => 1,                               # optional
            },
        },
    );
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            SignatureID  => 123,                     # ID of the updated Signature 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # init webSignature
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
        Data         => $Param{Data},
        Parameters   => {
            'SignatureID' => {
                Required => 1
            },
            'Signature' => {
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

    # isolate and trim Signature parameter
    my $Signature = $Self->_Trim(
        Data => $Param{Data}->{Signature},
    );

    # check if Signature exists 
    my %SignatureData = $Kernel::OM->Get('Kernel::System::Signature')->SignatureGet(
        ID => $Param{Data}->{SignatureID},
    );
 
    if ( !%SignatureData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update Signature. No Signature with ID '$Param{Data}->{SignatureID}' found.",
        );
    }

    # check if Signature exists
    my %SignatureList = reverse ( $Kernel::OM->Get('Kernel::System::Signature')->SignatureList() );

    if ( $SignatureList{$Signature->{Name}} && $SignatureList{$Signature->{Name}} ne $Param{Data}->{SignatureID} ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create Signature. Signature with same name '$Signature->{Name}' already exists.",
        );
    }   

    # update Signature
    my $Success = $Kernel::OM->Get('Kernel::System::Signature')->SignatureUpdate(
        ID          => $Param{Data}->{SignatureID},
        Name        => $Signature->{Name} || $SignatureData{Name},
        Text        => $Signature->{Text} || $SignatureData{Text},
        ContentType => $Signature->{ContentType} || $SignatureData{ContentType},
        Comment     => $Signature->{Comment} || $SignatureData{Comment},
        ValidID     => $Signature->{ValidID} || $SignatureData{ValidID},
        UserID      => $Self->{Authorization}->{UserID},            
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update Signature, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        SignatureID => $Param{Data}->{SignatureID},
    );    
}

1;
