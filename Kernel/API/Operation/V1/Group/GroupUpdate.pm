# --
# Kernel/API/Operation/Group/GroupUpdate.pm - API Group Update operation backend
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

package Kernel::API::Operation::V1::Group::GroupUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Group::GroupUpdate - API Group Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::GroupUpdate');

    return $Self;
}

=item Run()

perform GroupUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            ID      => '...',
        }
	    Group => {
	        Name    => '...',
	        ValidID => '...',
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            GroupID  => '',               # GroupID 
            Error   => {                        # should not return errors
                    Code    => 'Group.Update.ErrorCode'
                    Message => 'Error Description'
            },
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
            'GroupID' => {
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

    # isolate Group parameter
    my $Group = $Param{Data}->{Group};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Group} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Group->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Group->{$Attribute} =~ s{\s+\z}{};
        }
    }   

    # check if Group exists 
    my $GroupData = $Kernel::OM->Get('Kernel::System::Group')->GroupLookup(
        GroupID => $Param{Data}->{GroupID},
    );
  
    if ( !$GroupData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Can not update Group. No Group with ID '$Param{Data}->{GroupID}' found.",
        );
    }

    # update Group
    my $Success = $Kernel::OM->Get('Kernel::System::Group')->GroupUpdate(
        ID      => $Param{Data}->{GroupID},
        Name    => $Param{Data}->{Group}->{Name} || $Group->{Name},
        Comment => $Group->{Comment} || '',
        ValidID => $Param{Data}->{Group}->{ValidID} || $Group->{ValidID},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update Group, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        GroupID => $Param{Data}->{GroupID},
    );    
}


