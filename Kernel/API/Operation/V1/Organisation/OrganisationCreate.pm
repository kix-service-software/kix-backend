# --
# Kernel/API/Operation/Organisation/OrganisationCreate.pm - API Organisation Create operation backend
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

package Kernel::API::Operation::V1::Organisation::OrganisationCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Organisation::V1::OrganisationCreate - API Organisation Create Operation backend

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
        'Organisation' => {
            Type     => 'HASH',
            Required => 1
        },          
        'Contact::Number' => {
            Required => 1
        },            
        'Contact::Name' => {
            Required => 1
        },
    }
}

=item Run()

perform OrganisationCreate Operation. This will return the created OrganisationLogin.

    my $Result = $OperationObject->Run(
        Data => {
            Organisation => {
                ...                 # attributes (required and optional) depend on Map config 
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            OrganisationID  => '',                       # OrganisationID 
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Organisation parameter
    my $Organisation = $Self->_Trim(
        Data => $Param{Data}->{Organisation}
    );

    # check Number exists
    my %OrganisationSearch = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationSearch(
        Search => $Organisation->{Number},
    );
    if ( %OrganisationSearch ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Cannot create organisation. Another organisation with same number already exists.',
        );
    }

    # check Name exists
    %OrganisationSearch = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationSearch(
        Search => $Organisation->{Name},
    );
    if ( %OrganisationSearch ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Cannot create organisation. Another organisation with same name already exists.',
        );
    }
    
    # create Organisation
    my $OrganisationID = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationAdd(
        %{$Organisation},
        ValidID => $Organisation->{ValidID} || 1,
        UserID  => $Self->{Authorization}->{UserID},
    );    
    if ( !$OrganisationID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create organisation, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        Code   => 'Object.Created',
        OrganisationID => $OrganisationID,
    );    
}
