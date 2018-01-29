# --
# Kernel/API/Operation/ObjectIcon/ObjectIconCreate.pm - API ObjectIcon Create operation backend
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

package Kernel::API::Operation::V1::ObjectIcon::ObjectIconCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectIcon::ObjectIconCreate - API ObjectIcon ObjectIconCreate Operation backend

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

perform ObjectIconCreate Operation. This will return the created ObjectIconID.

    my $Result = $OperationObject->Run(
        Data => {
        	ObjectIcon => {
                Object      => '...',
                ObjectID    => '...',
                ContentType => '...',
                Content     => '...'
            }
	    },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ObjectIconID  => '',                          # ID of the created ObjectIcon
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    # trim 
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
            'ObjectIcon' => {
                Type => 'HASH',
                Required => 1
            },
            'ObjectIcon::Object' => {
                Required => 1
            },
            'ObjectIcon::ObjectID' => {
                Required => 1
            },
            'ObjectIcon::ContentType' => {
                Required => 1
            },
            'ObjectIcon::Content' => {
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
   
    # check if ObjectIcon exists
    my $ObjectIconList = $Kernel::OM->Get('Kernel::System::ObjectIcon')->ObjectIconList(
        Object   => $ObjectIcon->{Object},
        ObjectID => $ObjectIcon->{ObjectID},        
    );

    if ( IsArrayRefWithData($ObjectIconList) ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create ObjectIcon. Another ObjectIcon with the same Object and ObjectID already exists.",
        );
    }

    # create ObjectIcon
    my $ObjectIconID = $Kernel::OM->Get('Kernel::System::ObjectIcon')->ObjectIconAdd(
        Object      => $ObjectIcon->{Object},
        ObjectID    => $ObjectIcon->{ObjectID},
        ContentType => $ObjectIcon->{ContentType},
        Content     => $ObjectIcon->{Content},
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$ObjectIconID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create ObjectIcon, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        ObjectIconID => $ObjectIconID,
    );    
}

1;
