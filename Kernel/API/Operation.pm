# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation;

use strict;
use warnings;

use File::Basename;
use Storable;

use Kernel::API::Validator;
use Kernel::System::Role::Permission;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::PerfLog qw(TimeDiff);

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

    use Kernel::API::Operation;

    my $OperationObject = Kernel::API::Operation->new(
        Operation       => 'TicketCreate',                # the name of the operation in the web service
        OperationType   => 'V1::Ticket::TicketCreate',    # the local operation backend to use
        WebserviceID    => $WebserviceID,                 # ID of the currently used web service
        OperationRouteMapping => {},                      # required
        ParentMethodOperationMapping => {}                # required
        NoAuthorizationNeeded => 1                        # optional
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(Operation OperationType OperationRouteMapping ParentMethodOperationMapping AvailableMethods RequestMethod RequestURI CurrentRoute WebserviceID)) {
        if ( !$Param{$Needed} ) {

            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{CallingOperationType} = $Param{CallingOperationType};

    # check operation
    if ( !IsStringWithData( $Param{OperationType} ) ) {

        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => 'Got no Operation with content!',
        );
    }

    if ( !IsHashRefWithData($Kernel::OM->Get('Config')->Get('API::Operation::Module')) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => 'No OperationConfig found!',
        );
    }

    $Self->{OperationConfig} = $Kernel::OM->Get('Config')->Get('API::Operation::Module')->{$Param{OperationType}};
    if ( !IsHashRefWithData($Self->{OperationConfig}) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => 'No OperationConfig found!',
        );
    }

    # prepare ImplicitPagingFor config
    if ($Self->{OperationConfig}->{ImplicitPagingFor}) {
        $Self->{OperationConfig}->{ImplicitPagingFor} =  { map { $_ => 1 } split(/,/, $Self->{OperationConfig}->{ImplicitPagingFor}) };
    }

    # init call level
    $Self->{Level} = $Param{Level} || 0;
    $Self->{LevelIndent} = '    ' x $Self->{Level} || '';

    # check permission
    if ( IsHashRefWithData($Param{Authorization}) ) {
        if ( !$Param{IgnorePermissions} ) {
            my ($Granted, @AllowedMethods) = $Self->_CheckPermission(
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

        $Self->{Authorization} = $Param{Authorization};
    }

    # create validator
    $Self->{ValidatorObject} = $Kernel::OM->Get('API::Validator');

    # load backend module
    my $GenericModule = $Self->{OperationConfig}->{Module};
    if ( !$Kernel::OM->Get('Main')->Require($GenericModule) ) {

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
    foreach my $Key (
        qw(
            Authorization RequestURI RequestMethod Operation OperationType
            OperationConfig OperationRouteMapping ParentMethodOperationMapping
            AvailableMethods IgnorePermissions SuppressPermissionErrors HandleSortInCORE
        )
    ) {
        $Self->{BackendObject}->{$Key} = $Self->{$Key} || $Param{$Key};
    }

    # add call level
    $Self->{BackendObject}->{Level} = $Self->{Level};

    return $Self;
}

=item Run()

perform the selected Operation.

    my $Result = $OperationObject->Run(
        Data => {                               # data payload before Operation
            ...
        },
        PermissionCheckOnly => 1                # optional
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

    my $StartTime = Time::HiRes::time();

    if ( exists $Param{Data} && !IsHashRef($Param{Data}) ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Invalid Data!"
        );
    }

    if ( !$Param{PermissionCheckOnly} ) {

        my $DoValidate = $Param{IgnoreValidators} ? 0 : 1;

        my $DoNotValidate = $Kernel::OM->Get('Config')->Get('API::Validator::DisableForResource');
        if ( IsHashRefWithData($DoNotValidate)) {
            PATTERN:
            foreach my $Key ( keys %{$DoNotValidate} ) {
                foreach my $Pattern ( @{$DoNotValidate->{$Key}} ) {
                    if ( $Self->{RequestURI} =~ /^$Pattern$/ ) {
                        $DoValidate = 0;
                        last PATTERN;
                    }
                }
            }
        }
        if ( $DoValidate ) {
            # validate data
            my $ValidatorResult = $Self->{ValidatorObject}->Validate(
                Operation => $Self->{Operation},
                %Param
            );

            if ( !$ValidatorResult->{Success} ) {

                return $Self->_Error(
                    %{$ValidatorResult},
                );
            }
        }
    }

    if ( $Self->{AlteredRequestURI} && $Self->{CurrentRoute} =~ /:(.+?)$/ ) {
        # the RequestURI has been altered by the permission check
        # this can happen in case of multiple IDs with different permissions (the user has no permission to some of the items)
        $Param{Data}->{$1} = (split(/\//, $Self->{AlteredRequestURI}))[-1];
    }

    $Self->{BackendObject}->{PermissionCheckOnly} = $Param{PermissionCheckOnly};

    # start the backend
    my $Result = $Self->{BackendObject}->RunOperation(%Param);

    $Self->_Debug($Self->{LevelIndent}, sprintf("execution took %i ms", TimeDiff($StartTime)));

    return $Result;
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

=item _CheckPermission()

checks whether the user is allowed to execute this operation (Resource and Object types)

    my $Permission = $OperationObject->_CheckPermission(
        Authorization    => { },
    );

=cut

sub _CheckPermission {
    my ( $Self, %Param ) = @_;

    my $StartTime = Time::HiRes::time();

    $Self->_PermissionDebug($Self->{LevelIndent}, "permission check (Resource)");
    my $OldLevelIndent = $Self->{LevelIndent};
    $Self->{LevelIndent} .= '    ';

    my $RequestedPermission = Kernel::API::Operation::REQUEST_METHOD_PERMISSION_MAPPING->{$Self->{RequestMethod}};

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
        $Self->_PermissionDebug($Self->{LevelIndent}, "RequestURI: $Self->{RequestURI}, requested permission: $RequestedPermission --> permission denied by token");
        $Self->{LevelIndent} = $OldLevelIndent;
        return;
    }

    # split multiple (item) resources in the URI
    my ($Resource, $ResourceBase) = fileparse $Self->{RequestURI};
    my @Resources = split(/,/, $Resource);

    my $Granted = 0;
    my $AllowedPermission;
    my @GrantedResources;
    my $PermissionDebug = $Kernel::OM->Get('Config')->Get('Permission::Debug');

    foreach my $Resource ( @Resources ) {
        $Kernel::OM->Get('User')->{LevelIndent} = $Self->{LevelIndent};
        ($Granted, $AllowedPermission) = $Kernel::OM->Get('User')->CheckResourcePermission(
                UserID              => $Param{Authorization}->{UserID},
                UsageContext        => $Param{Authorization}->{UserType},
                Target              => $ResourceBase.$Resource,
                RequestedPermission => $RequestedPermission
        );

        if ( $PermissionDebug ) {
            my $AllowedPermissionShort = $Kernel::OM->Get('Role')->GetReadablePermissionValue(
                Value  => $AllowedPermission || 0,
                Format => 'Short'
            );

            $Self->_PermissionDebug($Self->{LevelIndent}, sprintf("RequestURI: %s, requested permission: %s, granted: %i, allowed permission: %s (0x%04x)", $ResourceBase.$Resource, $RequestedPermission, ($Granted || 0), $AllowedPermissionShort, ($AllowedPermission||0)));
        }

        if ( $Granted ) {
            # build new list of allowed (item) resources
            push(@GrantedResources, $Resource);
        }
    }

    # create a new RequestURI with granted resources if some of the item resources are denied
    if ( scalar(@Resources) > 1 && scalar(@GrantedResources) > 0 && scalar(@GrantedResources) < scalar(@Resources) ) {
        $Granted = 1;
        $Self->{AlteredRequestURI} = $ResourceBase.join(',', @GrantedResources);
        if ( $PermissionDebug ) {
            my $AllowedPermissionShort = $Kernel::OM->Get('Role')->GetReadablePermissionValue(
                Value  => $AllowedPermission || 0,
                Format => 'Short'
            );
            $Self->_PermissionDebug($Self->{LevelIndent}, sprintf("altered RequestURI: %s, requested permission: %s, granted: %i, allowed permission: %s (0x%04x)", $Self->{AlteredRequestURI}, $RequestedPermission, ($Granted || 0), $AllowedPermissionShort, ($AllowedPermission||0)));
        }
    }

    my @AllowedMethods;
    if ( $AllowedPermission ) {
        my %ReversePermissionMapping = reverse %Kernel::API::Operation::REQUEST_METHOD_PERMISSION_MAPPING;
        foreach my $Perm ( sort keys %Kernel::System::Role::Permission::PERMISSION ) {
            next if (($AllowedPermission & Kernel::System::Role::Permission::PERMISSION->{$Perm}) != Kernel::System::Role::Permission::PERMISSION->{$Perm});
            push(@AllowedMethods, $ReversePermissionMapping{$Perm});
        }
    }

    $Self->{LevelIndent} = $OldLevelIndent;
    $Self->_PermissionDebug($Self->{LevelIndent}, sprintf("permission check (Resource) for %s took %i ms", $Self->{RequestURI}, TimeDiff($StartTime)));

    # OPTIONS requests are always possible
    $Granted = 1 if ( $Self->{RequestMethod} eq 'OPTIONS' );

    return ($Granted, @AllowedMethods);
}

sub _Debug {
    my ( $Self, $Indent, $Message ) = @_;

    return if !$Kernel::OM->Get('Config')->Get('API::Debug');

    $Indent ||= '';

    printf STDERR "%f (%5i) %-15s %s%s: %s\n", Time::HiRes::time(), $$, "[API]", $Indent, $Self->{OperationConfig}->{Name}, "$Message";
}

sub _PermissionDebug {
    my ( $Self, $Indent, $Message ) = @_;

    return if !$Kernel::OM->Get('Config')->Get('Permission::Debug');

    $Indent ||= '';

    printf STDERR "%f (%5i) %-15s %s%s\n", Time::HiRes::time(), $$, "[Permission]", $Indent, $Message;
}

1;

=end Internal:



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
