# --
# Kernel/API/Operation/Salutation/SalutationUpdate.pm - API Salutation Update operation backend
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

package Kernel::API::Operation::V1::Salutation::SalutationUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Salutation::SalutationUpdate - API Salutation Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SalutationUpdate');

    return $Self;
}

=item Run()

perform SalutationUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            SalutationID => 123,
            Salutation  => {
                Name        => 'New Salutation',
                Text        => "--\nSome Salutation Infos",
                ValidID     => 1,                           # (optional)               
                Comment     => '...',                       # (optional)
                ContentType => 'text/plain; charset=utf-8',              
            },
        },
    );
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            SalutationID  => 123,                     # ID of the updated Salutation 
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
        Data         => $Param{Data},
        Parameters   => {
            'SalutationID' => {
                Required => 1
            },
            'Salutation' => {
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

    # isolate Salutation parameter
    my $Salutation = $Param{Data}->{Salutation};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Salutation} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Salutation->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Salutation->{$Attribute} =~ s{\s+\z}{};
        }
    }   

    # check if Salutation exists 
    my %SalutationData = $Kernel::OM->Get('Kernel::System::Salutation')->SalutationGet(
        ID => $Param{Data}->{SalutationID},
        UserID      => $Self->{Authorization}->{UserID},        
    );
 
    if ( !%SalutationData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update Salutation. No Salutation with ID '$Param{Data}->{SalutationID}' found.",
        );
    }

    # update Salutation
    my $Success = $Kernel::OM->Get('Kernel::System::Salutation')->SalutationUpdate(
        ID       => $Param{Data}->{SalutationID} || $SalutationData{SalutationID},
        Name     => $Salutation->{Name} || $SalutationData{Name},
        Comment  => $Salutation->{Comment} || $SalutationData{Comment},
        ValidID  => $Salutation->{ValidID} || $SalutationData{ValidID},
        Text     => $Salutation->{Text} || $SalutationData{Text},
        ContentType => $Salutation->{ContentType} || 'text/plain; charset=utf-8',
        UserID   => $Self->{Authorization}->{UserID},                      
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update Salutation, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        SalutationID => $Param{Data}->{SalutationID},
    );    
}

1;
