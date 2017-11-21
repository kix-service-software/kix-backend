# --
# Kernel/API/Operation/SystemAddress/SystemAddressUpdate.pm - API SystemAddress Update operation backend
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

package Kernel::API::Operation::V1::SystemAddress::SystemAddressUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SystemAddress::SystemAddressUpdate - API SystemAddress Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SystemAddressUpdate');

    return $Self;
}

=item Run()

perform SystemAddressUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            SystemAddressID => 123,
            SystemAddress  => {
                Name     => 'info@example.com',
                Realname => 'Hotline',
                ValidID  => 1,
                Comment  => 'some comment',
            },
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            SystemAddressID  => 123,                     # ID of the updated SystemAddress 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # init webSystemAddress
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
            'SystemAddressID' => {
                Required => 1
            },
            'SystemAddress' => {
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

    # isolate SystemAddress parameter
    my $SystemAddress = $Param{Data}->{SystemAddress};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$SystemAddress} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $SystemAddress->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $SystemAddress->{$Attribute} =~ s{\s+\z}{};
        }
    }   

    # check if SystemAddress exists 
    my %SystemAddressData = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressGet(
        ID => $Param{Data}->{SystemAddressID},
        UserID      => $Self->{Authorization}->{UserID},        
    );
 
    if ( !%SystemAddressData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update SystemAddress. No SystemAddress with ID '$Param{Data}->{SystemAddressID}' found.",
        );
    }

    # update SystemAddress
    my $Success = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressUpdate(
        ID       => $Param{Data}->{SystemAddressID} || $SystemAddressData{SystemAddressID},    
        Name     => $SystemAddress->{Name} || $SystemAddressData{Name},
        Comment  => $SystemAddress->{Comment} || $SystemAddressData{Comment},
        ValidID  => $SystemAddress->{ValidID} || $SystemAddressData{ValidID},
        Realname => $SystemAddress->{Realname} || $SystemAddressData{Realname},        
        UserID   => $Self->{Authorization}->{UserID},               
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update SystemAddress, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        SystemAddressID => $Param{Data}->{SystemAddressID},
    );    
}

1;
