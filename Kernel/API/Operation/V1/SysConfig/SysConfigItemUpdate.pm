# --
# Kernel/API/Operation/SysConfigItem/SysConfigItemUpdate.pm - API SysConfigItem Update operation backend
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

package Kernel::API::Operation::V1::SysConfig::SysConfigItemUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SysConfig::SysConfigItemUpdate - API SysConfigItem Update Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SysConfigItemUpdate');

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
        'SysConfigItemID' => {
            Required => 1
        },
        'SysConfigItem' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform SysConfigItemUpdate Operation. This will return the updated SysConfigItemID.

    my $Result = $OperationObject->Run(
        Data => {
            SysConfigItemID => 123,
            SysConfigItem   => {
                Data   => {}                # optional 
	            Active => 1,                # optional
            }
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            SysConfigItemID  => 123,             # ID of the updated SysConfigItem 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate SysConfigItem parameter
    my $SysConfigItem = $Param{Data}->{SysConfigItem};    

    if ( $SysConfigItem->{Active} && !defined($SysConfigItem->{Data}) ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Need a value if item should be active!',
        );
    }

    # update SysConfigItem
    my $Success = $Kernel::OM->Get('Kernel::System::SysConfig')->ConfigItemUpdate(
        Key   => $Param{Data}->{SysConfigItemID},
        Value => $SysConfigItem->{Data},
        Valid => $SysConfigItem->{Active},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update SysConfigItem, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        SysConfigItemID => $Param{Data}->{SysConfigItemID},
    );    
}


