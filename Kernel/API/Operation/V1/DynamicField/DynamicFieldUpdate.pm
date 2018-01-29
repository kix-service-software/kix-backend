# --
# Kernel/API/Operation/DynamicField/DynamicFieldUpdate.pm - API DynamicField Update operation backend
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

package Kernel::API::Operation::V1::DynamicField::DynamicFieldUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::DynamicField::DynamicFieldUpdate - API DynamicField Update Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::DynamicFieldUpdate');

    return $Self;
}

=item Run()

perform DynamicFieldUpdate Operation. This will return the updated DynamicFieldID.

    my $Result = $OperationObject->Run(
        Data => {
            DynamicFieldID => 123,
            DynamicField   => {
	            Name            => '...',            # optional
	            Label           => '...',            # optional
                FieldType       => '...',            # optional
                DisplayGroupID  => 123,              # optional
                ObjectType      => '...',            # optional
                Config          => { }               # optional
	            ValidID         => 1,                # optional
            }
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            DynamicFieldID  => 123,             # ID of the updated DynamicField 
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
            'DynamicFieldID' => {
                Required => 1
            },
            'DynamicField' => {
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

    # isolate and trim DynamicField parameter
    my $DynamicField = $Self->_Trim(
        Data => $Param{Data}->{DynamicField}
    );

    # check attribute values
    my $CheckResult = $Self->_CheckDynamicField( 
        DynamicField => $DynamicField
    );

    if ( !$CheckResult->{Success} ) {
        return $Self->_Error(
            %{$CheckResult},
        );
    }

    # check if name is duplicated
    my %DynamicFieldsList = %{
        $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldList(
            Valid      => 0,
            ResultType => 'HASH',
        )
    };

    %DynamicFieldsList = reverse %DynamicFieldsList;

    if ( $DynamicField->{Name} && $DynamicFieldsList{ $DynamicField->{Name} } && $DynamicFieldsList{ $DynamicField->{Name} } ne $Param{Data}->{DynamicFieldID} ) {

        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Can not update DynamicField. Another DynamicField with same name already exists.',
        );
    }

    # check if DynamicField exists 
    my $DynamicFieldData = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
        ID => $Param{Data}->{DynamicFieldID},
    );
  
    if ( !IsHashRefWithData($DynamicFieldData) ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update DynamicField. No DynamicField with ID '$Param{Data}->{DynamicFieldID}' found.",
        );
    }

    # if it's an internal field, it's name should not change
    if ( $DynamicField->{Name} && $DynamicFieldData->{InternalField} && $DynamicField->{Name} ne $DynamicFieldData->{Name} ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Cannot update name of DynamicField, because it is an internal field.',
        );
    }

    # update DynamicField
    my $Success = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldUpdate(
        ID              => $Param{Data}->{DynamicFieldID},
        Name            => $DynamicField->{Name} || $DynamicFieldData->{Name},
        Label           => $DynamicField->{Label} || $DynamicFieldData->{Label},
        FieldType       => $DynamicField->{FieldType} || $DynamicFieldData->{FieldType},
        DisplayGroupID  => $DynamicField->{DisplayGroupID} || $DynamicFieldData->{DisplayGroupID},
        ObjectType      => $DynamicField->{ObjectType} || $DynamicFieldData->{ObjectType},
        Config          => $DynamicField->{Config} || $DynamicFieldData->{Config},
        ValidID         => $DynamicField->{ValidID} || $DynamicFieldData->{ValidID},
        UserID          => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update DynamicField, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        DynamicFieldID => $Param{Data}->{DynamicFieldID},
    );    
}

