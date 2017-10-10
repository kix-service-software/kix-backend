# --
# Kernel/API/Operation/Role/RoleCreate.pm - API Role Create operation backend
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

package Kernel::API::Operation::V1::Role::RoleCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Role::RoleCreate - API Role RoleCreate Operation backend

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

perform RoleCreate Operation. This will return the created RoleID.

    my $Result = $OperationObject->Run(
        Data => {
	    	Role  => {
	        	Name    => '...',
	        	Comment => '...',                 # optional
	        	ValidID => '...',                 # optional
	    	},
	    },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            RoleID  => '',                         # ID of the created Role
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
            'Role' => {
                Type     => 'HASH',
                Required => 1
            },
            'Role::Name' => {
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
    my $Exists = $Kernel::OM->Get('Kernel::System::Group')->RoleLookup(
        Role => $Role->{Name},
    );
    
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'RoleCreate.TypeExists',
            Message => "Can not create Role. Role with same name '$Role->{Name}' already exists.",
        );
    }

    # create Role
    my $RoleID = $Kernel::OM->Get('Kernel::System::Group')->RoleAdd(
        Name    => $Role->{Name},
        Comment => $Role->{Comment} || '',
        ValidID => $Role->{ValidID} || 1,
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$RoleID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Role, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        RoleID => $RoleID,
    );    
}

1;
