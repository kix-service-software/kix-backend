# --
# Kernel/API/Operation/Priority/PriorityCreate.pm - API Priority Create operation backend
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

package Kernel::API::Operation::V1::Priority::PriorityCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Priority::PriorityCreate - API Priority PriorityCreate Operation backend

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

perform PriorityCreate Operation. This will return the created PriorityID.

    my $Result = $OperationObject->Run(
        Data => {
    		Priority(
        		Priority    => '...',
        		ValidID => '...',
        	},
        },	
    );

    $Result = {
        Success      => 1,                       # 0 or 1
        Code         => '',                      # 
        Message      => '',                      # in case of error
        Data         => {                        # result data payload after Operation
            PriorityID  => '',                   # PriorityID 
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
use Data::Dumper;
print STDERR "prioparam".Dumper(\%Param);

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
            'Priority' => {
                Type     => 'HASH',
                Required => 1
            },
            'Priority::Priority' => {
                Required => 1
            },
            'Priority::ValidID' => {
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

    # isolate Priority parameter
    my $Priority = $Param{Data}->{Priority};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Priority} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Priority->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Priority->{$Attribute} =~ s{\s+\z}{};
        }
    }

    # get relevant function	
    my $PriorityID;
     	
    # check if Priority exists
    my $Exists = $Kernel::OM->Get('Kernel::System::Priority')->PriorityLookup(
        Priority => $Priority->{Priority},
    );
    
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'PriorityCreate.PriorityExists',
            Message => "Can not create Priority. Priority with same name '$Priority->{Name}' already exists.",
        );
    }

    # create Priority
    $PriorityID = $Kernel::OM->Get('Kernel::System::Priority')->PriorityAdd(
        Name    => $Priority->{Priority},
        ValidID => $Priority->{ValidID},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$PriorityID ) {
        return 0; # $Self->_Error(
            #Code    => 'PriorityCreate.UnableToCreate',
            #Message => 'Could not create type, please contact the system administrator',
        #);
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        PriorityID => $PriorityID,
    );    
}
