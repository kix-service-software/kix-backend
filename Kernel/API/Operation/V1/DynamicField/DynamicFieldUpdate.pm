# --
# Kernel/API/Operation/Role/RoleUpdate.pm - API Role Update operation backend
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

package Kernel::API::Operation::V1::Role::RoleUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Role::RoleUpdate - API Role Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::RoleUpdate');

    return $Self;
}

=item Run()

perform RoleUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            RoleID => 123,
            Role   => {
	            Name    => '...',
	            Comment => '...',
	            ValidID => 1,
            }
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            RoleID  => 123,                     # ID of the updated Role 
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
        Data         => $Param{Data},
        Parameters   => {
            'RoleID' => {
                Required => 1
            },
            'Role' => {
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

    # isolate Role parameter
    my $Role = $Param{Data}->{Role};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Role} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Role->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Role->{$Attribute} =~ s{\s+\z}{};
        }
    }   

    # check if Role exists 
    my $RoleData = $Kernel::OM->Get('Kernel::System::Group')->RoleLookup(
        RoleID => $Param{Data}->{RoleID},
    );
  
    if ( !$RoleData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update Role. No Role with ID '$Param{Data}->{RoleID}' found.",
        );
    }

    # update Role
    my $Success = $Kernel::OM->Get('Kernel::System::Group')->RoleUpdate(
        ID      => $Param{Data}->{RoleID},
        Name    => $Role->{Name} || $RoleData->{Name},
        Comment => $Role->{Comment} || $RoleData->{Comment},
        ValidID => $Role->{ValidID}  || $RoleData->{ValidID},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update Role, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        RoleID => $Param{Data}->{RoleID},
    );    
}


