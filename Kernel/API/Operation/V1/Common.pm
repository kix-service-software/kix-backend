# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Common;

use strict;
use warnings;
use File::Basename;
use Data::Sorting qw(:arrays);
use Storable;

BEGIN { $SIG{ __WARN__} = sub { return if $_[0] =~ /in cleanup/ }; }

use Kernel::System::Role::Permission;
use Kernel::System::VariableCheck qw(:all);
use Kernel::System::PerfLog qw(TimeDiff);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Common - Base class for all Operations

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
    for my $Needed ( qw(WebserviceID) ) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Type =~ /^.*?::(V1::.*?)$/;
    $Self->{Config} = $Kernel::OM->Get('Config')->Get('API::Operation::'.$1);

    return $Self;
}
=item RunOperation()

initialize and run the current operation

    my $Return = $CommonObject->RunOperation(
        Data => {
            ...
        }
    );

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        Code    => 123
        Message => 'Error Message',
        Data => {
            ...
        }
    }

=cut

sub RunOperation {
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

    # check user permissions based on property values
    # UserID 1 has God Mode if SecureMode isn't active
    # also ignore all this if we have been told to ignore permissions
    if ( !$Self->{IgnorePermissions} && $Self->{Authorization}->{UserID} && ( $Kernel::OM->Get('Config')->Get('SecureMode') || $Self->{Authorization}->{UserID} != 1 ) ) {

        # determine which method to use
        my $RequestMethodOrigin = $Param{RequestMethodOrigin};
        my $ParentCheckMethod = ($Param{RequestMethodOrigin} || $Self->{RequestMethod}) eq 'GET' ? 'GET' : 'PATCH';

        # if we don't have a
        if ( !$Self->{ParentMethodOperationMapping}->{$ParentCheckMethod} && $Self->{ParentMethodOperationMapping}->{GET} ) {
            $RequestMethodOrigin = $ParentCheckMethod if !$RequestMethodOrigin;
            $ParentCheckMethod = 'GET';
        }

        # if object to be created is a ticket and no queue id is given,
        # fallback from sysconfig needs to be set for later base permission check
        if ($Param{Data}->{Ticket} && !$Param{Data}->{Ticket}->{QueueID} && $Self->{RequestMethod} eq 'POST') {
            my $QueueObject = $Kernel::OM->Get('Queue');
            my $DefaultTicketQueue = $Kernel::OM->Get('Config')->Get('Ticket::Queue::Default');
            my %AllTicketQueues = reverse $QueueObject->QueueList();
            if ($AllTicketQueues{$DefaultTicketQueue}) {
                $Param{Data}->{Ticket}->{QueueID} = $AllTicketQueues{$DefaultTicketQueue};
            }
            else {
                return $Self->_Error(
                    Code => 'Object.UnableToCreate',
                );
            }
        }

        # check the necessary permission of the parent object if needed
        if ( !$Param{IgnoreParentPermissions} && IsHashRefWithData($Self->{ParentMethodOperationMapping}) && $Self->{ParentMethodOperationMapping}->{$ParentCheckMethod} ) {

            # get the config of the parent operation to determine the primary object ID attribute
            my $OperationConfig = $Kernel::OM->Get('Config')->Get('API::Operation::Module')->{$Self->{ParentMethodOperationMapping}->{$ParentCheckMethod}};

            my $Data = $OperationConfig->{ObjectID} ? {
                    $OperationConfig->{ObjectID} => $Param{Data}->{$OperationConfig->{ObjectID}},

                    # TODO: find generic solution ("AlwaysForwardAttributes" config?)
                    RelevantOrganisationID => $Param{Data}->{RelevantOrganisationID},
                } : $Param{Data};

            my $ExecResult = $Self->ExecOperation(
                RequestMethod         => $ParentCheckMethod,
                RequestMethodOrigin   => $RequestMethodOrigin,
                OperationType         => $Self->{ParentMethodOperationMapping}->{$ParentCheckMethod},
                Data                  => $Data,
                IgnoreInclude         => 1,       # we don't need any includes
                IgnoreExpand          => 1,       # we don't need any expands
                PermissionCheckOnly   => 1,       # do not change any data
            );

            if ( !IsHashRefWithData($ExecResult) || !$ExecResult->{Success} ) {
                return $Self->_Error(
                    Code => 'Object.NoPermission',
                );
            }
        }

        # check if we have permission for this object
        if ( $Self->can('GetBasePermissionObjectIDs') ) {
            my $StartTime = Time::HiRes::time();
            my $Result =  $Self->_CheckBasePermission(
                %Param,
                Data => $Param{Data},
            );
            $Self->_Debug($Self->{LevelIndent}, sprintf("permission check (Base) for $Self->{RequestURI} took %i ms", TimeDiff($StartTime)));

            if ( !$Result->{Success} ) {
                return $Result;
            }
        }

        # check if we have permission for this object
        my $StartTime = Time::HiRes::time();
        my $Result =  $Self->_CheckObjectPermission(
            %Param,
            Data => $Param{Data},
        );
        $Self->_Debug($Self->{LevelIndent}, sprintf("permission check (Object) for $Self->{RequestURI} took %i ms", TimeDiff($StartTime)));

        if ( !$Result->{Success} ) {
            return $Result;
        }

        # check if we have permission for specific properties of this object
        $StartTime = Time::HiRes::time();
        $Result =  $Self->_CheckPropertyPermission(
            %Param,
            Data => $Param{Data},
        );
        $Self->_Debug($Self->{LevelIndent}, sprintf("permission check (Property) for $Self->{RequestURI} took %i ms", TimeDiff($StartTime)));

        if ( !$Result->{Success} ) {
            return $Result;
        }
    }

    if ( $Self->{PermissionCheckOnly} && $Self->{RequestMethod} ne 'GET' ) {
        return $Self->_Success();
    }

    # get parameter definitions (if available)
    my $Parameters;
    if ( $Self->can('ParameterDefinition') ) {
        $Parameters = $Self->ParameterDefinition(
            %Param,
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => $Parameters,
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => $Result->{Message},
        );
    }

    # check cache if CacheType is set for this operation
    if ( $Kernel::OM->Get('Config')->Get('API::Cache') && $Self->{OperationConfig}->{CacheType} ) {

        # add own cache dependencies, if available
        if ( $Self->{OperationConfig}->{CacheTypeDependency} ) {
            $Self->AddCacheDependency( Type => $Self->{OperationConfig}->{CacheTypeDependency} );
        }

        my $CacheKey = $Self->_GetCacheKey();

        my $CacheResult = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{OperationConfig}->{CacheType},
            Key  => $CacheKey,
        );

        # FIXME: get specific object type for implicit paging
        if ( IsHashRefWithData($CacheResult) && !IsHashRefWithData($Self->{OperationConfig}->{ImplicitPagingFor})) {
            $Self->_Debug( $Self->{LevelIndent}, "return cached response (Key=$CacheKey)" );
            $Self->{'_CachedResponse'} = 1;
            $Result = $Self->_Success(
                %{$CacheResult}
            );
        }
    }

    # run the operation itself if we don't return a cached response
    if ( !$Self->{'_CachedResponse'} ) {

        # exec pre run method (if possible)
        if ($Self->can('PreRun')) {
            $Self->_Debug($Self->{LevelIndent}, "executing PreRun...");

            my $StartTime = Time::HiRes::time();

            my $PreRunResult = $Self->PreRun(
                %Param,
            );

            $Self->_Debug($Self->{LevelIndent}, sprintf("PreRun took %i ms", TimeDiff($StartTime)));

            if ( !$PreRunResult->{Success} ) {
                return $Self->_Error(
                    %{$PreRunResult},
                );
            }
        }

        $Result = $Self->Run(
            %Param,
        );

        # handle optional permissions
        if ( $Result->{Success} && $Self->{RequestMethod} =~ /^(PATCH|POST)$/g ) {
            OBJECT:
            foreach my $Object ( keys %{$Param{Data}} ) {
                next OBJECT if !IsHashRefWithData($Param{Data}->{$Object}) || !IsArrayRef($Param{Data}->{$Object}->{Permissions});
                $Self->_HandlePermissions(
                    ObjectID    => (values %{$Result->{Data}})[0],
                    Object      => $Object,
                    Data        => $Param{Data}->{$Object},
                    Permissions => $Param{Data}->{$Object}->{Permissions},
                );
            }
        }
    }

    # log created ID of POST requests
    if ( $Self->{RequestMethod} eq 'POST' && IsHashRefWithData($Result) && $Result->{Success} ) {
        my @Data = %{ $Result->{Data} || {} };
        $Self->_Debug( $Self->{LevelIndent}, "created new item (" . join( '=', @Data ) . ")" );
    }

    return $Result
}

=item Options()

initialize and gather information about the operation

    my $Return = $CommonObject->Options();

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        Code    => 123
        Message => 'Error Message',
        Data => {
            ...
        }
    }

=cut

sub Options {
    my ( $Self, %Param ) = @_;
    my %Data;

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

    # get parameter definitions (if available)
    my $Parameters;
    if ( $Self->can('ParameterDefinition') ) {
        $Parameters = $Self->ParameterDefinition(
            %Param,
        );

        if ( IsHashRefWithData($Parameters) ) {

            # add parameter information to result
            $Data{Parameters} = $Parameters;
        }
    }

    $Self->_AddSchemaAndExamples(Data => \%Data);

    return $Self->_Success(
        IsOptionsResponse => 1,
        %Data
    );
}

=item Init()

initialize the operation by checking the webservice configuration

    my $Return = $CommonObject->Init(
        WebserviceID => 1,
    );

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        Message => 'Error Message',
    }

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # check needed
    if ( !$Param{WebserviceID} ) {
        return $Self->_Error(
            Code    => 'Webservice.InternalError',
            Message => "Got no WebserviceID!",
        );
    }

    # get webservice configuration
    my $Webservice = $Kernel::OM->Get('Webservice')->WebserviceGet(
        ID => $Param{WebserviceID},
    );

    if ( !IsHashRefWithData($Webservice) ) {
        return $Self->_Error(
            Code    => 'Webservice.InternalError',
            Message => 'Could not determine Web service configuration in Kernel::API::Operation::V1::Common::Init()',
        );
    }

    $Self->{CacheKeyExtensions} = [];

    # Search parameter is not handled in API by default
    $Self->{HandleSearchInAPI} = 0;

    # Sort parameter is not handled in Core by default
    $Self->{HandleSortInCORE} //= 0;

    # calculate LevelIndent for Logging
    $Self->{Level} = $Self->{Level} || 0;

    $Self->{LevelIndent} = '    ' x $Self->{Level} || '';

    return $Self->_Success();
}

=item PrepareData()

prepare data, check given parameters and parse them according to type

    my $Return = $CommonObject->PrepareData(
        Data   => {
            ...
        },
        Parameters => {
            <Parameter> => {                                            # if Parameter is a attribute of a hashref, just separate it by ::, i.e. "User::UserLogin"
                Type                => 'ARRAY' | 'ARRAYtoHASH | HASH',  # optional, use this to parse a comma separated string into an array or a hash with all array entries as keys and 1 as values or a JSON string into a HASH
                DataType            => 'NUMERIC',                       # optional, use this to force numeric datatype in JSON response
                Required            => 1,                               # optional
                RequiredIfNot       => [ '<AltParameter>', ... ]        # optional, specify the alternate parameters to be checked, if one of them has a value
                RequiredIf          => [ '<Parameter>', ... ]           # optional, specify the parameters that should be checked for values
                RequiresValueIfUsed => 1                                # optional
                Default             => ...                              # optional
                OneOf               => [...]                            # optional
                AnyOf               => [...]                            # optional
                Format              => '...'                            # optional, RegEx that defines the format pattern
            }
        }
    );

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        Message => 'Error Message',
    }

=cut

sub PrepareData {
    my ( $Self, %Param ) = @_;
    my $Result = {
        Success => 1
    };

    $Param{Data} //= {};

    # prepare filter
    if ( exists( $Param{Data}->{filter} ) ) {
        my $Result = $Self->_ValidateFilter(
            Filter => $Param{Data}->{filter},
            Type   => 'filter',
        );
        if ( IsHashRefWithData($Result) && exists $Result->{Success} && $Result->{Success} == 0 ) {

            # error occurred
            return $Result;
        }
        $Self->{Filter} = $Result;
    }

    # prepare search
    if ( exists( $Param{Data}->{search} ) ) {

        # we use the same syntax like the filter, so we can you the same validation method
        my $Result = $Self->_ValidateFilter(
            Filter => $Param{Data}->{search},
            Type   => 'search',
        );
        if ( IsHashRefWithData($Result) && exists $Result->{Success} && $Result->{Success} == 0 ) {

            # error occured
            return $Result;
        }
        $Self->{Search} = $Result;
    }

    # prepare field selector
    if ( ( exists( $Param{Data}->{fields} ) && IsStringWithData( $Param{Data}->{fields} ) ) || IsStringWithData( $Self->{OperationConfig}->{'FieldSet::Default'} ) ) {
        my $FieldSet = $Param{Data}->{fields} || ':Default';
        if ( $FieldSet =~ /^:(.*?)/ ) {

            # get pre-defined FieldSet
            $FieldSet = $Self->{OperationConfig}->{ 'FieldSet:' . $FieldSet };
        }
        foreach my $FieldSelector ( split( /,/, $FieldSet ) ) {
            my ( $Object, $Field ) = split( /\./, $FieldSelector, 2 );
            if ( $Field =~ /^\[(.*?)\]$/g ) {
                my @Fields = map { { Field => $_ } } split( /\s*;\s*/, $1 );
                $Self->{Fields}->{$Object} = \@Fields;
            }
            else {
                if ( !IsArrayRefWithData( $Self->{Fields}->{$Object} ) ) {
                    $Self->{Fields}->{$Object} = [];
                }
                push @{ $Self->{Fields}->{$Object} }, { Field => $Field };
            }
        }
    }

    #prepare limiter and searchlimit
    foreach my $LimitType ( qw(Limit SearchLimit) ) {
        if ( exists( $Param{Data}->{lc($LimitType)} ) && IsStringWithData( $Param{Data}->{lc($LimitType)} ) ) {
            foreach my $Limiter ( split( /,/, $Param{Data}->{lc($LimitType)} ) ) {
                my ( $Object, $Limit ) = split( /\:/, $Limiter, 2 );
                if ( $Limit && $Limit =~ /^\d+$/ ) {
                    $Self->{$LimitType}->{$Object} = $Limit;
                }
                else {
                    $Self->{$LimitType}->{__COMMON} = $Object;
                }
            }
        }
        else {
            my $Limit = $Kernel::OM->Get('Config')->Get('API::Request::DefaultLimit') || 0;
            $Self->{$LimitType}->{__COMMON} = $Limit;
        }
    }

    # prepare offset
    if ( exists( $Param{Data}->{offset} ) && IsStringWithData( $Param{Data}->{offset} ) ) {
        foreach my $Offset ( split( /,/, $Param{Data}->{offset} ) ) {
            my ( $Object, $Index ) = split( /\:/, $Offset, 2 );
            if ( $Index && $Index =~ /^\d+$/ ) {
                $Self->{Offset}->{$Object} = $Index;
            }
            else {
                $Self->{Offset}->{__COMMON} = $Object;
            }
        }
    }

    # prepare sorter
    if ( exists( $Param{Data}->{sort} ) && IsStringWithData( $Param{Data}->{sort} ) ) {
        foreach my $Sorter ( split( /,/, $Param{Data}->{sort} ) ) {
            my ( $Object, $FieldSort ) = split( /\./, $Sorter, 2 );
            my ( $Field, $Type ) = split( /\:/, $FieldSort );
            my $Direction = 'ascending';
            $Type = uc( $Type || 'TEXTUAL' );

            # check if sort type is valid
            if ( $Type && $Type !~ /(NUMERIC|TEXTUAL|NATURAL|DATE|DATETIME)/g ) {
                return $Self->_Error(
                    Code    => 'PrepareData.InvalidSort',
                    Message => "Unknown type $Type in $Sorter!",
                );
            }

            # should we sort ascending or descending
            if ( $Field =~ /^-(.*?)$/g ) {
                $Field     = $1;
                $Direction = 'descending';
            }

            if ( !IsArrayRefWithData( $Self->{Sort}->{$Object} ) ) {
                $Self->{Sort}->{$Object} = [];
            }
            push @{ $Self->{Sort}->{$Object} }, {
                Field     => $Field,
                Direction => $Direction,
                Type      => ( $Type || 'cmp' )
            };
        }
    }

    my %Data = %{ $Param{Data} };

    # store data for later use
    $Self->{RequestData} = \%Data;

    # prepare Parameters
    my %Parameters;
    if ( IsHashRefWithData( $Param{Parameters} ) ) {
        %Parameters = %{ $Param{Parameters} };
    }

    # always add include and expand parameter if given
    if ( $Param{Data}->{include} ) {
        $Parameters{'include'} = {
            Type => 'ARRAYtoHASH',
        };
    }
    if ( $Param{Data}->{expand} ) {
        $Parameters{'expand'} = {
            Type => 'ARRAYtoHASH',
        };
    }

    # if needed flatten hash structure for easier access to sub structures
    if (%Parameters) {

        if ( grep( /::/, keys %Parameters ) ) {

            my $FlatData = $Kernel::OM->Get('Main')->Flatten(
                Data          => $Param{Data},
                HashDelimiter => '::',
            );

            # add pseudo entries for substructures for requirement checking
            foreach my $Entry ( keys %{$FlatData} ) {

                while ( split( /::/, $Entry ) > 2 ) {
                    my @Parts = split( /::/, $Entry );
                    pop(@Parts);
                    my $DummyKey = join( '::', @Parts );
                    $Entry = $DummyKey;    # prepare next iteration

                    next if exists( $FlatData->{$DummyKey} );
                    $FlatData->{$DummyKey} = {};
                }
            }

            # combine flattened array for requirement checking
            foreach my $Entry ( keys %{$FlatData} ) {
                next if $Entry !~ /^(.*?):\d+/g;

                $FlatData->{$1} = [];
            }

            %Data = (
                %Data,
                %{$FlatData},
            );
        }

        foreach my $Parameter ( sort keys %Parameters ) {

            # check requirement
            if ( $Parameters{$Parameter}->{Required} && !defined( $Data{$Parameter} ) ) {
                $Result->{Success} = 0;
                $Result->{Message} = "Required parameter $Parameter is missing or undefined!",
                    last;
            }
            elsif ( $Parameters{$Parameter}->{RequiredIfNot} && ref( $Parameters{$Parameter}->{RequiredIfNot} ) eq 'ARRAY' ) {
                my $AltParameterHasValue = 0;
                foreach my $AltParameter ( @{ $Parameters{$Parameter}->{RequiredIfNot} } ) {
                    if ( exists( $Data{$AltParameter} ) && defined( $Data{$AltParameter} ) ) {
                        $AltParameterHasValue = 1;
                        last;
                    }
                }
                if ( !exists( $Data{$Parameter} ) && !$AltParameterHasValue ) {
                    $Result->{Success} = 0;
                    $Result->{Message} = "Required parameter $Parameter or " . ( join( " or ", @{ $Parameters{$Parameter}->{RequiredIfNot} } ) ) . " is missing or undefined!",
                        last;
                }
            }

            # check complex requirement (required if another parameter has value)
            if ( $Parameters{$Parameter}->{RequiredIf} && ref( $Parameters{$Parameter}->{RequiredIf} ) eq 'ARRAY' ) {
                my $OtherParameterHasValue = 0;
                foreach my $OtherParameter ( @{ $Parameters{$Parameter}->{RequiredIf} } ) {
                    if ( exists( $Data{$OtherParameter} ) && defined( $Data{$OtherParameter} ) ) {
                        $OtherParameterHasValue = 1;
                        last;
                    }
                }
                if ( !exists( $Data{$Parameter} ) && $OtherParameterHasValue ) {
                    $Result->{Success} = 0;
                    $Result->{Message} = "Required parameter $Parameter is missing!",
                    last;
                }
            }

            # parse into arrayref if parameter value is scalar and ARRAY type is needed
            if ( $Parameters{$Parameter}->{Type} && $Parameters{$Parameter}->{Type} =~ /(ARRAY|ARRAYtoHASH)/ && $Data{$Parameter} && ref( $Data{$Parameter} ) ne 'ARRAY' ) {
                my @Values = split( '\s*,\s*', $Data{$Parameter} );
                if ( $Parameters{$Parameter}->{DataType} && $Parameters{$Parameter}->{DataType} eq 'NUMERIC' ) {
                    @Values = map { 0 + $_ } @Values;
                }
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                    Value     => \@Values,
                );
            }

            # convert array to hash if we have to
            if ( $Parameters{$Parameter}->{Type} && $Parameters{$Parameter}->{Type} eq 'ARRAYtoHASH' && $Data{$Parameter} && ref( $Param{Data}->{$Parameter} ) eq 'ARRAY' ) {
                my %NewHash = map { $_ => 1 } @{ $Param{Data}->{$Parameter} };
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                    Value     => \%NewHash,
                );
            }

            # convert string to hash if we have to
            if ( $Parameters{$Parameter}->{Type} && $Parameters{$Parameter}->{Type} eq 'HASH' && $Data{$Parameter} && IsString( $Param{Data}->{$Parameter} ) ) {
                my $Object = $Kernel::OM->Get('JSON')->Decode(
                    Data => $Param{Data}->{$Parameter},
                );
                if ( !$Object )  {
                    $Result->{Success} = 0;
                    $Result->{Message} = "Parameter $Parameter is not a valid JSON object!",
                    last;
                }
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                    Value     => $Object,
                );
            }


            # set default value
            if ( !$Data{$Parameter} && exists( $Parameters{$Parameter}->{Default} ) ) {
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                    Value     => $Parameters{$Parameter}->{Default},
                );
            }

            # check if we have an optional parameter that needs a value
            if ( $Parameters{$Parameter}->{RequiresValueIfUsed} && exists( $Data{$Parameter} ) && !defined( $Data{$Parameter} ) ) {
                $Result->{Success} = 0;
                $Result->{Message} = "Optional parameter $Parameter is used without a value!",
                    last;
            }

            # check valid values
            if ( exists( $Data{$Parameter} ) && exists( $Parameters{$Parameter}->{OneOf} ) && ref( $Parameters{$Parameter}->{OneOf} ) eq 'ARRAY' ) {
                if ( !grep( /^$Data{$Parameter}$/g, @{ $Parameters{$Parameter}->{OneOf} } ) ) {
                    $Result->{Success} = 0;
                    $Result->{Message} = "Parameter $Parameter is not one of '" . ( join( ',', @{ $Parameters{$Parameter}->{OneOf} } ) ) . "'!",
                        last;
                }
            }
            if ( exists( $Data{$Parameter} ) && exists( $Parameters{$Parameter}->{Format} ) ) {
                if ( $Data{$Parameter} !~ /$Parameters{$Parameter}->{Format}/g ) {
                    $Result->{Success} = 0;
                    $Result->{Message} = "Parameter $Parameter has the wrong format!",
                        last;
                }
            }

            # check if we have an optional parameter that needs a value
            if ( $Parameters{$Parameter}->{RequiresValueIfUsed} && exists( $Data{$Parameter} ) && !defined( $Data{$Parameter} ) ) {
                $Result->{Success} = 0;
                $Result->{Message} = "Optional parameter $Parameter is used without a value!",
                    last;
            }
        }
    }

    # store include and expand for later
    $Self->{Include} = $Param{Data}->{include} || {};
    $Self->{Expand}  = $Param{Data}->{expand}  || {};

    return $Result;
}

=item SuppressSubResourceInclude()

suppress a sub-resource include if it's already done somewhere else (due to performance reasons etc.)

    $CommonObject->SuppressSubResourceInclude(
        SubResource => '...'
    );

=cut

sub SuppressSubResourceInclude {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(SubResource)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'SuppressSubResourceInclude.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    foreach my $SubResource ( split( /,/, $Param{SubResource} ) ) {

        if ( exists $Self->{SuppressedSubResourceIncludes}->{$SubResource} ) {
            next;
        }
        $Self->_Debug( $Self->{LevelIndent}, "suppress including of sub-resource \"$SubResource\"" );
        $Self->{SuppressSubResourceIncludes}->{lc($SubResource)} = 1;
    }
}

=item IncludeSubResourceIfProperty()

include a sub-resource only if a property exists and has a true value (due to performance reasons etc.)

    $CommonObject->IncludeSubResourceIfProperty(
        SubResource => '...',
        Property    => '...'
    );

=cut

sub IncludeSubResourceIfProperty {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(SubResource Property)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'IncludeSubResourceIfProperty.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    foreach my $SubResource ( split( /,/, $Param{SubResource} ) ) {

        if ( exists $Self->{IncludeSubResourceIfProperty}->{$SubResource} ) {
            next;
        }
        $Self->_Debug( $Self->{LevelIndent}, "including sub-resource \"$SubResource\" only if property \"$Param{Property}\"" );
        $Self->{IncludeSubResourceIfProperty}->{lc($SubResource)} = $Param{Property};
    }
}

=item AddCacheDependency()

add a new cache dependency to inform the system about foreign depending objects included in the response

    $CommonObject->AddCacheDependency(
        Type => '...'
    );

=cut

sub AddCacheDependency {
    my ( $Self, %Param ) = @_;

    # if the operation has no CacheType configured, ignore the additional dependencies but log an error
    if ( !$Self->{OperationConfig}->{CacheType} ) {
        $Self->_Error(
            Code    => 'AddCacheDependency.NoCacheType',
            Message => "Should add cache dependencies but no CacheType has been configured for this operation!",
        );
        return;
    }

    # check needed stuff
    for my $Needed (qw(Type)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'AddCacheDependency.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    foreach my $Type ( split( /,/, $Param{Type} ) ) {

        # ignore the same type as dependency
        next if $Type eq $Self->{OperationConfig}->{CacheType};

        if ( exists $Self->{CacheDependencies}->{$Type} ) {
            next;
        }
        $Self->_Debug( $Self->{LevelIndent}, "adding cache type dependencies to type \"$Self->{OperationConfig}->{CacheType}\": $Type" );
        $Self->{CacheDependencies}->{$Type} = 1;
    }
}

=item AddCacheKeyExtension()

add an extension to the cache key used to cache this request

    $CommonObject->AddCacheKeyExtension(
        Extension => []
    );

=cut

sub AddCacheKeyExtension {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Extension)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'AddCacheKeyExtension.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    if ( !IsArrayRefWithData( $Param{Extension} ) ) {
        return $Self->_Error(
            Code    => 'AddCacheKeyExtension.WringParameter',
            Message => "Extension is not an array reference!",
        );
    }

    foreach my $Extension ( @{ $Param{Extension} } ) {
        push( @{ $Self->{CacheKeyExtensions} }, $Extension );
    }
}

=item SetDefaultSort()

suppress a sub-resource include if it's already done somewhere else (due to performance reasons etc.)

    $CommonObject->SetDefaultSort(
        Ticket => [
            {
                Field     => 'Title',
                Direction => 'descending',      # optional, default: ascending
                Type      => 'NATURAL',         # optional, default: TEXTUAL
            }
        ]
    );

=cut

sub SetDefaultSort {
    my ( $Self, %Param ) = @_;

    foreach my $Object ( keys %Param ) {
        foreach my $SortItem ( @{$Param{$Object}} ) {
            if ( !$SortItem->{Field} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Default filter for \"$Object\" contains not \"Field\" property!",
                );
                return 0;
            }
            $SortItem->{Type} = 'cmp' if !$SortItem->{Type};
            $SortItem->{Direction} = 'ascending' if !$SortItem->{Direction};
        }
    }

    $Self->{DefaultSort} = \%Param;

    return 1;
}

=item SetTotalItemCount()

set the total item count for specific object types (can be used in conjunction with implicit paging)

    $CommonObject->SetTotalItemCount(
        Ticket => 123,
    );

=cut

sub SetTotalItemCount {
    my ( $Self, %Param ) = @_;

    $Self->{TotalItemCount} //= {};

    foreach my $Object ( keys %Param ) {
        $Self->{TotalItemCount}->{$Object} = $Param{$Object},
    }

    return 1;
}

=item HandleSearchInAPI()

Tell the API core to handle the "search" parameter in the API. This is needed for operations that don't handle the "search" parameter and leave the work to the API core.

    $CommonObject->HandleSearchInAPI();

=cut

sub HandleSearchInAPI {
    my ( $Self, %Param ) = @_;

    $Self->{HandleSearchInAPI} = 1;
}

=item HandleSortInCORE()

Tell the API to handle the "sort" parameter in the CORE. This is needed for operations that don't handle the "sort" parameter and leave the work to the CORE.

    $CommonObject->HandleSortInCORE();

=cut

sub HandleSortInCORE {
    my ( $Self, %Param ) = @_;

    $Self->{HandleSortInCORE} = 1;
}

=item ApplyPaging()

Apply the relevant limit and offset to the given data.

    $CommonObject->ApplyPaging(
        Ticket => [...],
    );

=cut

sub ApplyPaging {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( \%Param ) ) {

        # nothing to do
        return;
    }

    my %Data = (
        Data => \%Param,
    );

    $Self->_Debug($Self->{LevelIndent}, "applying paging...");

    my $StartTime = Time::HiRes::time();

    if ( IsHashRefWithData( $Self->{Offset} ) ) {
        $Self->_ApplyOffset(
            %Data,
            Force => 1,
        );
    }

    if ( IsHashRefWithData( $Self->{Limit} ) ) {
        $Self->_ApplyLimit(
            %Data,
            Force => 1,
        );
    }

    $Self->_Debug($Self->{LevelIndent}, sprintf("applying paging took %i ms", TimeDiff($StartTime)));

    return %Param;
}

=item _HandlePermissions()

Handle the optional "Permissions" property

    $CommonObject->_HandlePermissions(
        ObjectID    => 123,
        Object      => 'Queue',
        Data        => {...},
        Permissions => [],
    );

=cut

sub _HandlePermissions {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ObjectID Object Data Permissions)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my @BasePermissions;
    PERMISSION:
    foreach my $Permission ( @{$Param{Permissions}} ) {
        next PERMISSION if $Permission->{Type} ne 'Base';

        if ( !$Permission->{RoleID} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "RoleID missing in Permission!"
            );
            return;
        }
        push @BasePermissions, $Permission;
    }

    my $HandlerObject = $Kernel::OM->Get($Param{Object});

    if ( !$HandlerObject || !$HandlerObject->can('UpdateBasePermissions') ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No base permission handler for \"$Param{Object}\"!",
        );
        return;
    }

    my $Success = $HandlerObject->UpdateBasePermissions(
        ObjectID       => $Param{ObjectID},
        PermissionList => \@BasePermissions,
        UserID         => $Self->{Authorization}->{UserID},
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Base permission handler for \"Param{Object}\" returned error !",
        );
        return;
    }

    return 1;
}

=item _Success()

helper function to return a successful result.

    my $Return = $CommonObject->_Success(
        ...
    );

=cut

sub _Success {
    my ( $Self, %Param ) = @_;
    my %Headers = %{$Param{AdditionalHeaders}||{}};

    delete $Param{AdditionalHeaders};

    # ignore cached values if we have a cached response (see end of Init method)

    # handle Search parameter if we have to
    if ( !$Param{IsOptionsResponse} ) {
        # cache request if CacheType is set for this operation
        if ( $Kernel::OM->Get('Config')->Get('API::Cache') && !$Self->{'_CachedResponse'} && IsHashRefWithData( \%Param ) && $Self->{OperationConfig}->{CacheType} ) {
            $Self->_CacheRequest(
                Data => \%Param,
            );
        }

        # honor base permissions
        if ( IsHashRefWithData( \%Param ) && IsHashRefWithData( $Self->{BasePermissionFilter} ) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_Debug($Self->{LevelIndent}, "applying base permission");

            my $FilterResult = $Self->_ApplyFilter(
                Data               => \%Param,
                Filter             => $Self->{BasePermissionFilter},
                IsPermissionFilter => 1,
            );

            $Self->_Debug($Self->{LevelIndent}, sprintf("permission filtering took %i ms", TimeDiff($StartTime)));

            if ( $Self->{RequestMethod} eq 'GET' && IsHashRefWithData($FilterResult) ) {
                foreach my $Object ( sort keys %{$FilterResult} ) {
                    if ( $FilterResult->{$Object} == 0 && !defined $Param{$Object} ) {
                        # we have a single object and no permission, return a forbidden
                        $Self->_PermissionDebug($Self->{LevelIndent},  sprintf("object doesn't match the required criteria - denying request") );

                        # return 403, because we don't have permission to execute this
                        return $Self->_Error(
                            Code => 'Forbidden',
                        );
                    }
                }
            }
        }

        # honor object permissions
        if ( IsHashRefWithData( \%Param ) && IsArrayRefWithData( $Self->{RelevantObjectPermissions} ) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_Debug($Self->{LevelIndent}, "applying object permissions");

            my $Result = $Self->_ApplyObjectPermissions(
                Data => \%Param,
            );
            if ( IsHashRefWithData($Result) && !$Result->{Success} ) {
                return $Result;
            }

            $Self->_Debug($Self->{LevelIndent}, sprintf("permission filtering took %i ms", TimeDiff($StartTime)));
        }

        if ( $Self->{HandleSearchInAPI} && IsHashRefWithData( $Self->{Search} ) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_ApplyFilter(
                Data   => \%Param,
                Filter => $Self->{Search}
            );

            $Self->_Debug($Self->{LevelIndent}, sprintf("search in API layer took %i ms", TimeDiff($StartTime)));
        }

        # add header
        my $TotalCount;
        OBJECT:
        foreach my $Object ( sort keys %Param ) {
            next OBJECT if !IsArrayRef($Param{$Object});
            if ( $Self->{TotalItemCount}->{$Object} ) {
                $Headers{'X-Total-Count-'.$Object} = $Self->{TotalItemCount}->{$Object};
                $TotalCount += $Self->{TotalItemCount}->{$Object};
            }
            else {
                my $Count = scalar @{$Param{$Object}};
                $Headers{'X-Total-Count-'.$Object} = $Count;
                $TotalCount += $Count;
            }
        }
        $Headers{'X-Total-Count'} = $TotalCount if defined $TotalCount;

        # apply offset and limit only for collections
        if ( !$Self->{PermissionCheckOnly} && !IsHashRefWithData($Self->{OperationConfig}->{ImplicitPagingFor}) && $Self->{OperationRouteMapping}->{$Self->{OperationType}} !~ /\/:\w+$/ ) {
            # honor an offset, if we have one
            if ( IsHashRefWithData( $Self->{Offset} ) ) {
                my $StartTime = Time::HiRes::time();

                $Self->_ApplyOffset(
                    Data => \%Param,
                );

                $Self->_Debug($Self->{LevelIndent}, sprintf("applying offset took %i ms", TimeDiff($StartTime)));
            }

            # honor a limiter, if we have one
            if ( IsHashRefWithData( $Self->{Limit} ) ) {
                my $StartTime = Time::HiRes::time();

                $Self->_ApplyLimit(
                    Data => \%Param,
                );

                $Self->_Debug($Self->{LevelIndent}, sprintf("applying limit took %i ms", TimeDiff($StartTime)));
            }
        }

        # honor a filter, if we have one
        if ( IsHashRefWithData( $Self->{Filter} ) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_ApplyFilter(
                Data => \%Param,
            );

            $Self->_Debug($Self->{LevelIndent}, sprintf("filtering took %i ms", TimeDiff($StartTime)));
        }

        # honor a sorter, if we have one
        if (
            !$Self->{HandleSortInCORE}
            && IsHashRefWithData( $Self->{Sort} )
        ) {
            my $StartTime = Time::HiRes::time();

            $Self->_ApplySort(
                Data => \%Param,
            );

            $Self->_Debug($Self->{LevelIndent}, sprintf("sorting took %i ms", TimeDiff($StartTime)));
        }

        # honor a field selector, if we have one
        if ( IsHashRefWithData( $Self->{Fields} ) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_ApplyFieldSelector(
                Data   => \%Param,
                Fields => $Self->{Fields},
            );

            $Self->_Debug($Self->{LevelIndent}, sprintf("field selection took %i ms", TimeDiff($StartTime)));
        }

        if ( !$Self->{PermissionCheckOnly} ) {

            # honor a generic include, if we have one
            if ( IsHashRefWithData( $Self->{Include} ) ) {
                my $StartTime = Time::HiRes::time();

                $Self->_ApplyInclude(
                    Data => \%Param,
                );

                $Self->_Debug($Self->{LevelIndent}, sprintf("including took %i ms", TimeDiff($StartTime)));
            }

            # honor an expander, if we have one
            if ( IsHashRefWithData( $Self->{Expand} ) ) {
                my $StartTime = Time::HiRes::time();

                $Self->_ApplyExpand(
                    Data => \%Param,
                );

                $Self->_Debug($Self->{LevelIndent}, sprintf("expanding took %i ms", TimeDiff($StartTime)));
            }

        }

        # honor a permission field selector, if we have one - make sure nothing gets out what should not get out
        if ( IsHashRefWithData($Self->{PermissionFieldSelector}) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_Debug($Self->{LevelIndent}, "applying permission field selector");

            $Self->_ApplyFieldSelector(
                Data                       => \%Param,
                Fields                     => $Self->{PermissionFieldSelector},
                IsPermissionFieldSelection => 1
            );

            $Self->_Debug($Self->{LevelIndent}, sprintf("permission field selection took %i ms", TimeDiff($StartTime)));
        }
    }

    # prepare result
    my $Code    = $Param{Code};
    my $Message = $Param{Message};
    delete $Param{Code};
    delete $Param{Message};
    delete $Param{IsOptionsResponse};

    # return structure
    my $Result = {
        Success => 1,
        Code    => $Code,
        Message => $Message,
    };
    if ( IsHashRefWithData( \%Headers )) {
        $Result->{Additional}->{AddHeader} = \%Headers
    }
    if ( IsHashRefWithData( \%Param ) ) {
        $Result->{Data} = {
            %Param
        };
    }

    return $Result;
}

=item _Error()

helper function to return an error message.

    my $Return = $CommonObject->_Error(
        Code    => Ticket.AccessDenied,
        Message => 'You don't have rights to access this ticket',
    );

=cut

sub _Error {
    my ( $Self, %Param ) = @_;

    my $Message = $Param{Message};

    if ( !$Message ) {
        # get the last error log entry as the message if we don't have one
        $Message = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
    }

    # return structure
    return {
        Success => 0,
        Code    => $Param{Code},
        Message => $Message,
    };
}

=item ExecOperation()

helper function to execute another operation to work with its result.

    my $Return = $CommonObject->ExecOperation(
        OperationType            => '...',                              # required
        Data                     => {},                                 # optional
        IgnorePermissions        => 1,                                  # optional
        SuppressPermissionErrors => 1,                                  # optional
        IgnoreInclude            => 1,                                  # optional
        IgnoreExpand             => 1,                                  # optional
        PermissionCheckOnly      => 1,                                  # optional
        ApplyPaging              => ['TicketID'],                       # optional, apply paging to attribute
    );

=cut

sub ExecOperation {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(OperationType)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'ExecOperation.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    # get webservice config
    my $Webservice = $Kernel::OM->Get('Webservice')->WebserviceGet(
        ID => $Self->{WebserviceID},
    );
    if ( !IsHashRefWithData($Webservice) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Could not load web service configuration for web service with ID $Self->{WebserviceID}",
        );

        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "Could not load web service configuration for web service with ID $Self->{WebserviceID}!",
        );
    }
    my $TransportConfig = $Webservice->{Config}->{Provider}->{Transport}->{Config};

    # prepare RequestURI
    my $RequestURI = $TransportConfig->{RouteOperationMapping}->{$Param{OperationType}}->{Route};
    my $CurrentRoute = $RequestURI;
    $RequestURI =~ s/:(\w*)/$Param{Data}->{$1}/egx;

    # TODO: the following code is nearly identical to the code used in Transport::REST, method ProcessRequest -> should be generalized
    # maybe another solution to execute operations / API calls is needed

    # get direct sub-resource for generic including
    my %OperationRouteMapping = (
        $Param{OperationType} => $CurrentRoute
    );

    # determine parent mapping as well
    my $ParentObjectRoute = $CurrentRoute;
    $ParentObjectRoute =~ s/^((.*?):(\w+))\/(.+?)$/$1/g;
    $ParentObjectRoute = '' if $ParentObjectRoute eq $CurrentRoute;
    my %ParentMethodOperationMapping;

    # determine available methods
    my %AvailableMethods;
    for my $Op ( sort keys %{ $TransportConfig->{RouteOperationMapping} } ) {

        my %RouteMapping = %{ $TransportConfig->{RouteOperationMapping}->{$Op} || {} };
        my $RouteRegEx = $RouteMapping{Route};
        $RouteRegEx =~ s{:([^\/]+)}{(?<$1>[^\/]+)}xmsg;

        if ( $ParentObjectRoute ) {
            # ignore anything that has nothing to do with the parent Ops route
            if ( $ParentObjectRoute ne '/' && "$RouteMapping{Route}/" !~ /^$ParentObjectRoute\/$/ ) {
                # do nothing
            }
            elsif ( $ParentObjectRoute eq '/' && "$RouteMapping{Route}/" !~ /^$ParentObjectRoute[:a-zA-Z_]+$\//g ) {
                # do nothing
            }
            else {
                my $Method = $TransportConfig->{RouteOperationMapping}->{$Op}->{RequestMethod}->[0];
                $ParentMethodOperationMapping{$Method} = $Op;
            }
        }

        if ( $RequestURI =~ m{^ $RouteRegEx $}xms ) {
            $AvailableMethods{ $RouteMapping{RequestMethod}->[0] } = {
                Operation => $Op,
                Route     => $RouteMapping{Route}
            };
        }

        # ignore non-search or -get operations
        next if $Op !~ /(Search|Get)$/;

        # ignore anything that has nothing to do with the current Ops route
        if ( $CurrentRoute ne '/' && "$TransportConfig->{RouteOperationMapping}->{$Op}->{Route}/" !~ /^$CurrentRoute\// ) {
            next;
        }
        elsif ( $CurrentRoute eq '/' && "$TransportConfig->{RouteOperationMapping}->{$Op}->{Route}/" !~ /^$CurrentRoute[:a-zA-Z_]+\/$/g ) {
            next;
        }

        $OperationRouteMapping{$Op} = $TransportConfig->{RouteOperationMapping}->{$Op}->{Route};

    }

    # init new Operation object
    my $OperationModule = $Kernel::OM->GetModuleFor('API::Operation');
    if ( !$Kernel::OM->Get('Main')->Require($OperationModule) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message => "Can't load module $OperationModule",
        );
        return;    # bail out, this will generate 500 Error
    }

    my $OperationObject = $OperationModule->new(
        CallingOperationType     => $Self->{OperationType},
        Operation                => (split(/::/, $Param{OperationType}))[-1],
        OperationType            => $Param{OperationType},
        WebserviceID             => $Self->{WebserviceID},
        RequestMethod            => $Param{RequestMethod} || $Self->{RequestMethod},
        RequestMethodOrigin      => $Param{RequestMethodOrigin},
        AvailableMethods         => \%AvailableMethods,
        RequestURI               => $RequestURI,
        CurrentRoute             => $CurrentRoute,
        OperationRouteMapping    => \%OperationRouteMapping,
        ParentMethodOperationMapping => \%ParentMethodOperationMapping,
        Authorization            => $Self->{Authorization},
        Level                    => ($Self->{Level} || 0) + 1,
        SuppressPermissionErrors => $Param{SuppressPermissionErrors},
        IgnorePermissions        => $Param{IgnorePermissions},
        SuppressPermissionErrors => $Param{SuppressPermissionErrors},
        HandleSortInCORE         => $Self->{HandleSortInCORE},
        IgnoreValidators         => 1,                                  # always ignore validators in internal API calls
    );

    # if operation init failed, bail out
    if ( ref $OperationObject ne $OperationModule ) {
        return $Self->_Error(
            %{$OperationObject},
        );
    }

    $Self->_Debug( $Self->{LevelIndent}, "executing operation $OperationObject->{OperationConfig}->{Name}" );

    # check and prepare additional data
    my %AdditionalData;
    if ( $OperationObject->{OperationConfig}->{AdditionalUriParameters} ) {
        foreach my $AddParam ( sort split(/\s*,\s*/, $OperationObject->{OperationConfig}->{AdditionalUriParameters}) ) {
            $AdditionalData{$AddParam} = $Self->{RequestData}->{$AddParam};
        }
    }

    # do we have to add includes and expands
    if ( !$Param{IgnoreInclude} ) {
        $AdditionalData{include} = $Self->{RequestData}->{include};
    }
    if ( !$Param{IgnoreExpand} ) {
        $AdditionalData{expand} = $Self->{RequestData}->{expand};
    }

    # add inherited data if given (but keep it overwritable if given in Data)
    my %InheritedData;
    if (defined $Self->{RequestData}->{limit}) {
        $InheritedData{limit} = $Self->{RequestData}->{limit};
    }
    if (defined $Self->{RequestData}->{searchlimit}) {
        $InheritedData{searchlimit} = $Self->{RequestData}->{searchlimit};
    }
    if (defined $Self->{RequestData}->{sort}) {
        $InheritedData{sort} = $Self->{RequestData}->{sort};
    }

    my $Result = $OperationObject->Run(
        Data    => {
            %InheritedData,
            %{$Param{Data} || {}},
            %AdditionalData
        },
        PermissionCheckOnly     => $Param{PermissionCheckOnly},
        IgnorePermissions       => $Param{IgnorePermissions},
        IgnoreParentPermissions => $Param{IgnoreParentPermissions},
        IgnoreValidators         => 1,                                  # always ignore validators in internal API calls
    );

    # check result and add cachetype if neccessary
    if ( $Result->{Success} && $OperationObject->{OperationConfig}->{CacheType} && $Self->{OperationConfig}->{CacheType} ) {
        $Self->AddCacheDependency( Type => $OperationObject->{OperationConfig}->{CacheType} );
        if ( IsHashRefWithData( $OperationObject->GetCacheDependencies() ) ) {
            foreach my $CacheDep ( keys %{ $OperationObject->GetCacheDependencies() } ) {
                $Self->AddCacheDependency( Type => $CacheDep );
            }
        }
        if ( $Kernel::OM->Get('Config')->Get('API::Debug') ) {
            $Self->_Debug( $Self->{LevelIndent}, "    cache type $Self->{OperationConfig}->{CacheType} now depends on: " . join( ',', keys %{ $Self->{CacheDependencies} } ) );
        }
    }

    return $Result;
}

# BEGIN INTERNAL

sub _ValidateFilter {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( \%Param ) || !$Param{Filter} ) {

        # nothing to do
        return;
    }

    my %OperatorTypeMapping = (
        'EQ'         => { 'NUMERIC' => 1, 'STRING' => 1, 'DATE'     => 1, 'DATETIME' => 1 },
        'NE'         => { 'NUMERIC' => 1, 'STRING' => 1, 'DATE'     => 1, 'DATETIME' => 1 },
        'LT'         => { 'NUMERIC' => 1, 'DATE'   => 1, 'DATETIME' => 1 },
        'GT'         => { 'NUMERIC' => 1, 'DATE'   => 1, 'DATETIME' => 1 },
        'LTE'        => { 'NUMERIC' => 1, 'DATE'   => 1, 'DATETIME' => 1 },
        'GTE'        => { 'NUMERIC' => 1, 'DATE'   => 1, 'DATETIME' => 1 },
        'IN'         => { 'NUMERIC' => 1, 'STRING' => 1, 'DATE'     => 1, 'DATETIME' => 1 },
        '!IN'         => { 'NUMERIC' => 1, 'STRING' => 1, 'DATE'     => 1, 'DATETIME' => 1 },
        'CONTAINS'   => { 'STRING'  => 1 },
        'STARTSWITH' => { 'STRING'  => 1 },
        'ENDSWITH'   => { 'STRING'  => 1 },
        'LIKE'       => { 'STRING'  => 1 },
    );
    my %ValidTypes;
    foreach my $Tmp ( values %OperatorTypeMapping ) {
        foreach my $Type ( keys %{$Tmp} ) {
            $ValidTypes{$Type} = 1;
        }
    }

    # if we have been given a perl hash as filter (i.e. when called by ExecOperation), we can use it right away
    my $FilterDef = $Param{Filter};

    # if we have a JSON string, we have to decode it
    if ( IsStringWithData($FilterDef) ) {
        $FilterDef = $Kernel::OM->Get('JSON')->Decode(
            Data => $Param{Filter}
        );
    }

    if ( !IsHashRefWithData($FilterDef) ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "JSON parse error in $Param{Type}!",
        );
    }

    foreach my $Object ( keys %{$FilterDef} ) {

        # do we have a object definition ?
        if ( !IsHashRefWithData( $FilterDef->{$Object} ) ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Invalid $Param{Type} for object $Object!",
            );
        }

        foreach my $BoolOperator ( keys %{ $FilterDef->{$Object} } ) {
            if ( $BoolOperator !~ /^(AND|OR)$/g ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Invalid $Param{Type} for object $Object!",
                );
            }

            # do we have a valid boolean operator
            if ( !IsArrayRefWithData( $FilterDef->{$Object}->{$BoolOperator} ) ) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => "Invalid $Param{Type} for object $Object!, operator $BoolOperator",
                );
            }

            # iterate filters
            foreach my $Filter ( @{ $FilterDef->{$Object}->{$BoolOperator} } ) {
                $Filter->{Operator} = uc( $Filter->{Operator} || q{} );
                $Filter->{Type}     = uc( $Filter->{Type}     || 'STRING' );

                # handle negated operators
                if ( $Filter->{Operator} =~ /^!(.*?)$/ ) {
                    $Filter->{Operator} = $1;
                    $Filter->{Not} = !$Filter->{Not};
                }

                # check if filter field is valid
                if ( !$Filter->{Field} ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "No field in $Object.$Filter->{Field}!",
                    );
                }

                # check if filter Operator is valid
                if (
                    !$Filter->{Operator}
                    || !$OperatorTypeMapping{$Filter->{Operator}}
                ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "Unknown filter operator $Filter->{Operator} in $Object.$Filter->{Field}!",
                    );
                }

                # check if type is valid
                if ( !$ValidTypes{ $Filter->{Type} } ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "Unknown type $Filter->{Type} in $Object.$Filter->{Field}!",
                    );
                }

                # check if combination of filter Operator and type is valid
                if ( !$OperatorTypeMapping{ $Filter->{Operator} }->{ $Filter->{Type} } ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "Type $Filter->{Type} not valid for operator $Filter->{Operator} in $Object.$Filter->{Field}!",
                    );
                }

                # check DATE value
                if (
                    $Filter->{Type} eq 'DATE'
                    && $Filter->{Value} !~ /^(\d{4}-\d{2}-\d{2}(\s*([-+]\d+\w\s*)*)|\s*([-+]\d+\w\s*?)*)$/
                    && $Filter->{Value} !~ /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(\s*([-+]\d+\w\s*)*)|\s*([-+]\d+\w\s*?)*)$/
                ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "Invalid date value $Filter->{Value} in $Object.$Filter->{Field}!",
                    );
                }

                # check DATETIME value
                if (
                    $Filter->{Type} eq 'DATETIME'
                    && $Filter->{Value} !~ /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(\s*([-+]\d+\w\s*)*)|\s*([-+]\d+\w\s*?)*)$/
                ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "Invalid datetime value $Filter->{Value} in $Object.$Filter->{Field}!",
                    );
                }
            }
        }
    }

    return $FilterDef;
}

sub _ApplyFilter {
    my ( $Self, %Param ) = @_;
    my %Result;

    if ( !IsHashRefWithData( \%Param ) || !IsHashRefWithData( $Param{Data} ) ) {

        # nothing to do
        return;
    }

    my $Filter = $Param{Filter} || $Self->{Filter};

    OBJECT:
    foreach my $FilterObject ( sort keys %{$Filter} ) {
        my $Object = $FilterObject;
        if ( $Object eq '*' ) {
            # wildcard
            $Object = (sort keys %{$Param{Data}})[0];
            # merge that filter with a specific one (if we have)
            if ( IsHashRefWithData($Filter->{$Object}) ) {
                foreach my $Key ( keys %{$Filter->{$Object}} ) {
                    next if !exists $Filter->{$FilterObject}->{$Key};
                    $Filter->{$Object}->{$Key} = [
                        @{$Filter->{$Object}->{$Key}},
                        @{$Filter->{$FilterObject}->{$Key}}
                    ];
                }
            }
            next OBJECT;
        }
        my $ObjectData = $Param{Data}->{$Object};

        if ( $Param{IsPermissionFilter} && IsHashRefWithData( $ObjectData ) ) {

            # if we do permission filtering and the relevant object is a hashref then its a request to an item resource
            # we have to prepare something so the filter can handle it
            $ObjectData = [ $ObjectData ];
        }
        if ( IsArrayRefWithData($ObjectData) && $Filter->{$FilterObject} ) {
            # ignore lists of scalars
            if ( !IsHashRefWithData($ObjectData->[0]) ) {
                $Self->_Debug($Self->{LevelIndent}, "$Object is a list of scalars, not going to filter");
                next OBJECT;
            }

            $Self->_Debug($Self->{LevelIndent}, sprintf("filtering %i objects of type %s", scalar @{$ObjectData}, $Object));

            # filter each contained hash
            my @FilteredResult = $Kernel::OM->Get('Main')->FilterObjectList(
                Data   => $ObjectData,
                Filter => $Filter->{$FilterObject},
            );

            if ( $Param{IsPermissionFilter} && IsHashRefWithData( $Param{Data}->{$Object} ) ) {

                # if we are in the permission filter mode and have prepared something in the beginning, check if we have an item in the filtered result
                # if not, the item cannot be read
                $Param{Data}->{$Object} = $FilteredResult[0];
                $Result{$Object} = scalar @FilteredResult;
                $Self->_Debug($Self->{LevelIndent}, sprintf("filtered result contains %i objects", $Result{$Object}));
            }
            else {
                $Param{Data}->{$Object} = \@FilteredResult;
                $Result{$Object} = scalar @FilteredResult;
            }
            if ( ref $Param{Data}->{$Object} eq 'ARRAY' ) {
                $Self->_Debug($Self->{LevelIndent}, sprintf("filtered result contains %i objects", scalar @{$Param{Data}->{$Object}}));
            }
        }
    }

    return \%Result;
}

sub _ApplyFieldSelector {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( \%Param ) || !IsHashRefWithData( $Param{Data} ) || !IsHashRefWithData($Param{Fields})) {

        # nothing to do
        return;
    }

    # condition cache
    my %ConditionCache;

    foreach my $Object ( keys %{ $Param{Fields} } ) {
        if ( $Object eq '*') {
            # wildcard
            $Object = (sort keys %{$Param{Data}})[0];
        }

        my @Fields = (
            @{ $Param{Fields}->{'*'} || [] },
            @{ $Param{Fields}->{$Object} || [] },
            $Param{IsPermissionFieldSelection} ? () : map { { Field => $_ } } keys %{ $Self->{Include} },
        );

        # count non-auto fields
        my $FieldCount = 0;
        foreach my $Field ( @Fields ) {
            next if $Field->{Auto};
            $FieldCount++;
        }

        if ( ref( $Param{Data}->{$Object} ) eq 'HASH' ) {

            my $ConditionCount   = 0;
            my $ConditionMatches = 0;

            # extract filtered fields from hash
            my %NewObject;
            my @FieldsToRemove;
            foreach my $Item ( @Fields ) {
                if ( IsHashRefWithData($Item->{ConditionFilter}) ) {
                    $ConditionCount++;

                    # if we have already evaluated that condition, we can use the cache
                    next if exists $ConditionCache{$Item->{Condition}} && !$ConditionCache{$Item->{Condition}};

                    if ( !exists $ConditionCache{$Item->{Condition}} ) {
                        # check the condition
                        my %Tmp = ( $Object => \%{ $Param{Data}->{$Object} } );
                        $Self->_ApplyFilter(
                            Data               => \%Tmp,
                            Filter             => $Item->{ConditionFilter},
                            IsPermissionFilter => 1,
                        );
                        $ConditionCache{$Item->{Condition}} = $Tmp{$Object};
                        next if !$ConditionCache{$Item->{Condition}};
                    }

                    $ConditionMatches++;
                }

                my $Not = 0;

                #localise Variable. see perdoc perlsyn
                my $FieldDef = $Item;
                my $Field    = $FieldDef->{Field};

                if ( $Field =~ /^!(.*?)$/ ) {
                    $Not   = 1;
                    $Field = $1;
                }
                if ( $Field eq '*' ) {
                    # include all fields
                    %NewObject = %{ $Param{Data}->{$Object} } if !$Not;
                    last;
                }
                else {
                    if ( !$Not ) {
                        # "select field"
                        $NewObject{$Field} = $Param{Data}->{$Object}->{$Field} if exists $Param{Data}->{$Object}->{$Field};
                    }
                    else {
                        # remember field to be removed later
                        push @FieldsToRemove, $Field;
                    }
                }
            }

            # remove all attributes that should be ignored
            foreach my $Field ( @FieldsToRemove ) {
                delete $NewObject{$Field};
            }

            # only change object if we have non only conditionals without any matches
            if ( $FieldCount != $ConditionCount || $ConditionMatches ) {
                $Param{Data}->{$Object} = \%NewObject;
            }
        }
        elsif ( ref( $Param{Data}->{$Object} ) eq 'ARRAY' ) {

            # filter keys in each contained hash
            OBJECTITEM:
            foreach my $ObjectItem ( @{ $Param{Data}->{$Object} } ) {
                if ( ref($ObjectItem) eq 'HASH' ) {
                    # reset condition cache for each object
                    %ConditionCache = ();

                    my $ConditionCount   = 0;
                    my $ConditionMatches = 0;

                    # extract filtered fields from hash
                    my %NewObjectItem;
                    my @FieldsToRemove;
                    FIELD:
                    foreach my $Item ( @Fields ) {

                        if ( IsHashRefWithData($Item->{ConditionFilter}) ) {
                            $ConditionCount++;

                            # if we have already evaluated that condition, we can use the cache
                            next FIELD if exists $ConditionCache{$Item->{Condition}} && !$ConditionCache{$Item->{Condition}};

                            if ( !exists $ConditionCache{$Item->{Condition}} ) {
                                # check the condition
                                my %Tmp = ( $Object => \%{ $ObjectItem } );
                                $Self->_ApplyFilter(
                                    Data               => \%Tmp,
                                    Filter             => $Item->{ConditionFilter},
                                    IsPermissionFilter => 1,
                                );
                                $ConditionCache{$Item->{Condition}} = $Tmp{$Object};
                                next FIELD if !$ConditionCache{$Item->{Condition}};
                            }

                            $ConditionMatches++;
                        }

                        my $Not = 0;

                        #localise Variable. see perdoc perlsyn
                        my $FieldDef = $Item;
                        my $Field    = $FieldDef->{Field};

                        if ( $Field =~ /^!(.*?)$/ ) {
                            $Not   = 1;
                            $Field = $1;
                        }
                        if ( $Field eq '*' ) {
                            # include all fields
                            %NewObjectItem = %{$ObjectItem} if !$Not;
                            last;
                        }
                        else {
                            if ( !$Not ) {
                                # "select field"
                                $NewObjectItem{$Field} = $ObjectItem->{$Field} if exists $ObjectItem->{$Field};
                            }
                            else {
                                # remember field to be removed later
                                push @FieldsToRemove, $Field;
                            }
                        }
                    }

                    # remove all attributes that should be ignored
                    foreach my $Field ( @FieldsToRemove ) {
                        delete $NewObjectItem{$Field};
                    }

                    # check if we have only conditionals an non matched
                    if ( $FieldCount == $ConditionCount && !$ConditionMatches ) {
                        # we have to accept the whole object
                        next OBJECTITEM;
                    }

                    $ObjectItem = \%NewObjectItem;
                }
            }
        }
    }

    return 1;
}

sub _ApplyOffset {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( \%Param ) || !IsHashRefWithData( $Param{Data} ) ) {

        # nothing to do
        return;
    }

    foreach my $Object ( keys %{ $Self->{Offset} } ) {
        if ( $Object eq '__COMMON' ) {
            foreach my $DataObject ( keys %{ $Param{Data} } ) {
                # ignore the object if we have a specific start index for it
                next if exists( $Self->{Offset}->{$DataObject} ) || (!$Param{Force} && $Self->{OperationConfig}->{ImplicitPagingFor}->{$DataObject});

                if ( ref( $Param{Data}->{$DataObject} ) eq 'ARRAY' ) {
                    my @ResultArray = splice @{ $Param{Data}->{$DataObject} }, $Self->{Offset}->{$Object};
                    $Param{Data}->{$DataObject} = \@ResultArray;
                }
            }
        }
        elsif ( ref( $Param{Data}->{$Object} ) eq 'ARRAY' && (!$Self->{OperationConfig}->{ImplicitPagingFor}->{$Object} || $Param{Force}) ) {
            my @ResultArray = splice @{ $Param{Data}->{$Object} }, $Self->{Offset}->{$Object};
            $Param{Data}->{$Object} = \@ResultArray;
        }
    }
}

sub _ApplyLimit {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( \%Param ) || !IsHashRefWithData( $Param{Data} ) ) {

        # nothing to do
        return;
    }

    foreach my $Object ( keys %{ $Self->{Limit} } ) {
        if ( $Object eq '__COMMON' ) {
            foreach my $DataObject ( keys %{ $Param{Data} } ) {

                # ignore the object if we have a specific limiter for it
                next if exists( $Self->{Limit}->{$DataObject} ) || (!$Param{Force} && $Self->{OperationConfig}->{ImplicitPagingFor}->{$DataObject});

                if ( $Self->{Limit}->{$Object} && ref( $Param{Data}->{$DataObject} ) eq 'ARRAY' ) {
                    my @LimitedArray = splice @{ $Param{Data}->{$DataObject} }, 0, $Self->{Limit}->{$Object};
                    $Param{Data}->{$DataObject} = \@LimitedArray;
                }
            }
        }
        elsif ( ref( $Param{Data}->{$Object} ) eq 'ARRAY' && (!$Self->{OperationConfig}->{ImplicitPagingFor}->{$Object} || $Param{Force}) ) {
            my @LimitedArray = splice @{ $Param{Data}->{$Object} }, 0, $Self->{Limit}->{$Object};
            $Param{Data}->{$Object} = \@LimitedArray;
        }
    }
}

sub _ApplySort {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( \%Param ) || !IsHashRefWithData( $Param{Data} ) ) {

        # nothing to do
        return;
    }

    foreach my $Object ( keys %{ $Self->{Sort} || $Self->{DefaultSort} } ) {
        if ( ref( $Param{Data}->{$Object} ) eq 'ARRAY' ) {

            $Self->_Debug($Self->{LevelIndent}, sprintf("sorting %i objects of type %s", scalar @{$Param{Data}->{$Object}}, $Object));

            # sort array by given criteria
            my @SortCriteria;
            my %SpecialSort;
            foreach my $Sort ( @{ $Self->{Sort}->{$Object} || $Self->{DefaultSort}->{$Object} } ) {
                my $SortField = $Sort->{Field};
                my $Type      = $Sort->{Type};

                # special handling for DATE and DATETIME sorts
                if ( $Sort->{Type} eq 'DATE' ) {

                    # handle this as a numeric compare
                    $Type                     = 'NUMERIC';
                    $SortField                = $SortField . '_DateSort';
                    $SpecialSort{'_DateSort'} = 1;

                    # convert field values to unixtime
                    foreach my $ObjectItem ( @{ $Param{Data}->{$Object} } ) {
                        next if (!$ObjectItem->{ $Sort->{Field} });
                        my ( $DatePart, $TimePart ) = split( /\s+/, $ObjectItem->{ $Sort->{Field} } );
                        $ObjectItem->{$SortField} = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                            String => $DatePart . ' 12:00:00',
                        );
                    }
                }
                elsif ( $Sort->{Type} eq 'DATETIME' ) {

                    # handle this as a numeric compare
                    $Type                         = 'NUMERIC';
                    $SortField                    = $SortField . '_DateTimeSort';
                    $SpecialSort{'_DateTimeSort'} = 1;

                    # convert field values to unixtime
                    foreach my $ObjectItem ( @{ $Param{Data}->{$Object} } ) {
                        next if (!$ObjectItem->{ $Sort->{Field} });
                        $ObjectItem->{$SortField} = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                            String => $ObjectItem->{ $Sort->{Field} },
                        );
                    }
                }

                # special handling for "number-strings"
                if (lc($Type) eq 'textual') {
                    my $HasNotNumeric = grep {
                        $_->{$SortField} && $_->{$SortField} !~ m/^\d+$/
                    } @{ $Param{Data}->{$Object} };
                    if (!$HasNotNumeric) {
                        $Type = 'NUMERIC';
                    }
                }

                push @SortCriteria, {
                    order   => $Sort->{Direction},
                    compare => lc($Type),
                    sortkey => $SortField,
                };
            }

            my @SortedArray = sorted_arrayref( $Param{Data}->{$Object}, @SortCriteria );

            # remove special sort attributes
            if (%SpecialSort) {
                SPECIALSORTKEY:
                foreach my $SpecialSortKey ( keys %SpecialSort ) {
                    foreach my $ObjectItem (@SortedArray) {
                        last SPECIALSORTKEY if !IsHashRefWithData($ObjectItem);

                        my %NewObjectItem;
                        foreach my $ItemAttribute ( keys %{$ObjectItem} ) {
                            if ( $ItemAttribute !~ /.*?$SpecialSortKey$/g ) {
                                $NewObjectItem{$ItemAttribute} = $ObjectItem->{$ItemAttribute};
                            }
                        }

                        $ObjectItem = \%NewObjectItem;
                    }
                }
            }

            $Param{Data}->{$Object} = \@SortedArray;
        }
    }
}

sub _ApplyInclude {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( \%Param ) || !IsHashRefWithData( $Param{Data} ) ) {

        # nothing to do
        return;
    }

    if ( $Self->{RequestMethod} ne 'GET' || !$Self->{OperationConfig}->{ObjectID} || !$Self->{RequestData}->{ $Self->{OperationConfig}->{ObjectID} } ) {

        # no GET request or no ObjectID configured or given
        return;
    }

    # check if a given include can be matched to a sub-resource
    if ( IsHashRefWithData( $Self->{OperationRouteMapping} ) ) {
        my %ReverseOperationRouteMapping = reverse %{ $Self->{OperationRouteMapping} };

        foreach my $Include ( keys %{ $Self->{Include} } ) {
            next if !$Self->{OperationRouteMapping}->{ $Self->{OperationType} };
            next if $Self->{SuppressSubResourceIncludes}->{lc($Include)};

            my $IncludeOperation = $ReverseOperationRouteMapping{ "$Self->{OperationRouteMapping}->{$Self->{OperationType}}/" . lc($Include) };
            next if !$IncludeOperation;

            OBJECT:
            foreach my $Object ( keys %{ $Param{Data} } ) {
                next if !$Param{Data}->{$Object};

                if ( IsArrayRef( $Param{Data}->{$Object} ) ) {
                    my $Index = 0;
                    ITEM:
                    foreach my $Item ( @{$Param{Data}->{$Object}} ) {
                        if ( $Self->{IncludeSubResourceIfProperty}->{lc($Include)} && !$Item->{$Self->{IncludeSubResourceIfProperty}->{lc($Include)}} ) {
                            $Param{Data}->{$Object}->[ $Index++ ]->{$Include} = [];
                            next ITEM;
                        }

                        # we found a sub-resource include
                        my $Result = $Self->ExecOperation(
                            OperationType => $IncludeOperation,
                            Data          => {
                                %{ $Self->{RequestData} },
                                $Self->{OperationConfig}->{ObjectID} => $Item->{$Self->{OperationConfig}->{ObjectID}} || $Item->{ID},
                                }
                        );
                        if ( IsHashRefWithData($Result) && $Result->{Success} ) {

                            # get first response object as the include - this is not the perfect solution but it works for the moment
                            $Param{Data}->{$Object}->[ $Index++ ]->{$Include} = $Result->{Data}->{ ( keys %{ $Result->{Data} } )[0] };
                        } else {

                            # no success means empty list
                            $Param{Data}->{$Object}->[ $Index++ ]->{$Include} = [];
                        }
                    }
                }
                else {
                    if ( $Self->{IncludeSubResourceIfProperty}->{lc($Include)} && !$Param{Data}->{$Object}->{$Self->{IncludeSubResourceIfProperty}->{lc($Include)}} ) {
                        $Param{Data}->{$Object}->{$Include} = [];
                        next OBJECT;
                    }

                    # we found a sub-resource include
                    my $Result = $Self->ExecOperation(
                        OperationType => $IncludeOperation,
                        Data          => {
                            %{ $Self->{RequestData} },
                            $Self->{OperationConfig}->{ObjectID} => $Param{Data}->{$Object}->{ $Self->{OperationConfig}->{ObjectID} } || $Param{Data}->{$Object}->{ID}
                        }
                    );
                    if ( IsHashRefWithData($Result) && $Result->{Success} ) {

                        # get first response object as the include - this is not the perfect solution but it works for the moment
                        $Param{Data}->{$Object}->{$Include} = $Result->{Data}->{ ( keys %{ $Result->{Data} } )[0] };
                    } else {

                        # no success means empty list
                        $Param{Data}->{$Object}->{$Include} = [];
                    }
                }
            }
        }
    }

    # handle generic includes
    my $GenericIncludes = $Kernel::OM->Get('Config')->Get('API::Operation::GenericInclude');
    if ( IsHashRefWithData($GenericIncludes) ) {
        foreach my $Include ( keys %{ $Self->{Include} } ) {
            next if !$GenericIncludes->{$Include};
            next if $GenericIncludes->{$Include}->{IgnoreOperationRegEx} && $Self->{OperationType} =~ /$GenericIncludes->{$Include}->{IgnoreOperationRegEx}/;

            # we've found a requested generic include, now we have to handle it
            my $IncludeHandler = $GenericIncludes->{$Include}->{Module};
            if ( !$Self->{IncludeHandler}->{$IncludeHandler} ) {
                if ( !$Kernel::OM->Get('Main')->Require($IncludeHandler) ) {

                    return $Self->_Error(
                        Code    => 'Operation.InternalError',
                        Message => "Can't load include handler $IncludeHandler!"
                    );
                }
                $Self->{IncludeHandler}->{$IncludeHandler} = $IncludeHandler->new(
                    %{$Self},
                );
            }

            # if CacheType is set in config of GenericInclude
            if ( defined $GenericIncludes->{$Include}->{CacheType} ) {
                $Self->AddCacheDependency( Type => $GenericIncludes->{$Include}->{CacheType} );
                $Self->AddCacheDependency( Type => $GenericIncludes->{$Include}->{CacheTypeDependency} );
            }

            $Self->_Debug( $Self->{LevelIndent}, "GenericInclude: $Include" );

            # do it for every object in the response
            foreach my $Object ( keys %{ $Param{Data} } ) {
                next if !$Param{Data}->{$Object};

                if ( IsArrayRefWithData( $Param{Data}->{$Object} ) ) {

                    my $Index = 0;
                    foreach my $Item ( @{$Param{Data}->{$Object}} ) {

                        $Param{Data}->{$Object}->[ $Index++ ]->{$Include} = $Self->{IncludeHandler}->{$IncludeHandler}->Run(
                            OperationConfig => $Self->{OperationConfig},
                            RequestURI      => $Self->{RequestURI},
                            Object          => $Object,
                            ObjectID        => $Item->{$Self->{OperationConfig}->{ObjectID}} || $Item->{ID},
                            UserID          => $Self->{Authorization}->{UserID},
                        );

                        # add specific cache dependencies after exec if available
                        if ( $Self->{IncludeHandler}->{$IncludeHandler}->can('GetCacheDependencies') ) {
                            foreach my $CacheDep ( keys %{ $Self->{IncludeHandler}->{$IncludeHandler}->GetCacheDependencies() } ) {
                                $Self->{CacheDependencies}->{$CacheDep} = 1;
                            }
                        }
                    }
                }
                else {
                    my $Result = $Self->{IncludeHandler}->{$IncludeHandler}->Run(
                        OperationConfig => $Self->{OperationConfig},
                        RequestURI      => $Self->{RequestURI},
                        Object          => $Object,
                        ObjectID        => $Self->{RequestData}->{ $Self->{OperationConfig}->{ObjectID} } || $Self->{RequestData}->{ID},
                        UserID          => $Self->{Authorization}->{UserID},
                    );

                    if ($Result && IsHashRef($Param{Data}->{$Object}) ) {
                        $Param{Data}->{$Object}->{$Include} = $Result;

                        # add specific cache dependencies after exec if available
                        if ( $Self->{IncludeHandler}->{$IncludeHandler}->can('GetCacheDependencies') ) {
                            foreach my $CacheDep ( keys %{ $Self->{IncludeHandler}->{$IncludeHandler}->GetCacheDependencies() } ) {
                                $Self->{CacheDependencies}->{$CacheDep} = 1;
                            }
                        }
                    }
                }
            }

            $Kernel::OM->Get('Cache')->_Debug( $Self->{LevelIndent}, "    type $Self->{OperationConfig}->{CacheType} has dependencies to: " . join( ',', keys %{ $Self->{CacheDependencies} } ) );
        }
    }

    return 1;
}

sub _ApplyExpand {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( \%Param ) || !IsHashRefWithData( $Param{Data} ) ) {

        # nothing to do
        return;
    }

    if ( $ENV{'REQUEST_METHOD'} ne 'GET' || !$Self->{OperationConfig}->{ObjectID} || !$Self->{RequestData}->{ $Self->{OperationConfig}->{ObjectID} } ) {

        # no GET request or no ObjectID configured or given
        return;
    }

    my $GenericExpands = $Kernel::OM->Get('Config')->Get('API::Operation::GenericExpand');

    if ( IsHashRefWithData($GenericExpands) ) {
        foreach my $Object ( keys %{ $Param{Data} } ) {
            foreach my $AttributeToExpand ( keys %{ $Self->{Expand} } ) {
                next if !$GenericExpands->{ $Object . '.' . $AttributeToExpand } && !$GenericExpands->{$AttributeToExpand};

                $Self->_Debug( $Self->{LevelIndent}, "GenericExpand: $AttributeToExpand" );

                my @ItemList;
                if ( IsArrayRef( $Param{Data}->{$Object} ) ) {
                    @ItemList = @{ $Param{Data}->{$Object} };
                }
                else {
                    @ItemList = ( $Param{Data}->{$Object} );
                }

                foreach my $ItemData (@ItemList) {
                    if (IsHashRefWithData($ItemData)) {
                        my $Result = $Self->_ExpandObject(
                            AttributeToExpand => $AttributeToExpand,
                            ExpanderConfig    => $GenericExpands->{ $Object . '.' . $AttributeToExpand } || $GenericExpands->{$AttributeToExpand},
                            Data              => $ItemData
                        );

                        if ( IsHashRefWithData($Result) && !$Result->{Success} ) {
                            return $Result;
                        }
                    }
                }
            }
        }
    }

    return 1;
}

sub _ExpandObject {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(AttributeToExpand ExpanderConfig Data)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => '_ExpandObject.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    my $Data = $Param{Data};

    if ( $Param{AttributeToExpand} =~ /[.:]/ ) {
        # we need to flatten the data
        $Data = $Kernel::OM->Get('Main')->Flatten(
            Data => $Data
        );
    }

    my @Array;
    if ( IsArrayRefWithData( $Data->{ $Param{AttributeToExpand} } ) ) {
        @Array = @{ $Data->{ $Param{AttributeToExpand} } };
    }
    elsif ( IsHashRefWithData( $Data->{ $Param{AttributeToExpand} } ) ) {

        # hashref isn't possible
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Expanding a hash is not possible!",
        );
    }
    elsif ( IsStringWithData( $Data->{ $Param{AttributeToExpand} } ) ) {

        # convert scalar into our data array for further use
        @Array = ( $Data->{ $Param{AttributeToExpand} } );
    }
    else {
        # no data available to expand
        return 1;
    }

    # get primary key for get operation
    my $OperationConfig = $Kernel::OM->Get('Config')->Get('API::Operation::Module')->{ $Param{ExpanderConfig}->{Operation} };
    if ( !IsHashRefWithData($OperationConfig) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "No config for expand operation found!",
        );
    }
    if ( !$OperationConfig->{ObjectID} ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "No ObjectID for expand operation configured!",
        );
    }

    # add primary ObjectID to params
    my %ExecData = (
        "$OperationConfig->{ObjectID}" => join( ',', sort @Array )
    );

    if ( $Param{ExpanderConfig}->{AddParams} ) {
        my @AddParams = split( /\s*,\s*/, $Param{ExpanderConfig}->{AddParams} );
        foreach my $AddParam (@AddParams) {
            my ( $TargetAttr, $SourceAttr ) = split( /=/, $AddParam );

            # if we don't have a special source attribute, target and source attribute are the same
            if ( !$SourceAttr ) {
                $SourceAttr = $TargetAttr;
            }
            $ExecData{$TargetAttr} = $Data->{$SourceAttr},
        }
    }

    my $StoreTo = $Param{ExpanderConfig}->{StoreTo} || $Param{AttributeToExpand};

    my $Result = $Self->ExecOperation(
        OperationType => $Param{ExpanderConfig}->{Operation},
        Data          => \%ExecData,
    );
    if ( !IsHashRefWithData($Result) || !$Result->{Success} ) {
        $Result->{Data}->{$StoreTo} = IsArrayRef($Data->{$Param{AttributeToExpand}}) ? [] : undef;
    }

    # extract the relevant data from result
    my $ResultData = $Result->{Data}->{ ( ( keys %{ $Result->{Data} } )[0] ) };

    if ( $Param{AttributeToExpand} =~ /[.:]/ ) {
        # we need to flatten the result data
        $ResultData = $Kernel::OM->Get('Main')->Flatten(
            Data => $ResultData
        );

        # merge the two flat hashes
        foreach my $Key ( keys %{$ResultData} ) {
            $Data->{$StoreTo.'.'.$Key} = $ResultData->{$Key}
        }

        # reverse the flatten
        $Data = $Kernel::OM->Get('Main')->Unflatten(
            Data => $Data
        );
    }
    else {
        if ( IsArrayRef($Data->{$Param{AttributeToExpand}}) ) {
            if ( IsArrayRef($ResultData) ) {
                $Data->{$StoreTo} = $ResultData;
            }
            else {
                $Data->{$StoreTo} = [$ResultData];
            }
        }
        else {
            $Data->{$StoreTo} = $ResultData;
        }
    }

    %{$Param{Data}} = %{$Data};

    return $Self->_Success();
}

sub _ApplyObjectPermissions {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( \%Param ) || !IsHashRefWithData( $Param{Data} ) ) {

        # nothing to do
        return;
    }

    # get the relevant permission for the current request method
    my $PermissionName = Kernel::API::Operation->REQUEST_METHOD_PERMISSION_MAPPING->{ $Self->{RequestMethod} };

    $Self->_PermissionDebug($Self->{LevelIndent},  sprintf("applying object permissions. using the following permissions: %s", Data::Dumper::Dumper($Self->{RelevantObjectPermissions})) );

    foreach my $Object ( sort keys %{$Param{Data}} ) {
        my @ItemList = IsArrayRef($Param{Data}->{$Object}) ? @{$Param{Data}->{$Object}} : ( $Param{Data}->{$Object} );

        my @NewItemList;
        my $IsFiltered = 0;

        ITEM:
        foreach my $Item ( @ItemList ) {

            # we need a hash ref to filter
            next ITEM if ( !IsHashRefWithData($Item) );

            my $ObjectID = $Self->{OperationConfig}->{ObjectID} || 'ID';

            my $ResultingPermission;

            PERMISSION:
            foreach my $Permission ( @{$Self->{RelevantObjectPermissions}} ) {

                # ignore permission for another object type
                next PERMISSION if ( !$Permission->{ConditionFilter}->{$Object} && !$Permission->{ConditionFilter}->{'*'} );

                my %Data = (
                    $Object => \%{$Item}
                );

                $Self->_PermissionDebug($Self->{LevelIndent},  sprintf("applying object permission condition {%s} to object with ID %i", $Permission->{Condition}, $Item->{$ObjectID}) );

                # check the condition
                $Self->_ApplyFilter(
                    Data               => \%Data,
                    Filter             => $Permission->{ConditionFilter},
                    IsPermissionFilter => 1,
                );

                next PERMISSION if !IsHashRefWithData($Data{$Object});

                $ResultingPermission = 0 if !defined $ResultingPermission;

                # the filter matches, so we have to calculate the resulting permission
                $ResultingPermission |= $Permission->{Value};
            }

            if ( defined $ResultingPermission ) {
                $IsFiltered = 1;
                # check if we have the desired permission
                my $PermissionCheck = ( $ResultingPermission & Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) == Kernel::System::Role::Permission::PERMISSION->{$PermissionName};
                my $IsDeny          = ( $ResultingPermission & Kernel::System::Role::Permission::PERMISSION->{DENY} ) == Kernel::System::Role::Permission::PERMISSION->{DENY};

                if ( ($IsDeny || !$PermissionCheck) && !IsArrayRef($Param{Data}->{$Object}) ) {
                    # we have a single object and no permission, return a forbidden
                    $Self->_PermissionDebug($Self->{LevelIndent},  sprintf("object doesn't match the required criteria - denying request") );

                    # return 403, because we don't have permission to execute this
                    return $Self->_Error(
                        Code => 'Forbidden',
                    );
                }
                elsif ( !$IsDeny && $PermissionCheck ) {
                    push @NewItemList, $Item;
                }
            }
            else {
                push @NewItemList, $Item;
            }
        }
        if ( $IsFiltered ) {
            # replace the item list in the response
            if ( IsArrayRefWithData($Param{Data}->{$Object}) ) {
                $Param{Data}->{$Object} = \@NewItemList;
                $Self->_PermissionDebug($Self->{LevelIndent},  sprintf("permission filtered result contains %i objects", scalar @NewItemList) );
            }
            else {
                $Param{Data}->{$Object} = $NewItemList[0]
            }
        }
    }

    return 1;
}

sub _SetParameter {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data Attribute)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => '_SetParameter.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    my $Value;
    if ( exists( $Param{Value} ) ) {
        $Value = $Param{Value};
    }

    if ( $Param{Attribute} =~ /::/ ) {
        my ( $SubKey, $Rest ) = split( /::/, $Param{Attribute} );
        $Self->_SetParameter(
            Data      => $Param{Data}->{$SubKey},
            Attribute => $Rest,
            Value     => $Param{Value}
        );
    }
    else {
        $Param{Data}->{ $Param{Attribute} } = $Value;
    }

    return 1;
}

sub _Trim {
    my ( $Self, %Param ) = @_;

    return $Param{Data} if ( !$Param{Data} );

    # remove leading and trailing spaces
    if ( ref( $Param{Data} ) eq 'HASH' ) {
        foreach my $Attribute ( sort keys %{ $Param{Data} } ) {
            $Param{Data}->{$Attribute} = $Self->_Trim(
                Data => $Param{Data}->{$Attribute}
            );
        }
    }
    elsif ( ref( $Param{Data} ) eq 'ARRAY' ) {
        my $Index = 0;
        foreach my $Attribute ( @{ $Param{Data} } ) {
            $Param{Data}->[ $Index++ ] = $Self->_Trim(
                Data => $Attribute
            );
        }
    }
    else {
        #remove leading spaces
        $Param{Data} =~ s{\A\s+}{};

        #remove trailing spaces
        $Param{Data} =~ s{\s+\z}{};
    }

    return $Param{Data};
}

sub _GetCacheKey {
    my ( $Self, %Param ) = @_;

    # generate key without offset & limit
    my %RequestData = %{ $Self->{RequestData} };
    if ( !IsHashRefWithData($Self->{OperationConfig}->{ImplicitPagingFor}) ) {
        delete $RequestData{offset};
        delete $RequestData{limit};
    }
    if ( !$Self->{HandleSortInCORE} ) {
        delete $RequestData{sort};
    }
    delete $RequestData{filter};

    my @CacheKeyParts;
    if ( IsArrayRefWithData( $Self->{CacheKeyExtensions} ) ) {
        @CacheKeyParts = @{ $Self->{CacheKeyExtensions} };
    }

    # sort some things to make sure you always get the same cache key independent of the given order
    foreach my $What (@CacheKeyParts) {
        next if !$What || !$RequestData{$What};

        my @Parts = split( /,/, $RequestData{$What} );
        $RequestData{$What} = join( ',', sort @Parts );
    }

    # add UserKey (UserID + UserType) to CacheKey if not explicitly disabled
    my $UserKey = '';
    if ( !$Self->{OperationConfig}->{DisableUserBasedCaching} ) {
        $UserKey = $Self->{Authorization}->{UserID} . '::' . $Self->{Authorization}->{UserType};
    }

    my $CacheKey = $UserKey . '::' . $Self->{WebserviceID} . '::' . $Self->{OperationType} . '::' . $Kernel::OM->Get('Main')->Dump(
        \%RequestData,
        'ascii+noindent'
    );

    return $CacheKey;
}

sub _CacheRequest {
    my ( $Self, %Param ) = @_;

    if ( $Param{Data} ) {
        my $CacheKey = $Self->_GetCacheKey();
        my @CacheDependencies;
        if ( IsHashRefWithData( $Self->{CacheDependencies} ) ) {
            @CacheDependencies = keys %{ $Self->{CacheDependencies} };
        }
        $Kernel::OM->Get('Cache')->Set(
            Type     => $Self->{OperationConfig}->{CacheType},
            Depends  => \@CacheDependencies,
            Category => 'API',
            Key      => $CacheKey,
            Value    => $Param{Data},
            TTL      => 60 * 60 * 24 * 7,                        # 7 days
        );
    }

    return 1;
}

=item _ExecPermissionChecks()

check the given permissions

    my $Allowed = $CommonObject->_ExecPermissionChecks(
        Checks => []
    );

    $Allowed = 1 if allowed

=cut

sub _ExecPermissionChecks {
    my ( $Self, %Param ) = @_;

    return 1 if !IsArrayRefWithData($Param{Checks});

    my $UserID = $Self->{Authorization}->{UserID};
    $Self->{'_ExecPermissionChecksCache'}->{$UserID} //= {};

    my $Allowed = 1;
    CHECK:
    foreach my $Check ( @{$Param{Checks}} ) {
        my $Result;
        if ( exists $Self->{'_ExecPermissionChecksCache'}->{$UserID}->{$Check->{Check}} ) {
            $Result = $Self->{'_ExecPermissionChecksCache'}->{$UserID}->{$Check->{Check}};
        }
        else {
            $Result = $Self->ExecOperation(
                OperationType            => $Check->{OperationType},
                RequestMethod            => $Check->{RequestMethod},
                SuppressPermissionErrors => 1,
                PermissionCheckOnly      => 1,
                IgnoreInclude            => 1,
                IgnoreExpand             => 1,
                Data                     => $Check->{Data}
            );
            $Self->{'_ExecPermissionChecksCache'}->{$UserID}->{$Check->{Check}} = $Result;
        }
        if ( !$Result->{Success} ) {
            $Allowed = 0;
            last CHECK;
        }
    }

    return $Allowed;
}

=item _CheckBasePermission()

check base permissions

    my $Return = $CommonObject->_CheckBasePermission(
        Data => {},
    );

    $Return = _Success if granted

=cut

sub _CheckBasePermission {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $PermissionName = Kernel::API::Operation->REQUEST_METHOD_PERMISSION_MAPPING->{ $Self->{RequestMethod} };

    my $Result = $Self->GetBasePermissionObjectIDs(
        %Param,
        UserID       => $Self->{Authorization}->{UserID},
        UsageContext => $Self->{Authorization}->{UserType},
        Permission   => $PermissionName,
    );
    if ( !$Result ) {
        # return 403, because we don't have permission
        return $Self->_Error(
            Code => 'Forbidden',
        );
    }
    elsif ( !IsHashRef($Result) ) {
        return $Self->_Success();
    }

    # add corresponding permission filter
    my %Filter = $Self->_CreateFilterForObject(
        Filter   => {},
        Object   => $Result->{Object},
        Field    => $Result->{Attribute},
        Operator => 'IN',
        Value    => $Result->{ObjectIDs},
    );
    if ( !%Filter ) {
        # we can't generate the filter, so this is a false
        $Self->_PermissionDebug($Self->{LevelIndent}, sprintf("Unable to create permission filter for base permission!") );
        return;
    }

    if ( $Self->{RequestMethod} ne 'GET' ) {
        # load the object data (if we have to)
        my %ObjectData = ();
        if ( $Self->{RequestMethod} eq 'POST' ) {
            if ( IsHashRefWithData($Param{Data}->{$Result->{Object}}) ) {
                # we need some special handling here since we don't have an object in the DB yet
                # so we have to use the object given in the request data
                %ObjectData = %{$Param{Data}};

                $Self->_ApplyFilter(
                    Data               => \%ObjectData,
                    Filter             => \%Filter,
                    IsPermissionFilter => 1,
                );

                if ( !IsHashRefWithData($ObjectData{$Result->{Object}} ) ) {
                    # return 403, because we don't have permission
                    return $Self->_Error(
                        Code => 'Forbidden',
                    );
                }
            }
            elsif ( !IsArrayRefWithData($Result->{ObjectIDs}) ) {
                # we don't have a given object in the request data, we are returning 403
                # because we don't have any possible ObjectIDs matching the relevant base permission
                return $Self->_Error(
                    Code => 'Forbidden',
                );
            }
        }
        elsif ( IsHashRefWithData($Self->{AvailableMethods}->{GET}) && $Self->{AvailableMethods}->{GET}->{Operation} ) {

            # get the object data from the DB using a faked GET operation (we are ignoring permissions, just to get the data)
            # a GET request will be handled differently
            my $GetResult = $Self->ExecOperation(
                RequestMethod     => 'GET',
                OperationType     => $Self->{AvailableMethods}->{GET}->{Operation},
                Data              => $Param{Data},
                IgnorePermissions => 1,
            );

            if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
                # no success, simply return what we got
                return $GetResult;
            }

            %ObjectData = %{$GetResult->{Data}};

            if ( exists $ObjectData{$Result->{Object}} ) {
                # only filter if there is a relevant object to filter
                $Self->_ApplyFilter(
                    Data               => \%ObjectData,
                    Filter             => \%Filter,
                    IsPermissionFilter => 1,
                );

                if ( !IsHashRefWithData($ObjectData{$Result->{Object}} ) ) {#
                    # return 403, because we don't have permission
                    return $Self->_Error(
                        Code => 'Forbidden',
                    );
                }
            }
        }
    }
    else {
        $Self->{BasePermissionFilter} = \%Filter;
    }

    return $Self->_Success();
}

=item _CheckObjectPermission()

check object permissions

    my $Return = $CommonObject->_CheckObjectPermission(
        Data => {}          # optional
    );

    $Return = _Success if granted

=cut

sub _CheckObjectPermission {
    my ( $Self, %Param ) = @_;

    # init
    $Self->{RelevantObjectPermissions} = [];

    # get the relevant permission for the current request method
    my $PermissionName = Kernel::API::Operation->REQUEST_METHOD_PERMISSION_MAPPING->{ $Self->{RequestMethod} };

    # get list of permission types
    my %PermissionTypeList = $Kernel::OM->Get('Role')->PermissionTypeList();

    # get all Object permissions for this user
    my %Permissions = $Kernel::OM->Get('User')->PermissionList(
        UserID       => $Self->{Authorization}->{UserID},
        UsageContext => $Self->{Authorization}->{UserType},
        Types        => [ 'Object' ],
        Valid        => 1
    );

    # get all relevant permissions
    my @RelevantPermissions;
    foreach my $Permission ( sort { length($b->{Target}) <=> length($a->{Target}) } values %Permissions ) {

        # check for "Wildcard" target (empty restriction)
        $Permission->{IsWildcard} = 1 if $Permission->{Target} =~ /^.*?\{\}$/;

        # prepare target
        my $Target = $Permission->{Target};
        if ( !$Permission->{IsWildcard} ) {
            $Target =~ s/\*/[^\/]+/g;
        }
        else {
            $Target =~ s/\*/.*?/g;
        }
        $Target =~ s/\//\\\//g;
        $Target =~ s/\{.*?\}$//g;

        # only match the current RequestURI
        next if $Self->{RequestURI} !~ /^$Target$/;

        $Self->_PermissionDebug($Self->{LevelIndent},  sprintf( "found relevant permission (Object) on target \"%s\" with value 0x%04x", $Permission->{Target}, $Permission->{Value} ) );

        push @RelevantPermissions, $Permission;
    }

    # do something if we have at least one permission
    if ( IsArrayRefWithData(\@RelevantPermissions) ) {

        # load the object data (if we have to)
        my $ObjectData = {};
        if ( $Self->{RequestMethod} eq 'POST' ) {
            # we need some special handling here since we don't have an object in the DB yet
            # so we have to use the object given in the request data
            $ObjectData = $Param{Data};
        }
        elsif ( $Self->{RequestMethod} ne 'GET' && IsHashRefWithData($Self->{AvailableMethods}->{GET}) && $Self->{AvailableMethods}->{GET}->{Operation} ) {

            # get the object data from the DB using a faked GET operation (we are ignoring permissions, just to get the data)
            # a GET request will be handled differently
            my $GetResult = $Self->ExecOperation(
                RequestMethod     => 'GET',
                OperationType     => $Self->{AvailableMethods}->{GET}->{Operation},
                Data              => $Param{Data},
                IgnorePermissions => 1,
            );

            if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
                # no success, simply return what we got
                return $GetResult;
            }

            $ObjectData = $GetResult->{Data};
        }

        my $ResultingPermission = -1;

        # check each permission
        PERMISSION:
        foreach my $Permission ( @RelevantPermissions ) {

            # extract property value permission
            next if $Permission->{Target} !~ /^.*?\{(.*?)\}$/;

            $Permission->{Condition} = $1;

            if ( !$Permission->{IsWildcard} ) {
                my $CheckResult = $Self->_CheckPermissionCondition(
                    Permission => $Permission,
                    Condition  => $Permission->{Condition},
                    Data       => $ObjectData
                );

                # if we don't have a GET request and the condition doesn't match, we can ignore this permission
                next PERMISSION if $Self->{RequestMethod} ne 'GET' && !$CheckResult;
            }
            else {
                $Permission->{ConditionFilter} = {
                    '*' => {
                        OR => [
                            { AlwaysTrue => 1 }
                        ]
                    }
                };
            }

            if ( $Self->{RequestMethod} ne 'GET' ) {

                $ResultingPermission = 0 if $ResultingPermission == -1;

                $ResultingPermission |= $Permission->{Value};

                my $ResultingPermissionShort = $Kernel::OM->Get('Role')->GetReadablePermissionValue(
                    Value  => $ResultingPermission,
                    Format => 'Short'
                );

                $Self->_PermissionDebug($Self->{LevelIndent}, "resulting Object permission: $ResultingPermissionShort");

                # check if we have a DENY already
                if ( ($Permission->{Value} & Kernel::System::Role::Permission::PERMISSION->{DENY}) == Kernel::System::Role::Permission::PERMISSION->{DENY} ) {
                    $Self->_PermissionDebug($Self->{LevelIndent}, "DENY in permission ID $Permission->{ID} on target \"$Permission->{Target}\"" . ($Permission->{Comment} ? "(Comment: $Permission->{Comment})" : '') );
                    last PERMISSION;
                }
            }
            else {
                # we have a GET request, so we have to prepare everything for later
                push @{$Self->{RelevantObjectPermissions}}, $Permission;
            }
        }

        # output the result here if we do not have a GET request
        if ( $Self->{RequestMethod} ne 'GET' ) {
            if ( $ResultingPermission != -1 ) {
                # check if we have the desired permission
                my $PermissionCheck = ( $ResultingPermission & Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) == Kernel::System::Role::Permission::PERMISSION->{$PermissionName};

                # check if we have a DENY
                if ( ( $ResultingPermission & Kernel::System::Role::Permission::PERMISSION->{DENY} ) == Kernel::System::Role::Permission::PERMISSION->{DENY} ) {
                    $Self->_PermissionDebug($Self->{LevelIndent},  sprintf("object doesn't match the required criteria - denying request") );

                    # return 403, because we don't have permission to execute this
                    return $Self->_Error(
                        Code => 'Forbidden',
                    );
                }
            }

            if ( $ResultingPermission != -1 && ( $ResultingPermission & Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) != Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) {
                $Self->_PermissionDebug($Self->{LevelIndent},  sprintf("object doesn't match the required criteria - denying request") );

                # return 403, because we don't have permission to execute this
                return $Self->_Error(
                    Code => 'Forbidden',
                );
            }
        }
    }

    return $Self->_Success();
}

=item _CheckPropertyPermission()

check property permissions

    my $Return = $CommonObject->_CheckPropertyPermission(
        Data => {}              # optional
    );

    $Return = _Success if granted

=cut
sub _CheckPropertyPermission {
    my ( $Self, %Param ) = @_;

    $Self->{PermissionFieldSelector} = {};

    # get the relevant permission for the current request method
    my $PermissionName = Kernel::API::Operation->REQUEST_METHOD_PERMISSION_MAPPING->{ $Self->{RequestMethod} };

    # get list of permission types
    my %PermissionTypeList = $Kernel::OM->Get('Role')->PermissionTypeList();

    # get all Object and Property permissions for this user
    my %Permissions = $Kernel::OM->Get('User')->PermissionList(
        UserID       => $Self->{Authorization}->{UserID},
        UsageContext => $Self->{Authorization}->{UserType},
        Types        => [ 'Property' ],
        Valid        => 1
    );

    # get all relevant permissions
    my @RelevantPermissions;
    foreach my $Permission ( sort { length($b) <=> length($a) } values %Permissions ) {

        # check for "Wildcard" target (empty restriction)
        $Permission->{IsWildcard} = 1 if $Permission->{Target} =~ /^.*?\{\}$/;

        # prepare target
        my $Target = $Permission->{Target};

        #on POST/PATCH and if DENY and has '!*', remove '!*' from target (only deny specified attributes)
        if ($Self->{RequestMethod} =~ /^POST|PATCH$/ && $Target =~ /\!\*,?/g &&
            ($Permission->{Value} & Kernel::System::Role::Permission::PERMISSION->{DENY})
                == Kernel::System::Role::Permission::PERMISSION->{DENY}) {
            $Target =~ s/\!\*,?//g;
            $Permission->{Target} = $Target;
        }
        if ( !$Permission->{IsWildcard} ) {
            $Target =~ s/\*/[^\/]+/g;
        }
        else {
            $Target =~ s/\*/.*?/g;
        }
        $Target =~ s/\//\\\//g;
        $Target =~ s/\{.*?\}$//g;

        # only match the current RequestURI
        next if $Self->{RequestURI} !~ /^$Target$/;

        push @RelevantPermissions, $Permission;

        # immediately break loop on DENY
        last if (($Permission->{Value} & Kernel::System::Role::Permission::PERMISSION->{DENY})
            == Kernel::System::Role::Permission::PERMISSION->{DENY});
    }

    # do something if we have at least one permission
    if ( IsArrayRefWithData(\@RelevantPermissions) ) {

        my $ResultingPermission = -1;

        # check each permission and merge them for each attribute
        my %AttributePermissions;
        PERMISSION:
        foreach my $Permission ( @RelevantPermissions ) {

            my ( $Object, $Attributes, $Condition, @AttributeList);

            if ( !$Permission->{IsWildcard} ) {
                # extract property value permission
                next if $Permission->{Target} !~ /^.*?\{(\w+)\.\[(.*?)\](\s*IF\s+(.*?)\s*)?\}$/;

                ( $Object, $Attributes, $Condition) = ( $1, $2, $4 );
                @AttributeList = split(/\s*,\s*/, $Attributes);

                # check the condition if there is any
                if ( $Condition ) {
                    # inspect the object data (we try to use the cached data from the previous object level permission check)
                    my $ObjectData = $Self->{PermissionCheckObjectDataCache} || {};

                    if ( !IsHashRefWithData($ObjectData) ) {
                        if ( $Self->{RequestMethod} eq 'POST' ) {
                            # we have to use the object given in the request data
                            $ObjectData = $Param{Data};
                        }
                        elsif ( $Self->{RequestMethod} ne 'GET' && IsHashRefWithData($Self->{AvailableMethods}->{GET}) && $Self->{AvailableMethods}->{GET}->{Operation} ) {

                            # get the object data from the DB using a faked GET operation (we are ignoring permissions, just to get the data)
                            # a GET request will be handled differently
                            my $GetResult = $Self->ExecOperation(
                                RequestMethod     => 'GET',
                                OperationType     => $Self->{AvailableMethods}->{GET}->{Operation},
                                Data              => $Param{Data},
                                IgnorePermissions => 1,
                            );

                            if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
                                next PERMISSION;
                            }

                            $ObjectData = $GetResult->{Data};
                        }

                        # cache it for later use in the next iterations
                        $Self->{PermissionCheckObjectDataCache} = $ObjectData;
                    }

                    my $CheckResult = $Self->_CheckPermissionCondition(
                        Permission => $Permission,
                        Condition  => $Condition,
                        Data       => $ObjectData
                    );

                    # if we don't have a GET request and the condition doesn't match, we can ignore this permission
                    next PERMISSION if $Self->{RequestMethod} ne 'GET' && !$CheckResult;
                }
            }
            else {
                $Object = '*';
                @AttributeList = ( '*' );
            }

            $Self->_PermissionDebug($Self->{LevelIndent},  sprintf( "found relevant permission (Property) on target \"%s\" with value 0x%04x", $Permission->{Target}, $Permission->{Value} ) );

            foreach my $Attribute (sort @AttributeList) {
                # init
                $AttributePermissions{"$Object.$Attribute"}->{Value} = 0 if !exists $AttributePermissions{"$Object.$Attribute"};
                $AttributePermissions{"$Object.$Attribute"}->{Value} |= $Permission->{Value};

                if ( $Self->{RequestMethod} eq 'GET' && $Permission->{ConditionFilter} ) {
                    # if we have a GET request, we have to store the condition filter to later handling
                    $AttributePermissions{"$Object.$Attribute"}->{Condition}       = $Condition;
                    $AttributePermissions{"$Object.$Attribute"}->{ConditionFilter} = $Permission->{ConditionFilter};
                }
            }
        }

        # if there is a wildcard permission we need to apply it to all non wildcard permissions
        if ( IsHashRefWithData($AttributePermissions{'*.*'}) ) {
            foreach my $Attribute ( sort keys %AttributePermissions ) {
                next if $Attribute eq '*.*';
                $AttributePermissions{$Attribute}->{Value} |= $AttributePermissions{'*.*'}->{Value} || 0;
            }
        }

        my %SeenAttributes;
        foreach my $Attribute ( sort keys %AttributePermissions ) {

            my $ResultingPermissionShort = $Kernel::OM->Get('Role')->GetReadablePermissionValue(
                Value  => $AttributePermissions{$Attribute}->{Value},
                Format => 'Short'
            );

            $Self->_PermissionDebug($Self->{LevelIndent}, "resulting configured Property permission for property \"$Attribute\": $ResultingPermissionShort");

            if ( $Self->{RequestMethod} eq 'GET' ) {
                # add attribute to field selector
                my ($Object, $AttributeName) = split(/\./, $Attribute, 2);

                # init field selector
                $Self->{PermissionFieldSelector}->{$Object} = [ { Auto => 1, Field => $Self->{OperationConfig}->{ObjectID} || 'ID' } ] if !exists $Self->{PermissionFieldSelector}->{$Object};

                my $Ignore = '';
                if ( ( $AttributePermissions{$Attribute}->{Value} & Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) != Kernel::System::Role::Permission::PERMISSION->{$PermissionName}
                    || ( $AttributePermissions{$Attribute}->{Value} & Kernel::System::Role::Permission::PERMISSION->{DENY} ) == Kernel::System::Role::Permission::PERMISSION->{DENY}
                ) {
                    # access is denied, so we have to add an ignore selector for this attribute
                    $Ignore = '!'
                }

                # resolve double negations in case of NOT in DENY
                my $ResultingFieldSelector = "$Ignore$AttributeName";
                $ResultingFieldSelector =~ s/^!!//g;

                my %TmpHash = (
                    Field => $ResultingFieldSelector
                );
                if ( exists $AttributePermissions{$Attribute}->{ConditionFilter} ) {
                    $TmpHash{Condition}       = $AttributePermissions{$Attribute}->{Condition};
                    $TmpHash{ConditionFilter} = $AttributePermissions{$Attribute}->{ConditionFilter};
                }

                push @{$Self->{PermissionFieldSelector}->{$Object}}, \%TmpHash;
            }
            else {
                # we need a flat data structure to easily find the attributes
                my $FlatData = $Kernel::OM->Get('Main')->Flatten(
                    Data => $Param{Data},
                );

                # check if the attribute exists in the Data hash
                my $LookupAttribute = $Attribute;
                my $Not = 0;
                if ( $LookupAttribute =~ /^(.*?)\.!(.*?)$/ ) {
                    $Not = 1;
                    $LookupAttribute = "$1.$2";
                }
                $LookupAttribute =~ s/\./\\./g;
                $LookupAttribute =~ s/\*/.*?/g;
                my @MatchingAttributes = grep /^$LookupAttribute$/, keys %{$FlatData};

                foreach my $MatchingAttribute ( @MatchingAttributes ) {

                    # ignore everything we have already handled so far
                    next if $SeenAttributes{$MatchingAttribute};

                    my $IsPermissionMatch = ( $AttributePermissions{$Attribute}->{Value} & Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) == Kernel::System::Role::Permission::PERMISSION->{$PermissionName} || 0;
                    my $IsDeny            = ( $AttributePermissions{$Attribute}->{Value} & Kernel::System::Role::Permission::PERMISSION->{DENY} )            == Kernel::System::Role::Permission::PERMISSION->{DENY} || 0;

                    $Self->_PermissionDebug($Self->{LevelIndent}.'    ', "found property \"$MatchingAttribute\" (Not: $Not, $PermissionName permission: $IsPermissionMatch, DENY: $IsDeny)");

                    if ( !$Not && !$IsPermissionMatch || $Not && $IsPermissionMatch || $IsDeny ) {
                        $Self->_PermissionDebug($Self->{LevelIndent}, "request data doesn't match the required criteria - denying request" );

                        # return 403, because we don't have permission to execute this
                        return $Self->_Error(
                            Code => 'Forbidden',
                        );
                    }
                    else {
                        $Self->_PermissionDebug($Self->{LevelIndent}.'        ', "$PermissionName permission granted");
                    }

                    # for later lookup
                    $SeenAttributes{$MatchingAttribute} = 1;
                }
            }
        }
    }

    return $Self->_Success();
}

=item _CheckPermissionCondition()

check the condition of a permission and return true or false

    my $Result = $CommonObject->_CheckPermissionCondition(
        Permission => {},
        Condition  => '...',
        Data       => ...
    );

=cut

sub _CheckPermissionCondition {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Permission Condition Data)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $UseAnd = 0;

    # check for && and split accordingly
    my @Parts = $Param{Condition} || '';
    if ( $Parts[0] =~ /&&/ ) {
        @Parts = split(/\s+&&\s+/, $Parts[0]);

        # the single parts of the condition are a part of a logical AND
        $UseAnd = 1;
    }

    my $Not = 0;
    my %Filter;
    my @FilteredObjects;

    PART:
    foreach my $Part ( @Parts ) {
        my ( $Object, $Attribute, $Operator, $Value );
        $Not = 0; # reset Not

        next if $Part !~ /^(\w+)\.(\w+)\s+(!?\w+)\s+(.*?)$/;

        ( $Object, $Attribute, $Operator, $Value ) = ( $1, $2, $3, $4 );
        if ( $Operator =~ /^!(.*?)$/ ) {
            $Not      = 1;
            $Operator = $1;
        }

        # replace string quotes
        $Value =~ s/["']//g;

        # prepare value for IN operator
        if ( $Operator eq 'IN' || $Operator eq '!IN' ) {
            if ( $Value =~ /^(\[(.*?)\]|\$.*?)$/ ) {
                my @ValueParts;
                foreach my $ValueItem ( split(/\s*,\s*/, $2||$1) ) {
                    my $ValuePart = $Self->_ReplaceVariablesInPermission(Data => $ValueItem);
                    if ( IsArrayRef($ValuePart) ) {
                        push @ValueParts, @{$ValuePart};
                    }
                    else {
                        push @ValueParts, $ValuePart;
                    }
                }
                $Value = \@ValueParts;
            }
        }
        else {
            $Value = $Self->_ReplaceVariablesInPermission(
                Data => $Value
            );
        }

        # add a filter accordingly
        my %Result = $Self->_CreateFilterForObject(
            Filter   => \%Filter,
            Object   => $Object,
            Field    => $Attribute,
            Operator => $Operator,
            Value    => $Value,
            Not      => $Not,
            UseAnd   => $UseAnd,
        );
        if ( !%Result ) {
            # we can't generate the filter, so this is a false
            $Self->_PermissionDebug($Self->{LevelIndent}, sprintf("Unable to create object filter for condition part \"%s\"!", $Part) );
            return;
        }

        push @FilteredObjects, $Object;
    }

    if ( $Self->{RequestMethod} ne 'GET' ) {
        my %ObjectDataToFilter = %{$Param{Data}};        # a deref is required here, because the filter method will change the data

        # we use the permission filters in order to apply them to the given object
        $Self->_ApplyFilter(
            Data               => \%ObjectDataToFilter,
            Filter             => \%Filter,
            IsPermissionFilter => 1,
        );

        # check if the condition is true
        my $Result = 1;
        foreach my $FilteredObject ( @FilteredObjects ) {
            if ( !defined $ObjectDataToFilter{$FilteredObject} ) {
                $Result = 0;
                last;
            }
        }

        if ( $Result ) {
            $Self->_PermissionDebug($Self->{LevelIndent}, sprintf("Permission condition \"%s\" matches", $Param{Condition}) );
        }
        else {
            $Self->_PermissionDebug($Self->{LevelIndent}, sprintf("Permission condition \"%s\" does not match", $Param{Condition}) );
        }

        return $Result;
    }
    else {
        # we have a GET request - this has to be handled later, after the execution of the operation
        $Param{Permission}->{ConditionFilter} = \%Filter;
    }

    return 1;
}

=item _CreateFilterForObject()

create a filter

    my %Filter = $CommonObject->_CreateFilterForObject(
        Filter         => {},            # optional, if given the method adds the new filter the the existing one
        Object         => 'Ticket',
        Field          => 'QueueID',
        Operator       => 'EQ',
        Value          => 12,
        Not            => 0|1,           # optional, default 0
        UseAnd         => 0|1,           # optional, default 0
        StopAfterMatch => 0|1,           # optional, default 0
        AlwaysTrue     => 1              # optional, used for Wildcards
    );

=cut

sub _CreateFilterForObject {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{AlwaysTrue} ) {
        for my $Needed (qw(Object Field Operator Value)) {
            if ( !defined $Param{$Needed} ) {

                # use Forbidden here to prevent access to data
                return;
            }
        }
    }

    my $Logical = $Param{UseAnd} ? 'AND' : 'OR';

    my %Filter;
    $Filter{ $Param{Object} }->{$Logical} = [];
    push( @{ $Filter{ $Param{Object} }->{$Logical} }, { %Param } );

    if ( IsHashRef($Param{Filter}) ) {
        $Param{Filter}->{ $Param{Object} } //= {};
        $Param{Filter}->{ $Param{Object} }->{$Logical} //= [];
        push( @{ $Param{Filter}->{ $Param{Object} }->{$Logical} }, { %Param } );
    }

    return %Filter;
}

=item _ReplaceVariablesInPermission()

replaces special variables in permission expressions with actual value

    my $ReplacedData = $CommonObject->_ReplaceVariablesInPermission(
        Data => '...'
    );

=cut

sub _ReplaceVariablesInPermission {
    my ( $Self, %Param ) = @_;
    my $Result = $Param{Data};

    return $Param{Data} if !$Param{Data};

    # handle CurrentUser variable
    if ( $Param{Data} =~ /^\$CurrentUser\.(.*?)$/ ) {
        my $Attribute = $1;

        # get user data
        my %User = $Kernel::OM->Get('User')->GetUserData(
            UserID => $Self->{Authorization}->{UserID},
        );

        if ( %User ) {
            # get contact for user
            my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                UserID => $Self->{Authorization}->{UserID},
            );
            if ( %Contact ) {
                if ( $Contact{PrimaryOrganisationID} ) {
                    # get primary organisation of contact
                    my %Organisation = $Kernel::OM->Get('Organisation')->OrganisationGet(
                        ID => $Contact{PrimaryOrganisationID},
                    );
                    if ( %Organisation ) {
                        $Contact{PrimaryOrganisation} = \%Organisation;
                    }
                }

                $User{Contact} = \%Contact;
            }

            # add roles
            my @RoleIDs = $Kernel::OM->Get('Role')->UserRoleList(
                UserID => $Self->{Authorization}->{UserID},
                Valid  => 1,
            );
            my %Roles = $Kernel::OM->Get('Role')->RoleList(
                Valid => 1,
            );
            $User{Roles} = [ map { $Roles{$_} } @RoleIDs ];
        }

        $Result = $Self->_ResolveVariableValue(
            Variable => $Attribute,
            Data     => \%User
        );
    }

    return $Result;
}

sub _ResolveVariableValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Variable} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Variable!"
        );
        return;
    }

    # return undef if we have no data to work through
    return if exists $Param{Data} && !$Param{Data};

    my $Data = $Param{Data};

    my @Parts = split( /\./, $Param{Variable});
    my $Attribute = shift @Parts;
    my $ArrayIndex;

    if ( $Attribute =~ /(.*?):(\d+)/ ) {
        $Attribute = $1;
        $ArrayIndex = $2;
    }

    # get the value of $Attribute
    $Data = $Data->{$Attribute};

    if ( defined $ArrayIndex && IsArrayRef($Data) ) {
        $Data = $Data->[$ArrayIndex];
    }

    if ( @Parts ) {
        return $Self->_ResolveVariableValue(
            Variable => join('.', @Parts),
            Data     => $Data,
        );
    }

    return $Data;
}

sub _RunParallel {
    my ( $Self, $Sub, %Param ) = @_;

    # check needed stuff
    if ( !ref $Sub eq 'CODE' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Sub as a function ref!",
        );
        return;
    }

    for my $Needed (qw(Items)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    use threads;
    use threads::shared;
    use Thread::Queue;

    my $NumWorkers = $Self->_CanRunParallel(%Param);

    my $WorkQueue : shared;
    $WorkQueue = Thread::Queue->new();
    my $ResultQueue : shared;
    $ResultQueue = Thread::Queue->new();

    $Self->_Debug("executing with parallel algorithm ($NumWorkers workers) ");

    # create parallel instances
    my %Workers;
    foreach my $WorkerID ( 1..$NumWorkers ) {
        $Workers{$WorkerID}, threads->create(
            sub {
                my ( $Self, %Param ) = @_;

                my $DBDPg_VERSION = $DBD::Pg::{VERSION};

                local $Kernel::OM = Kernel::System::ObjectManager->new(
                    'Log' => {
                        LogPrefix => 'runworker#'.$Param{WorkerID},
                    },
                );

                $Kernel::OM->{ParallelProcessing} = 1;

                $Kernel::OM->Get('DB')->Disconnect();
                $DBD::Pg::VERSION = $DBDPg_VERSION;

                while ( (my $Item = $Param{WorkQueue}->dequeue) ne "END_OF_QUEUE" ) {
                    my $Result = $Sub->($Self, Item => $Item, %Param);

                    $ResultQueue->enqueue(Storable::freeze {
                        Item   => $Item,
                        Result => $Result,
                    });
                }

                $Kernel::OM->{ParallelProcessing} = 0;
            },
            $Self,
            %Param,
            WorkQueue   => $WorkQueue,
            ResultQueue => $ResultQueue,
            WorkerID    => $WorkerID,
        );
    }

    $WorkQueue->enqueue(@{$Param{Items}});

    foreach ( 1..$NumWorkers ) {
        $WorkQueue->enqueue("END_OF_QUEUE");
    }

    foreach my $t ( threads->list() ) {
        $t->join();
    }

    # sync thread output
    my %ResultHash;
    while ( my $Result = Storable::thaw $ResultQueue->dequeue_nb() ) {
        $ResultHash{$Result->{Item}} = $Result->{Result};
    }

    my @Result;
    foreach my $Item ( @{$Param{Items}} ) {
        next if !$ResultHash{$Item};
        push @Result, $ResultHash{$Item};
    }

    $Self->{ParallelProcessing} = 0;

    return @Result;
}

sub _CanRunParallel {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Items)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # check if deactivated
    return 0 if !$Kernel::OM->Get('Config')->Get('API::Parallelity');

    # no further parallel processes if we are already in a parallel state
    return 0 if $Kernel::OM->{ParallelProcessing};

    my $Workers = $Kernel::OM->Get('Config')->Get('API::Parallelity::Workers');

    my $WorkerCount = 0;

    THRESHOLD:
    foreach my $Threshold ( sort { $b cmp $a } keys %{$Workers} ) {
        if ( scalar(@{$Param{Items}}) >= $Threshold ) {
            $WorkerCount = $Workers->{$Threshold};
            last THRESHOLD;
        }
    }

    return $WorkerCount;
}

sub _Debug {
    my ( $Self, $Indent, $Message ) = @_;

    return if ( !$Kernel::OM->Get('Config')->Get('API::Debug') );

    $Indent ||= '';

    printf STDERR "%f (%5i) %-15s %s%s: %s\n", Time::HiRes::time(), $$, "[API]", $Indent, $Self->{OperationConfig}->{Name}, "$Message";
}

sub _PermissionDebug {
    my ( $Self, $Indent, $Message ) = @_;

    return if ( !$Kernel::OM->Get('Config')->Get('Permission::Debug') );

    $Indent ||= '';

    printf STDERR "%f (%5i) %-15s %s%s\n", Time::HiRes::time(), $$, "[Permission]", $Indent, $Message;
}

=item _CheckCustomerAssignedObject()

checks the object ids for current customer user if necessary

    my $CustomerCheck = $OperationObject->_CheckCustomerAssignedObject(
        ObjectType => 'Ticket'
        IDList     => [1,2,3] | 1            # array ref or number
        ...                                  # optional additional params
    );

    returns:

    $CustomerCheck = {
        Success => 1,                     # if everything is OK
    }

    $CustomerCheck = {
        Code    => 'Forbidden',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckCustomerAssignedObject {
    my ( $Self, %Param ) = @_;

    my $IDList = $Param{IDList};
    if ( $IDList && !IsArrayRefWithData($IDList) ) {
        $IDList = [ $IDList ];
    }

    if (
        $Param{ObjectType} &&
        IsArrayRefWithData($IDList) &&
        IsHashRefWithData($Self->{Authorization}) &&
        $Self->{Authorization}->{UserType} eq 'Customer'
    ) {
        my @ObjectIDList = $Self->_FilterCustomerUserVisibleObjectIds(
            %Param,
            ObjectIDList => $IDList
        );
        my %IDListHash = map { $_ => 1 } @ObjectIDList;

        foreach my $ID ( @{ $IDList } ) {

            if ( !$IDListHash{$ID} ) {
                return $Self->_Error(
                    Code => 'Forbidden',
                    Message => "Could not access $Param{ObjectType} with id $ID"
                );
            }
        }
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _FilterCustomerUserVisibleObjectIds()

filters ids for current customer user if necessary

    @FilteredObjectIDList = $Self->_FilterCustomerUserVisibleObjectIds(
        ObjectType   => 'Ticket'
        ObjectIDList => \@ObjectIDList,
        ...                                 # optional additional params
    )

=cut

sub _FilterCustomerUserVisibleObjectIds {
    my ( $Self, %Param ) = @_;

    my @ObjectIDList = IsArrayRefWithData($Param{ObjectIDList}) ? @{$Param{ObjectIDList}} : ();

    # check if customer context
    if (
        $Param{ObjectType} &&
        IsArrayRefWithData(\@ObjectIDList) &&
        IsHashRefWithData($Self->{Authorization}) &&
        $Self->{Authorization}->{UserType} eq 'Customer'
    ) {

        # get object relevant ids
        my $ItemIDs = $Self->_GetCustomerUserVisibleObjectIds(
            %Param
        );

        # keep relevant ids
        if ( IsArrayRefWithData($ItemIDs) ) {
            my %ItemIDsHash = map { $_ => 1 } @{$ItemIDs};
            my @Result;
            for my $ObjectID ( @ObjectIDList ) {
                push(@Result, 0 + $ObjectID) if $ItemIDsHash{$ObjectID};
            }
            @ObjectIDList = @Result;
        } else {
            @ObjectIDList = ();
        }
    }

    return @ObjectIDList;
}
=item _GetCustomerUserVisibleObjectIds()

returns object ids for current customer user if necessary

    @ObjectIDList = $Self->_FilterCustomerUserVisibleObjectIds(
        ObjectType   => 'Ticket'
        ...                         # optional additional params
    )

=cut

sub _GetCustomerUserVisibleObjectIds {
    my ( $Self, %Param ) = @_;

    # check if customer context
    if (
        $Param{ObjectType} &&
        IsHashRefWithData($Self->{Authorization}) &&
        $Self->{Authorization}->{UserType} eq 'Customer'
    ) {

        # get contact data
        my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
            UserID        => $Self->{Authorization}->{UserID},
            DynamicFields => 1
        );

        # get object relevant ids
        if ( IsHashRefWithData(\%ContactData) ) {

            # get user data
            if (!$ContactData{User} && $ContactData{AssignedUserID}) {
                my $UserData = $Self->ExecOperation(
                    OperationType => 'V1::User::UserGet',
                    Data          => {
                        UserID => $ContactData{AssignedUserID},
                    }
                );
                $ContactData{User} = ($UserData->{Success}) ? $UserData->{Data}->{User} : undef;
                $Self->AddCacheDependency(Type => 'User');
            }

            # handle relevant organisation id
            # if not given use primary
            my @RelevantIDs = split(/\s*,\s*/, $Param{RelevantOrganisationID} // $ContactData{PrimaryOrganisationID});
            # make sure given id belongs to contact, else given id is not usable
            my @ValidRelevantIDs;
            my %ContactOrgaIDs = map{ $_ => 1 } @{ $ContactData{OrganisationIDs} };
            for my $RelevantID (@RelevantIDs) {
                next if ( !$ContactOrgaIDs{$RelevantID} );
                push(@ValidRelevantIDs, $RelevantID);
            }
            $ContactData{RelevantOrganisationID} = \@ValidRelevantIDs if (scalar @ValidRelevantIDs);

            if ($Param{ObjectType} eq 'ConfigItem') {
                my @IDs = $Kernel::OM->Get('ObjectSearch')->Search(
                    Search => {
                        AND => [
                            {
                                Field => 'AssignedContact',
                                Operator => 'EQ',
                                Type     => 'NUMERIC',
                                Value    => $ContactData{ID}
                            },
                            {
                                Field => 'AssignedOrganisation',
                                Operator => 'IN',
                                Type     => 'NUMERIC',
                                Value    => $ContactData{RelevantOrganisationID} || $ContactData{PrimaryOrganisationID}
                            }
                        ]
                    },
                    Result     => 'ARRAY',
                    ObjectType => 'ConfigItem',
                    UserID     => $Self->{Authorization}->{UserID},
                    UserType   => $Self->{Authorization}->{UserType}
                );
                return scalar(@IDs) ? \@IDs : [];
            } elsif ($Param{ObjectType} eq 'Ticket') {
                return $Kernel::OM->Get('Ticket')->GetAssignedTicketsForObject(
                    %Param,
                    ObjectType => 'Contact',
                    Object     => \%ContactData,
                    UserID     => $Self->{Authorization}->{UserID},
                    UserType   => $Self->{Authorization}->{UserType},
                );
            } elsif ($Param{ObjectType} eq 'TicketArticle') {
                return $Kernel::OM->Get('Ticket')->GetAssignedArticlesForObject(
                    %Param,
                    ObjectType => 'Contact',
                    Object     => \%ContactData,
                    UserID     => $Self->{Authorization}->{UserID},
                    UserType   => $Self->{Authorization}->{UserType},
                );
            } elsif ($Param{ObjectType} eq 'FAQArticle') {
                my @IDs = $Kernel::OM->Get('ObjectSearch')->Search(
                    Search => {
                        AND => [
                            {
                                Field => 'AssignedContact',
                                Operator => 'EQ',
                                Type     => 'NUMERIC',
                                Value    => $ContactData{ID}
                            }
                        ]
                    },
                    Result     => 'ARRAY',
                    ObjectType => 'FAQArticle',
                    UserID     => $Self->{Authorization}->{UserID},
                    UserType   => $Self->{Authorization}->{UserType}
                );
                return scalar(@IDs) ? \@IDs : [];
            }
        }
    }

    return;
}

=item _CheckDynamicField()

checks if the given dynamic field parameter is valid.

    my $DynamicFieldCheck = $OperationObject->_CheckDynamicField(
        DynamicField => $DynamicField,              # all dynamic field parameters
        ObjectType   => 'Ticket'
    );

    returns:

    $DynamicFieldCheck = {
        Success => 1,                               # if everything is OK
    }

    $DynamicFieldCheck = {
        Code    => 'Function.Error',           # if error
        Message => 'Error description',
    }

=cut

sub _CheckDynamicField {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(DynamicField ObjectType)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "_CheckDynamicField() No $Needed given!"
            );
        }
    }

    # get the dynamic fields
    my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => [ $Param{ObjectType} ],
    );

    # create a Dynamic Fields lookup table (by name)
    DYNAMICFIELD:
    for my $DynamicField ( @{$DynamicFieldList} ) {
        next DYNAMICFIELD if !$DynamicField;
        next DYNAMICFIELD if !IsHashRefWithData($DynamicField);
        next DYNAMICFIELD if !$DynamicField->{Name};
        $Self->{DynamicFieldLookup}->{ $DynamicField->{Name} } = $DynamicField;
    }

    my $DynamicField = $Param{DynamicField};

    # check DynamicField item internally
    for my $Needed (qw(Name Value)) {
        if (
            !defined $DynamicField->{$Needed}
            || ( !IsString( $DynamicField->{$Needed} ) && ref $DynamicField->{$Needed} ne 'ARRAY' )
            )
        {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "Parameter DynamicField::$Needed is missing!",
            );
        }
    }

    # check DF access
    if ( $Self->{Authorization}->{UserType} eq 'Customer' && !$Self->{DynamicFieldLookup}->{ $DynamicField->{Name} }->{CustomerVisible} ) {
        return $Self->_Error(
            Code    => 'Forbidden',
            Message => "DynamicField \"$DynamicField->{Name}\" cannot be set!",
        );
    }

    # check DynamicField->Name
    if ( !$Self->_ValidateDynamicFieldName( %{$DynamicField} ) ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Parameter DynamicField::Name is invalid!",
        );
    }

    # check DynamicField->Value
    if ( !$Self->_ValidateDynamicFieldObjectType( %{$DynamicField}, ObjectType => $Param{ObjectType} ) ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Parameter DynamicField is invalid for object type \"$Param{ObjectType}\"!",
        );
    }

    # check DynamicField->Value
    if ( !$Self->_ValidateDynamicFieldValue( %{$DynamicField} ) ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Parameter DynamicField::Value is invalid!",
        );
    }

    # if everything is OK then return Success
    return $Self->_Success();
}

=item _ValidateDynamicFieldName()

checks if the given dynamic field name is valid.

    my $Success = $CommonObject->_ValidateDynamicFieldName(
        Name => 'some name',
    );

    returns
    $Success = 1            # or 0

=cut

sub _ValidateDynamicFieldName {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );
    return if !$Param{Name};

    return if !$Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup}->{ $Param{Name} } );

    return 1;
}

=item _ValidateDynamicFieldValue()

checks if the given dynamic field value is valid.

    my $Success = $CommonObject->_ValidateDynamicFieldValue(
        Name  => 'some name',
        Value => 'some value',          # String or Integer or DateTime format
    );

    my $Success = $CommonObject->_ValidateDynamicFieldValue(
        Value => [                      # Only for fields that can handle multiple values like
            'some value',               #   Multiselect
            'some other value',
        ],
    );

    returns
    $Success = 1                        # or 0

=cut

sub _ValidateDynamicFieldValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );

    # possible structures are string and array, no data inside is needed
    if ( !IsString( $Param{Value} ) && ref $Param{Value} ne 'ARRAY' ) {
        return;
    }

    # get dynamic field config
    my $DynamicFieldConfig = $Self->{DynamicFieldLookup}->{ $Param{Name} };

    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    for my $Value (@Values) {
        my $ValueTypeResult = $Kernel::OM->Get('DynamicField::Backend')->ValueValidate(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Value,
            UserID             => 1,
        );
        return if (!$ValueTypeResult);
    }

    return 1;
}

=item _ValidateDynamicFieldObjectType()

checks if the given dynamic field object type is valid.

    my $Success = $CommonObject->_ValidateDynamicFieldObjectType(
        Name       => 'some name',
        ObjectType => 'Ticket'
    );

    returns
    $Success = 1            # or 0

=cut

sub _ValidateDynamicFieldObjectType {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup} );
    return if !$Param{Name};

    return if !$Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if !IsHashRefWithData( $Self->{DynamicFieldLookup}->{ $Param{Name} } );

    my $DynamicFieldConfg = $Self->{DynamicFieldLookup}->{ $Param{Name} };
    return if $DynamicFieldConfg->{ObjectType} ne $Param{ObjectType};

    return 1;
}

=item _SetDynamicFieldValue()

sets the value of a dynamic field.

    my $Result = $CommonObject->_SetDynamicFieldValue(
        Name       => 'some name',           # the name of the dynamic field
        Value      => 'some value',          # String or Integer or DateTime format
        ObjectID   => 123
        ObjectType => 123
        UserID     => 123,
    );

    returns

    $Result = {
        Success => 1,                        # if everything is ok
    }

    $Result = {
        Success      => 0,
        ErrorMessage => 'Error description'
    }

=cut

sub _SetDynamicFieldValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserID ObjectID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "_SetDynamicFieldValue() No $Needed given!"
            );
        }
    }

    # check needed stuff
    for my $Needed (qw(Name ObjectType)) {
        if ( !IsString( $Param{$Needed} ) ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "_SetDynamicFieldValue() Invalid value for $Needed, just string is allowed!"
            );
        }
    }

    # get the dynamic fields
    my $DynamicFieldList = $Kernel::OM->Get('DynamicField')->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => [ $Param{ObjectType} ],
    );

    # create a Dynamic Fields lookup table (by name)
    DYNAMICFIELD:
    for my $DynamicField ( @{$DynamicFieldList} ) {
        next DYNAMICFIELD if !$DynamicField;
        next DYNAMICFIELD if !IsHashRefWithData($DynamicField);
        next DYNAMICFIELD if !$DynamicField->{Name};
        $Self->{DynamicFieldLookup}->{ $DynamicField->{Name} } = $DynamicField;
    }

    # check value structure
    if ( !IsString( $Param{Value} ) && ref $Param{Value} ne 'ARRAY' && defined($Param{Value}) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "_SetDynamicFieldValue() Invalid value for Value, just string, array and undef is allowed!"
        );
    }

    if ( !IsHashRefWithData( $Self->{DynamicFieldLookup} ) ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "_SetDynamicFieldValue() No DynamicFieldLookup!"
        );
    }

    # get dynamic field config
    my $Config = $Self->{DynamicFieldLookup}->{ $Param{Name} };

    if ( !$Config ) {
        return $Self->_Error(
            Code    => 'Operation.InternalError',
            Message => "_SetDynamicFieldValue() no matching dynamic field found for \"$Param{Name}\"!"
        );
    }

    my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $Config,
        ObjectID           => $Param{ObjectID},
        Value              => $Param{Value},
        UserID             => $Param{UserID},
    );
    if ( !$Success ) {
        # get the last error log entry as the message
        my $Message = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => $Message,
        );
    }

    return $Self->_Success();
}

=item _GetPrepareDynamicFieldValue()

prepares the value of a dynamic field

    my $Result = $CommonObject->_GetPrepareDynamicFieldValue(
        Config          => $Param{Config}HashRef,
        Value           => 'some value',          # String or Integer or DateTime format
        NoDisplayValues => [<DF types>],          # do not prepare the display value for those DF types
    );

    returns

    $Result = {
        ID                => 123,
        Name              => 'someDFName',
        Label             => 'Some label',
        Value             => [5, 10]
        DisplayValue      => 'Value1, Value2'        # configured separator is used, else ', '
        DisplayValueHTML  => 'Value1, Value2'        # if special html value is possible (e.g. for checklists), else DisplayValue
        DisplayValueShort => 'Value1, Value2'        # if special short value is possible (e.g. for checklists), else DisplayValue
        PreparedValue     => ['Value1', 'Value2']
    }

=cut

sub _GetPrepareDynamicFieldValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Config Value)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "_PrepareDynamicFieldValue() No $Needed given!" );
            return;
        }
    }

    my %NoPrepare = map { $_ => 1 } @{$Param{NoDisplayValues} || []};

    if ( !$NoPrepare{$Param{Config}->{FieldType}} ) {

        # set language in layout object
        my $Language = $Kernel::OM->Get('User')->GetUserLanguage(
            UserID => $Self->{Authorization}->{UserID},
        );
        $Kernel::OM->ObjectParamAdd(
            'Output::HTML::Layout' => {
                UserLanguage => $Language,
            },
        );

        # add cache dependencies
        my $Dependencies = $Kernel::OM->Get('DynamicField::Backend')->GetCacheDependencies(
            DynamicFieldConfig => $Param{Config}
        );
        if ( IsArrayRefWithData($Dependencies) ) {
            $Self->AddCacheDependency(Type => join( ',', @{$Dependencies} ));
        }

        # get prepared value
        my $DFPreparedValue = $Kernel::OM->Get('DynamicField::Backend')->ValueLookup(
            DynamicFieldConfig => $Param{Config},
            Key                => $Param{Value}
        );

        # get display value string
        my $DisplayValue = $Kernel::OM->Get('DynamicField::Backend')->DisplayValueRender(
            DynamicFieldConfig => $Param{Config},
            Value              => $Param{Value},
            HTMLOutput         => 0
        );

        if (!IsHashRefWithData($DisplayValue)) {
            my $Separator = ', ';
            if (
                IsHashRefWithData($Param{Config}) &&
                IsHashRefWithData($Param{Config}->{Config}) &&
                defined $Param{Config}->{Config}->{ItemSeparator}
            ) {
                $Separator = $Param{Config}->{Config}->{ItemSeparator};
            }

            my @Values;
            if ( ref $DFPreparedValue eq 'ARRAY' ) {
                @Values = @{ $DFPreparedValue };
            }
            else {
                @Values = ($DFPreparedValue);
            }

            $DisplayValue = {
                Value => join($Separator, @Values)
            };
        }

        # get html display value string
        my $DisplayValueHTML = $Kernel::OM->Get('DynamicField::Backend')->HTMLDisplayValueRender(
            DynamicFieldConfig => $Param{Config},
            Value              => $Param{Value}
        );

        # get short display value string
        my $DisplayValueShort = $Kernel::OM->Get('DynamicField::Backend')->ShortDisplayValueRender(
            DynamicFieldConfig => $Param{Config},
            Value              => $Param{Value},
            HTMLOutput         => 0
        );

        return {
            ID                => $Param{Config}->{ID},
            Name              => $Param{Config}->{Name},
            Label             => $Param{Config}->{Label},
            Value             => $Param{Value},
            DisplayValue      => $DisplayValue->{Value},
            DisplayValueHTML  => $DisplayValueHTML ? $DisplayValueHTML->{Value} : $DisplayValue->{Value},
            DisplayValueShort => $DisplayValueShort ? $DisplayValueShort->{Value} : $DisplayValue->{Value},
            PreparedValue     => $DFPreparedValue
        };
    }
    else {
        return {
            ID                => $Param{Config}->{ID},
            Name              => $Param{Config}->{Name},
            Label             => $Param{Config}->{Label},
            Value             => $Param{Value},
        };
    }
}

sub _AddSchemaAndExamples {
    my ( $Self, %Param ) = @_;

    return if (!IsHashRefWithData($Param{Data}));

    my @Directories;

    # get plugin folders
    my @Plugins = $Kernel::OM->Get('Installation')->PluginList(
        Valid     => 1,
        InitOrder => 1
    );
    foreach my $Plugin ( @Plugins ) {
        my $Directory = $Plugin->{Directory} . '/doc/API/V1';
        next if ! -e $Directory;
        push (@Directories, $Directory);
    }

    # get framework folder
    my $Home = $ENV{KIX_HOME} || $Kernel::OM->Get('Config')->Get('Home');
    if ( !$Home ) {
        use FindBin qw($Bin);
        $Home = $Bin.'/..';
    }
    push (@Directories, $Home . '/doc/API/V1');

    foreach my $Type (qw(Request Response)) {
        my $Object = $Self->{OperationConfig}->{ $Type . 'Schema' };
        if ($Object) {

            # add the example if available
            my $Example;
            EXAMPLES:
            for my $Location ( @Directories ) {
                $Example = $Kernel::OM->Get('Main')->FileRead(
                    Location        => "$Location/examples/$Object.json",
                    DisableWarnings => 1
                );
                if ($Example) {
                    last EXAMPLES;
                }
            }

            if ($Example) {
                $Param{Data}->{$Type}->{Example} = $Kernel::OM->Get('JSON')->Decode(
                    Data => $$Example
                );
            } else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "$Type Example for '$Object' not found!"
                );
            }

            # add the schema if available
            my $Schema;
            SCHEMAS:
            for my $Location ( @Directories ) {
                $Schema = $Kernel::OM->Get('Main')->FileRead(
                    Location        => "$Location/schemas/$Object.json",
                    DisableWarnings => 1
                );
                if ($Schema) {
                    last SCHEMAS;
                }
            }

            if ($Schema) {
                $Param{Data}->{$Type}->{JSONSchema} = $Kernel::OM->Get('JSON')->Decode(
                    Data => $$Schema
                );
            } else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "$Type Schema for '$Object' not found!"
                );
            }
        }
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
