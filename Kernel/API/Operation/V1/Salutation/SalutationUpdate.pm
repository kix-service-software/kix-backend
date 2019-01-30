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
        'SalutationID' => {
            Required => 1
        },
        'Salutation' => {
            Type => 'HASH',
            Required => 1
        },   
    }
}

=item Run()

perform SalutationUpdate Operation. This will return the updated SalutationID.

    my $Result = $OperationObject->Run(
        Data => {
            SalutationID => 123,
            Salutation  => {
                Name        => 'New Salutation',                # optional
                Text        => "Some Salutation Infos",         # optional
                ValidID     => 1,                               # optional               
                Comment     => '...',                           # optional
                ContentType => 'text/plain; charset=utf-8',     # optional             
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

    # isolate and trim Salutation parameter
    my $Salutation = $Self->_Trim(
        Data => $Param{Data}->{Salutation}
    );

    # check if Salutation exists 
    my %SalutationData = $Kernel::OM->Get('Kernel::System::Salutation')->SalutationGet(
        ID     => $Param{Data}->{SalutationID},
        UserID => $Self->{Authorization}->{UserID},        
    );
 
    if ( !%SalutationData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if Salutation with this name exists
    my %SalutationList = reverse ( $Kernel::OM->Get('Kernel::System::Salutation')->SalutationList() );

    if ( $SalutationList{$Salutation->{Name}} && $SalutationList{$Salutation->{Name}} ne $Param{Data}->{SalutationID} ) {
        return $Self->_Error(
            Code => 'Object.AlreadyExists',
        );
    }        

    # update Salutation
    my $Success = $Kernel::OM->Get('Kernel::System::Salutation')->SalutationUpdate(
        ID          => $Param{Data}->{SalutationID},
        Name        => $Salutation->{Name} || $SalutationData{Name},
        Comment     => $Salutation->{Comment} || $SalutationData{Comment},
        ValidID     => $Salutation->{ValidID} || $SalutationData{ValidID},
        Text        => $Salutation->{Text} || $SalutationData{Text},
        ContentType => $Salutation->{ContentType} || $SalutationData{ContentType},
        UserID      => $Self->{Authorization}->{UserID},                      
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        SalutationID => $Param{Data}->{SalutationID},
    );    
}

1;
