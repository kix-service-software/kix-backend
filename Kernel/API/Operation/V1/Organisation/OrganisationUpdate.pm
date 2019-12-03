# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Organisation::OrganisationUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Organisation::V1::OrganisationUpdate - API Organisation Update Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Organisation::OrganisationUpdate');

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
        'OrganisationID' => {
            Required => 1
        },
        'Organisation' => {
            Type     => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform OrganisationUpdate Operation. This will return the updated OrganisationID.

    my $Result = $OperationObject->Run(
        Data => {
            OrganisationID => 123         # required
            Organisation   => {
                ...                 # attributes (required and optional) depend on Map config 
                ...
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            OrganisationID  => '',                  # OrganisationID 
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Organisation parameter
    my $Organisation = $Self->_Trim(
        Data => $Param{Data}->{Organisation}
    );

    # check Organisation exists
    my %OrganisationData = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationGet(
        ID => $Param{Data}->{OrganisationID},
    );
    if ( !%OrganisationData ) {
        return $Self->_Error(
            Code => 'Object.NotFound'
        );
    }

    # check if Number already exists
    if ( IsStringWithData($Organisation->{Number}) ) {
        my %OrganisationSearch = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationSearch(
            Search => $Organisation->{Number},
        );
        if ( %OrganisationSearch && (scalar(keys %OrganisationSearch) > 1 || !$OrganisationSearch{$OrganisationData{ID}})) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Cannot update organisation. Another organisation with the name already exists.',
            );
        }
    }

    # check if Name already exists
    if ( IsStringWithData($Organisation->{Name}) ) {
        my %OrganisationSearch = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationSearch(
            Search => $Organisation->{Name},
        );
        if ( %OrganisationSearch && (scalar(keys %OrganisationSearch) > 1 || !$OrganisationSearch{$OrganisationData{ID}})) {        
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Cannot update organisation. Another organisation with the name already exists.',
            );
        }
    }
    
    # update Organisation
    my $Success = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationUpdate(
        %OrganisationData,
        %{$Organisation},
        ID     => $Param{Data}->{OrganisationID},
        UserID => $Self->{Authorization}->{UserID},
    );    
    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update organisation, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        OrganisationID => $Param{Data}->{OrganisationID},
    );   
}
=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
