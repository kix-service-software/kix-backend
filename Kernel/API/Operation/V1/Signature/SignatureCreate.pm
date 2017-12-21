# --
# Kernel/API/Operation/Signature/SignatureCreate.pm - API Signature Create operation backend
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

package Kernel::API::Operation::V1::Signature::SignatureCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Signature::SignatureCreate - API Signature SignatureCreate Operation backend

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

perform SignatureCreate Operation. This will return the created SignatureID.

    my $Result = $OperationObject->Run(
        Data => {
            Signature  => {
                Name        => 'New Signature',
                Text        => "--\nSome Signature Infos",
                ContentType => 'text/plain; charset=utf-8',
                Comment     => 'some comment',                  # optional
                ValidID     => 1,                               # 0|1 default 1
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            SignatureID  => '',                         # ID of the created Signature
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
        Data       => $Param{Data},
        Parameters => {
            'Signature' => {
                Type     => 'HASH',
                Required => 1
            },
            'Signature::Name' => {
                Required => 1
            },
            'Signature::Text' => {
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

    # isolate Signature parameter
    my $Signature = $Param{Data}->{Signature};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Signature} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Signature->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Signature->{$Attribute} =~ s{\s+\z}{};
        }
    }   
     	
    # check if Signature exists
    my %List = $Kernel::OM->Get('Kernel::System::Signature')->SignatureList();

    foreach my $ID ( keys %List ) {                   
        my %SignatureData = $Kernel::OM->Get('Kernel::System::Signature')->SignatureGet(
            ID    => $ID,
        );

        if ( $SignatureData{Name} eq $Signature->{Name} ) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Can not create Signature. Signature with same name '$Signature->{Name}' already exists.",
            );
        }
    }        

    # create Signature
    my $SignatureID = $Kernel::OM->Get('Kernel::System::Signature')->SignatureAdd(
        Name        => $Signature->{Name},
        Text        => $Signature->{Text},
        ContentType => $Signature->{Login} || 'text/plain; charset=utf-8',
        Comment     => $Signature->{Comment} || '',
        ValidID     => $Signature->{ValidID} || 1,
        UserID      => $Self->{Authorization}->{UserID},              
    );

    if ( !$SignatureID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Signature, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        SignatureID => $SignatureID,
    );    
}


1;
