# --
# Kernel/API/Operation/ObjectIcon/ObjectIconUpdate.pm - API ObjectIcon Update operation backend
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

package Kernel::API::Operation::V1::ObjectIcon::ObjectIconUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectIcon::ObjectIconUpdate - API ObjectIcon Update Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ObjectIconUpdate');

    return $Self;
}

=item Run()

perform ObjectIconUpdate Operation. This will return the updated ObjectIconID.

    my $Result = $OperationObject->Run(
        Data => {
            ObjectIconID => 123,
        	ObjectIcon => {
                Object      => '...',           # optional
                ObjectID    => '...',           # optional
                ContentType => '...',           # optional
                Content     => '...'            # optional
            }
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            ObjectIconID  => 123,               # ID of the updated ObjectIcon 
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
            'ObjectIconID' => {
                Required => 1
            },
            'ObjectIcon' => {
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

     # isolate and trim ObjectIcon parameter
    my $ObjectIcon = $Self->_Trim(
        Data => $Param{Data}->{ObjectIcon},
    );   

    # check if ObjectIcon entry exists
    my %ObjectIconData = $Kernel::OM->Get('Kernel::System::ObjectIcon')->ObjectIconGet(
        ID => $Param{Data}->{ObjectIconID},
    );
  
    if ( !%ObjectIconData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update ObjectIcon. No ObjectIcon with ObjectIconID $Param{Data}->{ObjectIconID} found",
        );
    }
    
    # check if ObjectIcon exists
    my $ObjectIconList = $Kernel::OM->Get('Kernel::System::ObjectIcon')->ObjectIconList(
        Object   => $ObjectIcon->{Object},
        ObjectID => $ObjectIcon->{ObjectID},        
    );

    if ( IsArrayRefWithData($ObjectIconList) && $ObjectIconList->[0] != $Param{Data}->{ObjectIconID} ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create ObjectIcon. Another ObjectIcon with the same Object and ObjectID already exists.",
        );
    }
    
    # update ObjectIcon
    my $Success = $Kernel::OM->Get('Kernel::System::ObjectIcon')->ObjectIconUpdate(
        ID          => $Param{Data}->{ObjectIconID},
        Object      => $ObjectIcon->{Object} || $ObjectIconData{Object},
        ObjectID    => $ObjectIcon->{ObjectID} || $ObjectIconData{ObjectID},
        ContentType => $ObjectIcon->{ContentType} || $ObjectIconData{ContentType},
        Content     => $ObjectIcon->{Content} || $ObjectIconData{Content},
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update ObjectIcon, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        ObjectIconID => $Param{Data}->{ObjectIconID},
    );    
}


