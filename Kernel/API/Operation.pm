# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation;

use strict;
use warnings;

use Kernel::API::Validator;
use Kernel::System::VariableCheck qw(:all);

# prevent 'Used once' warning for Kernel::OM
use Kernel::System::ObjectManager;

use base qw(
    Kernel::API::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation - API Operation interface

=head1 SYNOPSIS

Operations are called by web service requests from remote
systems.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object.

    use Kernel::API::Debugger;
    use Kernel::API::Operation;

    my $DebuggerObject = Kernel::API::Debugger->new(
        DebuggerConfig   => {
            DebugThreshold => 'debug',
            TestMode       => 0,           # optional, in testing mode the data will not be written to the DB
            # ...
        },
        WebserviceID      => 12,
        CommunicationType => Provider, # Requester or Provider
        RemoteIP          => 192.168.1.1, # optional
    );

    my $OperationObject = Kernel::API::Operation->new(
        DebuggerObject  => $DebuggerObject,
        Operation       => 'TicketCreate',                # the name of the operation in the web service
        OperationType   => 'V1::Ticket::TicketCreate',    # the local operation backend to use
        WebserviceID    => $WebserviceID,                 # ID of the currently used web service
        NoAuthorizationNeeded => 1                        # optional
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject Operation OperationType WebserviceID)) {
        if ( !$Param{$Needed} ) {

            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # check operation
    if ( !IsStringWithData( $Param{OperationType} ) ) {

        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => 'Got no Operation with content!',
        );
    }

    my $OperationConfig = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::Module')->{$Param{OperationType}};
    if ( !IsHashRefWithData($OperationConfig) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => 'No OperationConfig found!',
        );
    }

    # check permission
    if ( IsHashRefWithData($Param{Authorization}) ) {
        my $Permission = $Self->_CheckOperationPermission(
            OperationType   => $Param{OperationType},
            OperationConfig => $OperationConfig,
            Authorization   => $Param{Authorization},
        );
        if ( !$Permission ) {
            return $Self->_Error(
                Code    => 'Forbidden',
                Message => 'No permission to execute this operation!',
            );
        }
    }

    # create validator
    $Self->{ValidatorObject} = Kernel::API::Validator->new(
        %{$Self},
    );

    # if validator init failed, bail out
    if ( ref $Self->{ValidatorObject} ne 'Kernel::API::Validator' ) {
        return $Self->_GenerateErrorResponse(
            %{$Self->{ValidatorObject}},
        );
    }

    # load backend module
    my $GenericModule = 'Kernel::API::Operation::' . $Param{OperationType};
    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($GenericModule) ) {

        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "Can't load operation backend module $GenericModule!"
        );
    }
    $Self->{BackendObject} = $GenericModule->new(
        %{$Self},
    );

    # pass back error message from backend if backend module could not be executed
    return $Self->{BackendObject} if ref $Self->{BackendObject} ne $GenericModule;

    # pass authorization information to backend
    $Self->{BackendObject}->{Authorization}   = $Param{Authorization};

    # pass operation information to backend
    $Self->{BackendObject}->{Operation}       = $Param{Operation};
    $Self->{BackendObject}->{OperationType}   = $Param{OperationType};
    $Self->{BackendObject}->{OperationConfig} = $OperationConfig;

    return $Self;
}

=item Run()

perform the selected Operation.

    my $Result = $OperationObject->Run(
        Data => {                               # data payload before Operation
            ...
        },
    );

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
        Data            => {                    # result data payload after Operation
            ...
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;    

    # validate data
    my $ValidatorResult = $Self->{ValidatorObject}->Validate(
        %Param
    );

    if ( !$ValidatorResult->{Success} ) {

        return $Self->_Error(
            %{$ValidatorResult},
        );
    }

    # start map on backend
    return $Self->{BackendObject}->Run(%Param);
}

=begin Internal:

=item _CheckOperationPermission()

checks whether the user is allowed to execute this operation

    my $Permission = $OperationObject->_CheckOperationPermission(
        OperationType    => 'V1::Own::UserGet',
        OperationConfig  => { },
        Authorization    => { },
    );

=cut

sub _CheckOperationPermission {
    my ( $Self, %Param ) = @_;    

    # check if token allows access, first check denials
    my $Access = 1;
    foreach my $DeniedOp ( @{$Param{Authorization}->{DeniedOperations}} ) {
        if ( $Param{OperationType} =~ /^$DeniedOp$/g ) {
            $Access = 0;
            last;
        }
    }

    if ( !IsArrayRefWithData($Param{Authorization}->{DeniedOperations}) || !$Access ) {
        if ( IsArrayRefWithData($Param{Authorization}->{AllowedOperations}) ) {
            # clear access flag, we are restricted
            $Access = 0;
        }
        # we don't have access, so check if the operation is explicitly allowed
        foreach my $AllowedOp ( @{$Param{Authorization}->{AllowedOperations}} ) {
            if ( $Param{OperationType} =~ /^$AllowedOp$/g ) {
                $Access = 1;
                last;
            }
        }        
    }

    return 0 if !$Access;

    return 1 if !$Param{OperationConfig}->{Permission};

    # parse permissions
    my $Result = 0;
    PERMISSION:
    foreach my $PermissionDef ( split(/\s*,\s*/, $Param{OperationConfig}->{Permission}) ) {

        my ($ObjectType, $Rest)   = split(/=/, $PermissionDef);
        my ($Object, $Permission) = split(/:/, $Rest);
        my @UserIDs;

        # check roles, groups and users
        if ( uc($ObjectType) eq 'ROLE' ) {
            my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
            my $RoleID = $GroupObject->RoleLookup( 
                Role => $Object
            );
            if ( $RoleID ) {
                @UserIDs = $GroupObject->GroupUserRoleMemberList(
                    RoleID => $RoleID,
                    Result => 'ID',
                );
            }
        }
        elsif ( uc($ObjectType) eq 'GROUP' ) {
            my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');
            my $GroupID = $GroupObject->GroupLookup( 
                Group => $Object
            );
            if ( $GroupID ) {
                @UserIDs = $GroupObject->GroupGroupMemberList(
                    GroupID => $GroupID,
                    Type    => $Permission,
                    Result  => 'ID',
                );
            }
        }
        elsif ( uc($ObjectType) eq 'USER' ) {
            my $UserObject = $Kernel::OM->Get('Kernel::System::User');
            my $UserID = $UserObject->UserLookup( 
                UserLogin => $Object 
            );
            if ( $UserID ) {
                push(@UserIDs, $UserID);
            }
        }

        my %UserHash = map { $_ => 1 } @UserIDs;
        if ( $UserHash{$Param{Authorization}->{UserID}} ) {
            # user has permission, abort loop
            $Result = 1;
            last PERMISSION;
        }
    }

    return $Result;
}

1;

=end Internal:


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
