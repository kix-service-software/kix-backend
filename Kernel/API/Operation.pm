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

# mapping for permissions
use constant REQUEST_METHOD_PERMISSION_MAPPING => {
    'GET'    => 'READ',
    'POST'   => 'CREATE',
    'PATCH'  => 'UPDATE',
    'DELETE' => 'DELETE',
};

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
        OperationRouteMapping => {},                      # required
        NoAuthorizationNeeded => 1                        # optional
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject Operation OperationType OperationRouteMapping RequestMethod RequestURI CurrentRoute WebserviceID)) {
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

    $Self->{OperationConfig} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::Module')->{$Param{OperationType}};
    if ( !IsHashRefWithData($Self->{OperationConfig}) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => 'No OperationConfig found!',
        );
    }

    # check permission
    if ( IsHashRefWithData($Param{Authorization}) ) {
        my ($Granted, @AllowedMethods) = $Self->_CheckOperationPermission(
            Authorization => $Param{Authorization},
        );
        if ( !$Granted ) {
            return $Self->_Error(
                Code => 'Forbidden',
                Additional => {
                    AddHeader => {
                        Allow => join(', ', @AllowedMethods),
                    }
                }
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

    # pass information to backend
    foreach my $Key ( qw(Authorization RequestURI RequestMethod Operation OperationType OperationConfig OperationRouteMapping) ) {
        $Self->{BackendObject}->{$Key} = $Param{$Key} || $Self->{$Key};
    }

    # add call level
    $Self->{Level} = $Param{Level};
    $Self->{BackendObject}->{Level} = $Self->{Level};

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

    # start the backend
    return $Self->{BackendObject}->RunOperation(%Param);
}

=item Options()

gather information about the Operation.

    my $Result = $OperationObject->Options();

    $Result = {
        Success         => 1,                   # 0 or 1
        ErrorMessage    => '',                  # in case of error
        Data            => {                    # result data payload after Operation
            ...
        },
    };

=cut

sub Options {
    my ( $Self, %Param ) = @_;    

    # start the backend
    return $Self->{BackendObject}->Options(%Param);
}

=item GetCacheDependencies()

returns the cache dependencies of the backend object

    my $Result = $OperationObject->GetCacheDependencies();

    $Result = {
        CacheType1 => 1,
        CacheType2 => 2
    };

=cut

sub GetCacheDependencies {
    my ( $Self, %Param ) = @_;    

    return $Self->{BackendObject}->{CacheDependencies};
}


=begin Internal:

=item _CheckOperationPermission()

checks whether the user is allowed to execute this operation

    my $Permission = $OperationObject->_CheckOperationPermission(
        Authorization    => { },
    );

=cut

sub _CheckOperationPermission {
    my ( $Self, %Param ) = @_;    

    my $RequestedPermission = Kernel::API::Operation->REQUEST_METHOD_PERMISSION_MAPPING->{$Self->{RequestMethod}};

    # check if token allows access, first check denials
    my $Access = 1;
    foreach my $DeniedOp ( @{$Param{Authorization}->{DeniedOperations}} ) {
        if ( $Self->{OperationType} =~ /^$DeniedOp$/g ) {
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
            if ( $Self->{OperationType} =~ /^$AllowedOp$/g ) {
                $Access = 1;
                last;
            }
        }        
    }

    # return false if access is explicitly denied by token
    if ( !$Access ) {
        $Self->_PermissionDebug("RequestURI = $Self->{RequestURI}, requested permission = $RequestedPermission --> permission denied by token");
        return;
    }

    # check if user has permission for this request
    my ($Granted, $AllowedPermission) = $Kernel::OM->Get('Kernel::System::User')->CheckPermission(
        UserID              => $Param{Authorization}->{UserID},
        Target              => $Self->{RequestURI},
        RequestedPermission => $RequestedPermission,
    );

    $Self->_PermissionDebug(sprintf("RequestURI = $Self->{RequestURI}, requested permission = $RequestedPermission --> Granted = $Granted, allowed permission = 0x%04x", ($AllowedPermission||0)));

    my @AllowedMethods;
    if ( $AllowedPermission ) {
        my %ReversePermissionMapping = reverse %{Kernel::API::Operation->REQUEST_METHOD_PERMISSION_MAPPING};
        foreach my $Perm ( sort keys %{Kernel::System::Role::Permission->PERMISSION} ) {
            next if (($AllowedPermission & Kernel::System::Role::Permission->PERMISSION->{$Perm}) != Kernel::System::Role::Permission->PERMISSION->{$Perm});
            push(@AllowedMethods, $ReversePermissionMapping{$Perm});
        }
    }

    # OPTIONS requests are always possible
    $Granted = 1 if ( $Self->{RequestMethod} eq 'OPTIONS' );

    return ($Granted, @AllowedMethods);
}

sub _PermissionDebug {
    my ( $Self, $Message ) = @_;

    return if ( !$Kernel::OM->Get('Kernel::Config')->Get('Permission::Debug') );

    printf STDERR "%10s %s\n", "[Permission]", $Message;
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
