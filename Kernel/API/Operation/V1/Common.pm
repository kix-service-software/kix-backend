# --
# Copyright (C) 2006-2021 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Common;

use strict;
use warnings;
use Hash::Flatten;
use File::Basename;
use Data::Sorting qw(:arrays);
use Storable;

BEGIN { $SIG{ __WARN__} = sub { return if $_[0] =~ /in cleanup/ }; }

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Common - Base class for all Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

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

        # check the necessary permission of the parent object if needed
        if ( IsHashRefWithData($Self->{ParentMethodOperationMapping}) && $Self->{ParentMethodOperationMapping}->{$ParentCheckMethod} ) {

            # get the config of the parent operation to determine the primary object ID attribute
            my $OperationConfig = $Kernel::OM->Get('Config')->Get('API::Operation::Module')->{$Self->{ParentMethodOperationMapping}->{$ParentCheckMethod}};

            my $Data = $OperationConfig->{ObjectID} ? {
                    $OperationConfig->{ObjectID} => $Param{Data}->{$OperationConfig->{ObjectID}},
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

        # init meta data
        $Self->{PermissionFilteredObjects} = {};

        # check if we have permission for this object
        my $Result =  $Self->_CheckObjectPermission(
            %Param,
            Data => $Param{Data},
        );
        if ( !$Result->{Success} ) {
            return $Result;
        }

        # check if we have permission for specific properties of this object
        $Result =  $Self->_CheckPropertyPermission(
            %Param,
            Data => $Param{Data},
        );

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

        if ( IsHashRefWithData($CacheResult) ) {
            $Self->_Debug( $Self->{LevelIndent}, "return cached response (Key: " . Dumper($CacheKey) );
            $Self->{'_CachedResponse'} = 1;
            $Result = $Self->_Success(
                %{$CacheResult}
            );
        }
    }

    # run the operation itself if we don't return a cached response
    if ( !$Self->{'_CachedResponse'} ) {
        $Result = $Self->Run(
            %Param,
        );
    }

    # check the result for filtered objects
    if ( $Self->{RequestMethod} eq 'GET' && !$Self->{SuppressPermissionErrors} && IsHashRefWithData($Result) && $Result->{Success} && IsHashRefWithData($Self->{PermissionFilteredObjects}) ) {

        foreach my $Object ( keys %{$Self->{PermissionFilteredObjects}} ) {
            next if !exists $Result->{Data}->{$Object};

            # if the filtered object is undef then we don't have permission to read it
            if ( !$Result->{Data}->{$Object} ) {
                return $Self->_Error(
                    Code => 'Forbidden',
                );
            }
        }
    }


    # log created ID of POST requests
    if ( $Self->{RequestMethod} eq 'POST' && IsHashRefWithData($Result) && $Result->{Success} ) {
        my @Data = %{ $Result->{Data} };
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

    # add the schema if available
    my $SchemaLocation = $Kernel::OM->Get('Config')->Get('API::JSONSchema::Location');
    if ( $SchemaLocation && -d $SchemaLocation ) {
        foreach my $Type (qw(Request Response)) {
            my $Object = $Self->{OperationConfig}->{ $Type . 'Schema' };
            if ($Object) {
                my $Content = $Kernel::OM->Get('Main')->FileRead(
                    Location => "$SchemaLocation/$Object.json",
                );
                if ($Content) {
                    $Data{$Type}->{JSONSchema} = $Kernel::OM->Get('JSON')->Decode(
                        Data => $$Content
                    );
                }
            }
        }
    }

    # add the example if available
    my $ExampleLocation = $Kernel::OM->Get('Config')->Get('API::Example::Location');
    if ( $ExampleLocation && -d $ExampleLocation ) {
        foreach my $Type (qw(Request Response)) {
            my $Object = $Self->{OperationConfig}->{ $Type . 'Schema' };
            if ($Object) {
                my $Content = $Kernel::OM->Get('Main')->FileRead(
                    Location => "$ExampleLocation/$Object.json",
                );
                if ($Content) {
                    $Data{$Type}->{Example} = $Kernel::OM->Get('JSON')->Decode(
                        Data => $$Content
                    );
                }
            }
        }
    }

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
    my $Webservice = $Kernel::OM->Get('API::Webservice')->WebserviceGet(
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
                Type                => 'ARRAY' | 'ARRAYtoHASH',         # optional, use this to parse a comma separated string into an array or a hash with all array entries as keys and 1 as values
                DataType            => 'NUMERIC',                       # optional, use this to force numeric datatype in JSON response
                Required            => 1,                               # optional
                RequiredIfNot       => [ '<AltParameter>', ... ]        # optional, specify the alternate parameters to be checked, if one of them has a value
                RequiredIf          => [ '<Parameter>', ... ]           # optional, specify the parameters that should be checked for values
                RequiresValueIfUsed => 1                                # optional
                Default             => ...                              # optional
                OneOf               => [...]                            # optional
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

    # check needed stuff
    for my $Needed (qw(Data)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'PrepareData.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    # prepare filter
    if ( exists( $Param{Data}->{filter} ) ) {
        my $Result = $Self->_ValidateFilter(
            Filter => $Param{Data}->{filter},
            Type   => 'filter',
        );
        if ( IsHashRefWithData($Result) && exists $Result->{Success} && $Result->{Success} == 0 ) {

            # error occured
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
                my @Fields = split( /\s*;\s*/, $1 );
                $Self->{Fields}->{$Object} = \@Fields;
            }
            else {
                if ( !IsArrayRefWithData( $Self->{Fields}->{$Object} ) ) {
                    $Self->{Fields}->{$Object} = [];
                }
                push @{ $Self->{Fields}->{$Object} }, $Field;
            }
        }
    }

    # prepare limiter
    if ( exists( $Param{Data}->{limit} ) && IsStringWithData( $Param{Data}->{limit} ) ) {
        foreach my $Limiter ( split( /,/, $Param{Data}->{limit} ) ) {
            my ( $Object, $Limit ) = split( /\:/, $Limiter, 2 );
            if ( $Limit && $Limit =~ /^\d+$/ ) {
                $Self->{Limit}->{$Object} = $Limit;
            }
            else {
                $Self->{Limit}->{__COMMON} = $Object;
            }
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

            if ( !IsArrayRefWithData( $Self->{Sorter}->{$Object} ) ) {
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

            my $FlatData = Hash::Flatten::flatten(
                $Param{Data},
                {
                    HashDelimiter => '::',
                }
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

=item HandleSearchInAPI()

Tell the API core to handle the "search" parameter in the API. This is needed for operations that don't handle the "search" parameter and leave the work to the API core.

    $CommonObject->HandleSearchInAPI();

=cut

sub HandleSearchInAPI {
    my ( $Self, %Param ) = @_;

    $Self->{HandleSearchInAPI} = 1;
}

=item _Success()

helper function to return a successful result.

    my $Return = $CommonObject->_Success(
        ...
    );

=cut

sub _Success {
    my ( $Self, %Param ) = @_;

    # ignore cached calues if we have a cached response (see end of Init method)

    # handle Search parameter if we have to
    if ( !$Param{IsOptionsResponse} ) {
        if ( !$Self->{'_CachedResponse'} && $Self->{HandleSearchInAPI} && IsHashRefWithData( $Self->{Search} ) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_ApplyFilter(
                Data   => \%Param,
                Filter => $Self->{Search}
            );

            my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
            $Self->_Debug($Self->{LevelIndent}, sprintf("search in API layer took %i ms", $TimeDiff));
        }

        # honor a filter, if we have one
        if ( !$Self->{'_CachedResponse'} && IsHashRefWithData( $Self->{Filter} ) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_ApplyFilter(
                Data => \%Param,
            );

            my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
            $Self->_Debug($Self->{LevelIndent}, sprintf("filtering took %i ms", $TimeDiff));
        }

        # honor a sorter, if we have one
        if ( !$Self->{'_CachedResponse'} && IsHashRefWithData( $Self->{Sort} ) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_ApplySort(
                Data => \%Param,
            );

            my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
            $Self->_Debug($Self->{LevelIndent}, sprintf("sorting took %i ms", $TimeDiff));
        }

        # honor an offset, if we have one
        if ( !$Self->{'_CachedResponse'} && IsHashRefWithData( $Self->{Offset} ) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_ApplyOffset(
                Data => \%Param,
            );

            my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
            $Self->_Debug($Self->{LevelIndent}, sprintf("applying offset took %i ms", $TimeDiff));
        }

        # honor a limiter, if we have one
        if ( !$Self->{'_CachedResponse'} && IsHashRefWithData( $Self->{Limit} ) ) {
            my $StartTime = Time::HiRes::time();

            $Self->_ApplyLimit(
                Data => \%Param,
            );

            my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
            $Self->_Debug($Self->{LevelIndent}, sprintf("applying limit took %i ms", $TimeDiff));
        }

        # honor permission filters
        if ( IsHashRefWithData( \%Param ) && IsArrayRefWithData( $Self->{PermissionFilters} ) ) {
            my $StartTime = Time::HiRes::time();

            # in case of a GET request to a collection resource, this should have been done in the filter already
            # but we will make sure nothing gets out that should not and we have to honor item resources as well
            $Self->_ApplyFilter(
                Data               => \%Param,
                Filter             => $Self->_GetPermissionFilter(),
                IsPermissionFilter => 1,
            );

            my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
            $Self->_Debug($Self->{LevelIndent}, sprintf("permission filtering took %i ms", $TimeDiff));
        }

        # honor a field selector, if we have one
        if ( !$Self->{'_CachedResponse'} && (IsHashRefWithData( $Self->{Fields} ) || IsHashRefWithData( $Self->{PermissionFieldSelector} )) ) {
            my $StartTime = Time::HiRes::time();

            my $FieldSelector = $Self->{Fields};
            if ( IsHashRefWithData( $Self->{PermissionFieldSelector} ) ) {
                $Self->_Debug($Self->{LevelIndent}, "using permission field selector");
                $FieldSelector = $Self->{PermissionFieldSelector};
            }

            $Self->_ApplyFieldSelector(
                Data   => \%Param,
                Fields => $FieldSelector,
            );

            my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
            $Self->_Debug($Self->{LevelIndent}, sprintf("field selection took %i ms", $TimeDiff));
        }

        if ( !$Self->{PermissionCheckOnly} ) {
            # honor a generic include, if we have one
            if ( !$Self->{'_CachedResponse'} && IsHashRefWithData( $Self->{Include} ) ) {
                my $StartTime = Time::HiRes::time();

                $Self->_ApplyInclude(
                    Data => \%Param,
                );

                my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
                $Self->_Debug($Self->{LevelIndent}, sprintf("including took %i ms", $TimeDiff));
            }

            # honor an expander, if we have one
            if ( !$Self->{'_CachedResponse'} && IsHashRefWithData( $Self->{Expand} ) ) {
                my $StartTime = Time::HiRes::time();

                $Self->_ApplyExpand(
                    Data => \%Param,
                );

                my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
                $Self->_Debug($Self->{LevelIndent}, sprintf("expanding took %i ms", $TimeDiff));
            }
        }

        # cache request without offset and limit if CacheType is set for this operation
        if ( $Kernel::OM->Get('Config')->Get('API::Cache') && !$Self->{'_CachedResponse'} && IsHashRefWithData( \%Param ) && $Self->{OperationConfig}->{CacheType} ) {
            $Self->_CacheRequest(
                Data => \%Param,
            );
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

    $Self->{DebuggerObject}->Error(
        Summary => $Param{Code},
        Data    => $Param{Message},
    );

    # return structure
    return {
        Success => 0,
        Code    => $Param{Code},
        Message => $Param{Message},
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
    my $Webservice = $Kernel::OM->Get('API::Webservice')->WebserviceGet(
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

    # TODO: the following code is nearly identical to the code used in Transport::REST, method ProviderProcessRequest -> should be generalized
    # maybe another solution to execute operations / API calls is needed

    # determine available methods
    my %AvailableMethods;
    for my $CurrentOperation ( sort keys %{ $TransportConfig->{RouteOperationMapping} } ) {

        next if !IsHashRefWithData( $TransportConfig->{RouteOperationMapping}->{$CurrentOperation} );

        my %RouteMapping = %{ $TransportConfig->{RouteOperationMapping}->{$CurrentOperation} };
        my $RouteRegEx = $RouteMapping{Route};
        $RouteRegEx =~ s{:([^\/]+)}{(?<$1>[^\/]+)}xmsg;

        next if !( $RequestURI =~ m{^ $RouteRegEx $}xms );

        $AvailableMethods{ $RouteMapping{RequestMethod}->[0] } = {
            Operation => $CurrentOperation,
            Route     => $RouteMapping{Route}
        };
    }

    # get direct sub-resource for generic including
    my %OperationRouteMapping = (
        $Param{OperationType} => $CurrentRoute
    );
    for my $Op ( sort keys %{ $TransportConfig->{RouteOperationMapping} } ) {
        # ignore invalid config
        next if !IsHashRefWithData( $TransportConfig->{RouteOperationMapping}->{$Op} );
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

    # determine parent mapping as well
    my $ParentObjectRoute = $CurrentRoute;
    $ParentObjectRoute =~ s/^((.*?):(\w+))\/(.+?)$/$1/g;
    $ParentObjectRoute = '' if $ParentObjectRoute eq $CurrentRoute;

    my %ParentMethodOperationMapping;
    if ( $ParentObjectRoute ) {
        for my $Op ( sort keys %{ $TransportConfig->{RouteOperationMapping} } ) {
            # ignore invalid config
            next if !IsHashRefWithData( $TransportConfig->{RouteOperationMapping}->{$Op} );

            # ignore anything that has nothing to do with the parent Ops route
            if ( $ParentObjectRoute ne '/' && "$TransportConfig->{RouteOperationMapping}->{$Op}->{Route}/" !~ /^$ParentObjectRoute\/$/ ) {
                next;
            }
            elsif ( $ParentObjectRoute eq '/' && "$TransportConfig->{RouteOperationMapping}->{$Op}->{Route}/" !~ /^$ParentObjectRoute[:a-zA-Z_]+$\//g ) {
                next;
            }

            my $Method = $TransportConfig->{RouteOperationMapping}->{$Op}->{RequestMethod}->[0];
            $ParentMethodOperationMapping{$Method} = $Op;
        }
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
        DebuggerObject           => $Self->{DebuggerObject},
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
        IgnorePermissions        => $Param{IgnorePermissions},
        SuppressPermissionErrors => $Param{SuppressPermissionErrors},
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
    
    my $Result = $OperationObject->Run(
        Data    => {
            %{$Param{Data} || {}},
            %AdditionalData,
        },
        IgnorePermissions   => $Param{IgnorePermissions},
        PermissionCheckOnly => $Param{PermissionCheckOnly},
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
        'CONTAINS'   => { 'STRING'  => 1 },
        'STARTSWITH' => { 'STRING'  => 1 },
        'ENDSWITH'   => { 'STRING'  => 1 },
        'LIKE'       => { 'STRING'  => 1 },
    );
    my $ValidOperators = join( '|', keys %OperatorTypeMapping );
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
                $Filter->{Operator} = uc( $Filter->{Operator} || '' );
                $Filter->{Type}     = uc( $Filter->{Type}     || 'STRING' );

                # check if filter field is valid
                if ( !$Filter->{Field} ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "No field in $Object.$Filter->{Field}!",
                    );
                }

                # check if filter Operator is valid
                if ( $Filter->{Operator} !~ /^($ValidOperators)$/g ) {
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
                if ( $Filter->{Type} eq 'DATE' && $Filter->{Value} !~ /\d{4}-\d{2}-\d{2}/ && $Filter->{Value} !~ /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/ ) {
                    return $Self->_Error(
                        Code    => 'BadRequest',
                        Message => "Invalid date value $Filter->{Value} in $Object.$Filter->{Field}!",
                    );
                }

                # check DATETIME value
                if ( $Filter->{Type} eq 'DATETIME' && $Filter->{Value} !~ /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/ ) {
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

    if ( !IsHashRefWithData( \%Param ) || !IsHashRefWithData( $Param{Data} ) ) {

        # nothing to do
        return;
    }

    my $Filter = $Param{Filter} || $Self->{Filter};

    OBJECT:
    foreach my $FilterObject ( keys %{$Filter} ) {
        my $Object = $FilterObject;
        if ( $Object eq '*' ) {
            # wildcard
            $Object = (sort keys %{$Param{Data}})[0];
        }
        my $ObjectData = $Param{Data}->{$Object};

        if ( $Param{IsPermissionFilter} && IsHashRefWithData( $ObjectData ) ) {

            # if we do permission filtering and the relevant object is a hashref then its a request to an item resource
            # we have to prepare something so the filter can handle it
            $ObjectData = [ $ObjectData ];
        }
        if ( IsArrayRefWithData($ObjectData) ) {
            # ignore lists of scalars
            if ( !IsHashRefWithData($ObjectData->[0]) ) {
                $Self->_Debug($Self->{LevelIndent}, "$Object is a list of scalars, not going to filter");
                next OBJECT;
            }

            $Self->_Debug($Self->{LevelIndent}, sprintf("filtering %i objects of type %s", scalar @{$ObjectData}, $Object));

            if ( $Param{IsPermissionFilter} ) {
                $Self->_PermissionDebug($Self->{LevelIndent}, "using permission filter: " . Dumper( $Param{Filter} ) );
            }

            # filter each contained hash
            my @FilteredResult;

            OBJECTITEM:
            foreach my $ObjectItem ( @{$ObjectData} ) {
                if ( ref($ObjectItem) eq 'HASH' ) {
                    my $Match = 1;

                    BOOLOPERATOR:
                    foreach my $BoolOperator ( keys %{ $Filter->{$FilterObject} } ) {
                        my $BoolOperatorMatch = 1;

                        FILTER:
                        foreach my $FilterItem ( @{ $Filter->{$FilterObject}->{$BoolOperator} } ) {                           
                            my $FilterMatch = 1;

                            if ( !$FilterItem->{AlwaysTrue} ) {
                                # if filter attributes are not contained in the response, check if it references a sub-structure
                                if ( !exists( $ObjectItem->{ $FilterItem->{Field} } ) ) {

                                    if ( $FilterItem->{Field} =~ /\./ ) {

                                        # yes it does, filter sub-structure
                                        my ( $SubObject, $SubField ) = split( /\./, $FilterItem->{Field}, 2 );
                                        my $SubData = {
                                            $SubObject => IsArrayRefWithData( $ObjectItem->{$SubObject} ) ? $ObjectItem->{$SubObject} : [ $ObjectItem->{$SubObject} ]
                                        };
                                        my %SubFilter = %{$FilterItem};
                                        $SubFilter{Field} = $SubField;

                                        # continue if the sub-structure attribute exists
                                        if ( exists( $ObjectItem->{$SubObject} ) ) {

                                            # execute filter on sub-structure
                                            $Self->_ApplyFilter(
                                                Data   => $SubData,
                                                Filter => {
                                                    $SubObject => {
                                                        OR => [
                                                            \%SubFilter
                                                            ]
                                                        }
                                                    }
                                            );

                                            # check filtered SubData
                                            if ( !IsArrayRefWithData( $SubData->{$SubObject} ) ) {

                                                # the filter didn't match the sub-structure
                                                $FilterMatch = 0;
                                            }
                                        }
                                        else {
                                            # the sub-structure attribute doesn't exist, ignore this item
                                            $FilterMatch = 0;
                                        }
                                    }
                                    else {
                                        # filtered attribute not found, ignore this item
                                        $FilterMatch = 0;
                                    }
                                }
                                else {
                                    my $FieldValue  = $ObjectItem->{ $FilterItem->{Field} } || '';
                                    my $FilterValue = $FilterItem->{Value};
                                    my $Type        = $FilterItem->{Type} || 'STRING';

                                    # check if the value references a field in our hash and take its value in this case
                                    if ( $FilterValue && $FilterValue =~ /^\$(.*?)$/ ) {
                                        $FilterValue = exists( $ObjectItem->{$1} ) ? $ObjectItem->{$1} : undef;
                                    }
                                    elsif ($FilterValue) {

                                        # replace wildcards with valid RegEx in FilterValue
                                        $FilterValue =~ s/\*/.*?/g;
                                    }
                                    else {
                                        $FilterValue = undef;
                                    }

                                    my @FieldValues = ($FieldValue);
                                    if ( IsArrayRefWithData($FieldValue) ) {
                                        @FieldValues = @{$FieldValue}
                                    }

                                    # handle multiple FieldValues (array)
                                    FIELDVALUE:
                                    foreach my $FieldValue (@FieldValues) {
                                        $FilterMatch = 1;

                                        # prepare date compare
                                        if ( $Type eq 'DATE' ) {

                                            # convert values to unixtime
                                            my ( $DatePart, $TimePart ) = split( /\s+/, $FieldValue );
                                            $FieldValue = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                                                String => $DatePart . ' 12:00:00',
                                            );
                                            my ( $FilterDatePart, $FilterTimePart ) = split( /\s+/, $FilterValue );
                                            $FilterValue = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                                                String => $FilterDatePart . ' 12:00:00',
                                            );

                                            # handle this as a numeric compare
                                            $Type = 'NUMERIC';
                                        }

                                        # prepare datetime compare
                                        elsif ( $Type eq 'DATETIME' ) {

                                            # convert values to unixtime
                                            $FieldValue = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                                                String => $FieldValue,
                                            );
                                            $FilterValue = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                                                String => $FilterValue,
                                            );

                                            # handle this as a numeric compare
                                            $Type = 'NUMERIC';
                                        }

                                        # equal (=)
                                        if ( $FilterItem->{Operator} eq 'EQ' ) {
                                            if ( !$FilterValue && $FieldValue ) {
                                                $FilterMatch = 0
                                            }
                                            elsif ( $Type eq 'STRING' && ( $FieldValue || '' ) ne ( $FilterValue || '' ) ) {
                                                $FilterMatch = 0;
                                            }
                                            elsif ( $Type eq 'NUMERIC' && ( $FieldValue || '' ) != ( $FilterValue || '' ) ) {
                                                $FilterMatch = 0;
                                            }
                                        }

                                        # not equal (!=)
                                        elsif ( $FilterItem->{Operator} eq 'NE' ) {
                                            if ( !$FilterValue && !$FieldValue ) {
                                                $FilterMatch = 0
                                            }
                                            elsif ( $Type eq 'STRING' && ( $FieldValue || '' ) eq ( $FilterValue || '' ) ) {
                                                $FilterMatch = 0;
                                            }
                                            elsif ( $Type eq 'NUMERIC' && ( $FieldValue || '' ) == ( $FilterValue || '' ) ) {
                                                $FilterMatch = 0;
                                            }
                                        }

                                        # less than (<)
                                        elsif ( $FilterItem->{Operator} eq 'LT' ) {
                                            if ( $Type eq 'NUMERIC' && $FieldValue >= $FilterValue ) {
                                                $FilterMatch = 0;
                                            }
                                        }

                                        # greater than (>)
                                        elsif ( $FilterItem->{Operator} eq 'GT' ) {
                                            if ( $Type eq 'NUMERIC' && $FieldValue <= $FilterValue ) {
                                                $FilterMatch = 0;
                                            }
                                        }

                                        # less than or equal (<=)
                                        elsif ( $FilterItem->{Operator} eq 'LTE' ) {
                                            if ( $Type eq 'NUMERIC' && $FieldValue > $FilterValue ) {
                                                $FilterMatch = 0;
                                            }
                                        }

                                        # greater than or equal (>=)
                                        elsif ( $FilterItem->{Operator} eq 'GTE' ) {
                                            if ( $Type eq 'NUMERIC' && $FieldValue < $FilterValue ) {
                                                $FilterMatch = 0;
                                            }
                                        }

                                        # value is contained in an array or values
                                        elsif ( $FilterItem->{Operator} eq 'IN' ) {
                                            $FilterMatch = 0;
                                            foreach $FilterValue ( @{$FilterValue} ) {
                                                if ( $Type eq 'NUMERIC' ) {
                                                    next if $FilterValue != $FieldValue + 0;
                                                }
                                                next if $FilterValue ne $FieldValue;
                                                $FilterMatch = 1;
                                            }
                                        }

                                        # the string contains a part
                                        elsif ( $FilterItem->{Operator} eq 'CONTAINS' ) {
                                            my $FilterValueQuoted = quotemeta $FilterValue;
                                            if ( $Type eq 'STRING' && $FieldValue !~ /$FilterValueQuoted/i ) {
                                                $FilterMatch = 0;
                                            }
                                        }

                                        # the string starts with the part
                                        elsif ( $FilterItem->{Operator} eq 'STARTSWITH' ) {
                                            my $FilterValueQuoted = quotemeta $FilterValue;
                                            if ( $Type eq 'STRING' && $FieldValue !~ /^$FilterValueQuoted/i ) {
                                                $FilterMatch = 0;
                                            }
                                        }

                                        # the string ends with the part
                                        elsif ( $FilterItem->{Operator} eq 'ENDSWITH' ) {
                                            my $FilterValueQuoted = quotemeta $FilterValue;
                                            if ( $Type eq 'STRING' && $FieldValue !~ /$FilterValueQuoted$/i ) {
                                                $FilterMatch = 0;
                                            }
                                        }

                                        # the string matches the pattern
                                        elsif ( $FilterItem->{Operator} eq 'LIKE' ) {
                                            if ( $Type eq 'STRING' && $FieldValue !~ /^$FilterValue$/im ) {
                                                $FilterMatch = 0;
                                            }
                                        }

                                        last FIELDVALUE if $FilterMatch;
                                    }
                                }
                            }

                            if ( $FilterItem->{Not} ) {

                                # negate match result
                                $FilterMatch = !$FilterMatch;
                            }

                            # abort filters for this bool operator, if we have a non-match
                            if ( $BoolOperator eq 'AND' && !$FilterMatch ) {

                                # signal the operator that it didn't match
                                $BoolOperatorMatch = 0;
                                last FILTER;
                            }
                            elsif ( $BoolOperator eq 'OR' && $FilterMatch ) {

                                # we don't need to check more filters in this case
                                $BoolOperatorMatch = 1;
                                last FILTER;
                            }
                            elsif ( $BoolOperator eq 'OR' && !$FilterMatch ) {
                                $BoolOperatorMatch = 0;
                            }
                        }

                        # abort filters for this object, if we have a non-match in the operator filters
                        if ( !$BoolOperatorMatch ) {
                            $Match = 0;
                            last BOOLOPERATOR;
                        }
                    }

                    # all filter criteria match, add to result
                    if ($Match) {
                        push @FilteredResult, $ObjectItem;
                    }
                }
            }
            if ( $Param{IsPermissionFilter} && IsHashRefWithData( $Param{Data}->{$Object} ) ) {

                # if we are in the permission filter mode and have prepared something in the beginning, check if we have an item in the filtered result
                # if not, the item cannot be read
                $Param{Data}->{$Object} = $FilteredResult[0];
                $Self->_Debug($Self->{LevelIndent}, sprintf("filtered result contains %i objects", scalar @FilteredResult));
            }
            else {
                $Param{Data}->{$Object} = \@FilteredResult;
            }
            if ( ref $Param{Data}->{$Object} eq 'ARRAY' ) {
                $Self->_Debug($Self->{LevelIndent}, sprintf("filtered result contains %i objects", scalar @{$Param{Data}->{$Object}}));
            }
        }
    }

    return 1;
}

sub _ApplyFieldSelector {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData( \%Param ) || !IsHashRefWithData( $Param{Data} ) || !IsHashRefWithData($Param{Fields})) {

        # nothing to do
        return;
    }

    foreach my $Object ( keys %{ $Param{Fields} } ) {
        if ( $Object eq '*') {
            # wildcard
            $Object = (sort keys %{$Param{Data}})[0];
        }

        my %Tmp = map { $_ => 1 } (
            @{ $Param{Fields}->{'*'} || [] },
            @{ $Param{Fields}->{$Object} || [] },
            keys %{ $Self->{Include} } ,
        );
        my @Fields = sort keys %Tmp;

        if ( ref( $Param{Data}->{$Object} ) eq 'HASH' ) {

            # extract filtered fields from hash
            my %NewObject;
            my @FieldsToRemove;
            foreach my $Field ( @Fields ) {
                my $Not = 0;
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
                        $NewObject{$Field} = $Param{Data}->{$Object}->{$Field};
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

            $Param{Data}->{$Object} = \%NewObject;
        }
        elsif ( ref( $Param{Data}->{$Object} ) eq 'ARRAY' ) {

            # filter keys in each contained hash
            foreach my $ObjectItem ( @{ $Param{Data}->{$Object} } ) {
                if ( ref($ObjectItem) eq 'HASH' ) {
                    # extract filtered fields from hash
                    my %NewObjectItem;
                    my @FieldsToRemove;
                    foreach my $Field ( @Fields ) {
                        my $Not = 0;
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
                                $NewObjectItem{$Field} = $ObjectItem->{$Field};
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
                next if exists( $Self->{Offset}->{$DataObject} );

                if ( ref( $Param{Data}->{$DataObject} ) eq 'ARRAY' ) {
                    my @ResultArray = splice @{ $Param{Data}->{$DataObject} }, $Self->{Offset}->{$Object};
                    $Param{Data}->{$DataObject} = \@ResultArray;
                }
            }
        }
        elsif ( ref( $Param{Data}->{$Object} ) eq 'ARRAY' ) {
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
                next if exists( $Self->{Limit}->{$DataObject} );

                if ( ref( $Param{Data}->{$DataObject} ) eq 'ARRAY' ) {
                    my @LimitedArray = splice @{ $Param{Data}->{$DataObject} }, 0, $Self->{Limit}->{$Object};
                    $Param{Data}->{$DataObject} = \@LimitedArray;
                }
            }
        }
        elsif ( ref( $Param{Data}->{$Object} ) eq 'ARRAY' ) {
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

    foreach my $Object ( keys %{ $Self->{Sort} } ) {
        if ( ref( $Param{Data}->{$Object} ) eq 'ARRAY' ) {

            $Self->_Debug($Self->{LevelIndent}, sprintf("sorting %i objects of type %s", scalar @{$Param{Data}->{$Object}}, $Object));

            # sort array by given criteria
            my @SortCriteria;
            my %SpecialSort;
            foreach my $Sort ( @{ $Self->{Sort}->{$Object} } ) {
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
                        $ObjectItem->{$SortField} = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                            String => $ObjectItem->{ $Sort->{Field} },
                        );
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

            my $IncludeOperation = $ReverseOperationRouteMapping{ "$Self->{OperationRouteMapping}->{$Self->{OperationType}}/" . lc($Include) };
            next if !$IncludeOperation;

            foreach my $Object ( keys %{ $Param{Data} } ) {
                next if !$Param{Data}->{$Object};

                if ( IsArrayRefWithData( $Param{Data}->{$Object} ) ) {
                    my $Index = 0;
                    foreach my $Item ( @{$Param{Data}->{$Object}} ) {

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
                        }
                    }
                }
                else {

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
                if ( IsArrayRefWithData( $Param{Data}->{$Object} ) ) {
                    @ItemList = @{ $Param{Data}->{$Object} };
                }
                else {
                    @ItemList = ( $Param{Data}->{$Object} );
                }

                foreach my $ItemData (@ItemList) {
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

    return 1;
}

sub _ClearPermissionFilters {
    my ( $Self, %Param ) = @_;

    $Self->{PermissionFilters} = [];

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

    my @Data;
    if ( IsArrayRefWithData( $Param{Data}->{ $Param{AttributeToExpand} } ) ) {
        @Data = @{ $Param{Data}->{ $Param{AttributeToExpand} } };
    }
    elsif ( IsHashRefWithData( $Param{Data}->{ $Param{AttributeToExpand} } ) ) {

        # hashref isn't possible
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Expanding a hash is not possible!",
        );
    }
    elsif ( IsStringWithData( $Param{Data}->{ $Param{AttributeToExpand} } ) ) {

        # convert scalar into our data array for further use
        @Data = ( $Param{Data}->{ $Param{AttributeToExpand} } );
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
        "$OperationConfig->{ObjectID}" => join( ',', sort @Data )
    );

    if ( $Param{ExpanderConfig}->{AddParams} ) {
        my @AddParams = split( /\s*,\s*/, $Param{ExpanderConfig}->{AddParams} );
        foreach my $AddParam (@AddParams) {
            my ( $TargetAttr, $SourceAttr ) = split( /=/, $AddParam );

            # if we don't have a special source attribute, target and source attribute are the same
            if ( !$SourceAttr ) {
                $SourceAttr = $TargetAttr;
            }
            $ExecData{$TargetAttr} = $Param{Data}->{$SourceAttr},
        }
    }

    my $Result = $Self->ExecOperation(
        OperationType => $Param{ExpanderConfig}->{Operation},
        Data          => \%ExecData,
    );
    if ( !IsHashRefWithData($Result) || !$Result->{Success} ) {
        return $Result;
    }

    # extract the relevant data from result
    my $ResultData = $Result->{Data}->{ ( ( keys %{ $Result->{Data} } )[0] ) };

    if ( ref( $Param{Data}->{ $Param{AttributeToExpand} } ) eq 'ARRAY' ) {
        if ( IsArrayRefWithData($ResultData) ) {
            $Param{Data}->{ $Param{AttributeToExpand} } = $ResultData;
        }
        else {
            $Param{Data}->{ $Param{AttributeToExpand} } = [$ResultData];
        }
    }
    else {
        $Param{Data}->{ $Param{AttributeToExpand} } = $ResultData;
    }

    return $Self->_Success();
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

    # generate key without offset
    my %RequestData = %{ $Self->{RequestData} };
    delete $RequestData{offset};

    my @CacheKeyParts = qw(limit include expand);
    if ( IsArrayRefWithData( $Self->{CacheKeyExtensions} ) ) {
        @CacheKeyParts = (
            @CacheKeyParts,
            @{ $Self->{CacheKeyExtensions} }
            )
    }

    # sort some things to make sure you always get the same cache key independent of the given order
    foreach my $What (@CacheKeyParts) {
        next if !$What || !$RequestData{$What};

        my @Parts = split( /,/, $RequestData{$What} );
        $RequestData{$What} = join( ',', sort @Parts );
    }

    # add UserID to CacheKey if not explicitly disabled
    my $UserID = '';
    if ( !$Self->{OperationConfig}->{DisableUserBasedCaching} ) {
        $UserID = $Self->{Authorization}->{UserID};
    }

    my $CacheKey = $UserID . '::' . $Self->{WebserviceID} . '::' . $Self->{OperationType} . '::' . $Kernel::OM->Get('Main')->Dump(
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

=item _CheckObjectPermission()

check object permissions

    my $Return = $CommonObject->_CheckObjectPermission(
        Data => {}          # optional
    );

    $Return = _Success if granted

=cut
sub _CheckObjectPermission {
    my ( $Self, %Param ) = @_;

    # get the relevant permission for the current request method
    my $PermissionName = Kernel::API::Operation->REQUEST_METHOD_PERMISSION_MAPPING->{ $Self->{RequestMethod} };

    # get list of permission types
    my %PermissionTypeList = $Kernel::OM->Get('Role')->PermissionTypeList();

    # get all Object and Property permissions for this user
    my %Permissions = $Kernel::OM->Get('User')->PermissionList(
        UserID       => $Self->{Authorization}->{UserID},
        UsageContext => $Self->{Authorization}->{UserType},
        Types        => [ 'Object' ],
        Valid        => 1
    );

    # get all relevant permissions
    my @RelevantPermissions;
    foreach my $Permission ( sort { length($b) <=> length($a) } values %Permissions ) {

        # prepare target
        my $Target = $Permission->{Target};
        $Target =~ s/\*/[^\/]+/g;
        $Target =~ s/\//\\\//g;
        $Target =~ s/\{.*?\}$//g;

        # only match the current RequestURI
        next if $Self->{RequestURI} !~ /^$Target$/;

        push @RelevantPermissions, $Permission;
    }

    # do something if we have at least one permission
    if ( IsArrayRefWithData(\@RelevantPermissions) ) {

        my $StartTime = Time::HiRes::time();

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

                my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
                $Self->_Debug($Self->{LevelIndent}, sprintf("permission check (Object) for $Self->{RequestURI} took %i ms", $TimeDiff));

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

            # check for "Wildcard" target (empty restriction)
            my $WildcardTarget = 1 if $1 =~ /^\s*$/;

            # every permission will be a part of a logical OR
            my $UseAnd = 0;

            # check for && and split accordingly
            my @Parts = $1 || '';
            if ( $Parts[0] =~ /&&/ ) {
                @Parts = split(/\s+&&\s+/, $Parts[0]);

                # the single parts of the permission are a part of a logical AND
                $UseAnd = 1;
            }

            my $Not = 0;
            my %Filter;
            foreach my $Part ( @Parts ) {
                if ( $Part eq $Parts[0] ) {
                    # only print this information once
                    $Self->_PermissionDebug($Self->{LevelIndent}, sprintf( "found relevant permission (Object) on target \"%s\" with value 0x%04x", $Permission->{Target}, $Permission->{Value} ) );
                }

                my ( $Object, $Attribute, $Operator, $Value );

                if ( !$WildcardTarget ) {
                    next if $Part !~ /^(\w+)\.(\w+)\s+(\w+)\s+(.*?)$/;

                    ( $Object, $Attribute, $Operator, $Value ) = ( $1, $2, $3, $4 );
                    if ( $Operator =~ /^!(.*?)$/ ) {
                        $Not      = 1;
                        $Operator = $1;
                    }

                    # replace string quotes
                    $Value =~ s/["']//g;

                    # prepare value for IN operator
                    if ( $Operator eq 'IN' ) {
                        if ( $Value =~ /^\[(.*?)\]$/ ) {
                            my @ValueParts = map { $_ = $Self->_ReplaceVariablesInPermission(Data => $_) } split(/\s*,\s*/, $1);
                            $Value = \@ValueParts;
                        }
                        else {
                            $Self->_PermissionDebug($Self->{LevelIndent}, sprintf("Value part of Object permission on target \"%s\" is invalid!", $Permission->{Target}) );
                            $Self->_Error(
                                Code    => 'InternalError',
                                Message => 'Permission value is invalid!',
                            );
                        }
                    }
                    else {
                        $Value = $Self->_ReplaceVariablesInPermission(
                            Data => $Value
                        );
                    }
                }
                else {
                    $Object = '*';
                }

                # add a NOT filter if we should have no permission (including DENY)
                if ( ( $Permission->{Value} & Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) != Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) {
                    $Not = 1;
                }
                elsif ( ( $Permission->{Value} & Kernel::System::Role::Permission::PERMISSION->{DENY} ) == Kernel::System::Role::Permission::PERMISSION->{DENY} ) {
                    $Not = 1;
                    # also clear all existing permission filters
                    $Self->_ClearPermissionFilters();
                }

                # add a filter accordingly
                my %Result = $Self->_AddPermissionFilterForObject(
                    Filter     => \%Filter,
                    Object     => $Object,
                    Field      => $Attribute,
                    Operator   => $Operator,
                    Value      => $Value,
                    Not        => $Not,
                    UseAnd     => $UseAnd,
                    AlwaysTrue => $WildcardTarget,
                );
                if ( !%Result ) {

                    return $Self->_Error(
                        Code    => 'InternalError',
                        Message => 'Unable to add permission filter!',
                    );
                }

                # save info that this object is permission filtered for later use
                $Self->{PermissionFilteredObjects}->{$Object} = 1;
            }

            if ( $Self->{RequestMethod} ne 'GET' ) {
                my %ObjectDataToFilter = %{$ObjectData};        # a deref is required here, because the filter method will change the data

                # we use the permission filters in order to apply them to the given object
                my $Result = $Self->_ApplyFilter(
                    Data               => \%ObjectDataToFilter,
                    Filter             => \%Filter,
                    IsPermissionFilter => 1,
                );

                # if the filtered object is undef then the filter doesn't match and we have to determine what to do depending on the desired permission
                foreach my $FilteredObject ( sort keys %{$Self->{PermissionFilteredObjects}} ) {
                    if ( (!$Not && defined $ObjectDataToFilter{$FilteredObject}) || ($Not && !defined $ObjectDataToFilter{$FilteredObject}) ) {
                        # init Result
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
                }

                if ( $ResultingPermission != -1 ) {
                    # check if we have the desired permission
                    my $PermissionCheck = ( $ResultingPermission & Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) == Kernel::System::Role::Permission::PERMISSION->{$PermissionName};

                    if ( !$PermissionCheck || ( $ResultingPermission & Kernel::System::Role::Permission::PERMISSION->{DENY} ) == Kernel::System::Role::Permission::PERMISSION->{DENY} ) {
                        $Self->_PermissionDebug($Self->{LevelIndent},  sprintf("object doesn't match the required criteria - denying request") );

                        my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
                        $Self->_Debug($Self->{LevelIndent}, sprintf("permission check (Object) for $Self->{RequestURI} took %i ms", $TimeDiff));

                        # return 403, because we don't have permission to execute this
                        return $Self->_Error(
                            Code => 'Forbidden',
                        );
                    }
                }
            }
            elsif ( ( $Permission->{Value} & Kernel::System::Role::Permission::PERMISSION->{DENY} ) == Kernel::System::Role::Permission::PERMISSION->{DENY} ) {
                # if we have a GET request and a DENY permission we can stop here and just use the DENY filter
                last PERMISSION;
            }
        }

        my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
        $Self->_Debug($Self->{LevelIndent}, sprintf("permission check (Object) for $Self->{RequestURI} took %i ms", $TimeDiff));
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

        # prepare target
        my $Target = $Permission->{Target};
        $Target =~ s/\*/[^\/]+/g;
        $Target =~ s/\//\\\//g;
        $Target =~ s/\{.*?\}$//g;

        # only match the current RequestURI
        next if $Self->{RequestURI} !~ /^$Target$/;

        push @RelevantPermissions, $Permission;
    }

    # do something if we have at least one permission
    if ( IsArrayRefWithData(\@RelevantPermissions) ) {

        my $StartTime = Time::HiRes::time();

        # inspect the object data
        my $ObjectData = {};
        if ( $Self->{RequestMethod} =~ /^POST|PATCH$/ ) {
            # we have to use the object given in the request data
            $ObjectData = $Param{Data};
        }

        my $ResultingPermission = -1;

        # check each permission and merge them for each attribute
        my %AttributePermissions;
        PERMISSION:
        foreach my $Permission ( @RelevantPermissions ) {

            # check for "Wildcard" target (empty restriction)
            my $WildcardTarget = 1 if $Permission->{Target} =~ /^.*?\{\}$/;

            my ( $Object, $Attributes, @AttributeList);

            if ( !$WildcardTarget ) {
                # extract property value permission
                next if $Permission->{Target} !~ /^.*?\{(\w+)\.\[(.*?)\]\}$/;

                ( $Object, $Attributes) = ( $1, $2 );
                @AttributeList = split(/\s*,\s*/, $Attributes);
            }
            else {
                $Object = '*';
                @AttributeList = ( '*' ); 
            }

            $Self->_PermissionDebug($Self->{LevelIndent},  sprintf( "found relevant permission (Property) on target \"%s\" with value 0x%04x", $Permission->{Target}, $Permission->{Value} ) );

            foreach my $Attribute (sort @AttributeList) {
                # init
                $AttributePermissions{"$Object.$Attribute"} = 0 if !exists $AttributePermissions{"$Object.$Attribute"};
                $AttributePermissions{"$Object.$Attribute"} |= $Permission->{Value};
            }
        }

        # if there is a wildcard permission we need to applay it to all non wildcard permissions
        foreach my $Attribute ( sort keys %AttributePermissions ) {
            next if $Attribute eq '*.*';
            $AttributePermissions{$Attribute} |= $AttributePermissions{'*.*'} || 0;
        }

        my %SeenAttributes;
        foreach my $Attribute ( sort keys %AttributePermissions ) {

            my $ResultingPermissionShort = $Kernel::OM->Get('Role')->GetReadablePermissionValue(
                Value  => $AttributePermissions{$Attribute},
                Format => 'Short'
            );

            $Self->_PermissionDebug($Self->{LevelIndent}, "resulting configured Property permission for property \"$Attribute\": $ResultingPermissionShort");

            if ( $Self->{RequestMethod} eq 'GET' ) {
                # add attribute to field selector
                my ($Object, $AttributeName) = split(/\./, $Attribute, 2);

                # init field selector
                $Self->{PermissionFieldSelector}->{$Object} = [ $Self->{OperationConfig}->{ObjectID} || 'ID' ] if !exists $Self->{PermissionFieldSelector}->{$Object};

                my $Ignore = '';
                if ( ( $AttributePermissions{$Attribute} & Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) != Kernel::System::Role::Permission::PERMISSION->{$PermissionName}
                    || ( $AttributePermissions{$Attribute} & Kernel::System::Role::Permission::PERMISSION->{DENY} ) == Kernel::System::Role::Permission::PERMISSION->{DENY}
                ) {
                    # access is denied, so we have to add an ignore selector for this attribute
                    $Ignore = '!'
                }
                push @{$Self->{PermissionFieldSelector}->{$Object}}, "$Ignore$AttributeName";
            }
            else {
                # we need a flat data structure to easily find the attributes
                my $FlatData = Hash::Flatten::flatten(
                    $Param{Data},
                    {
                        HashDelimiter  => '.',
                        ArrayDelimiter => ':'
                    }
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

                    my $IsPermissionMatch = ( $AttributePermissions{$Attribute} & Kernel::System::Role::Permission::PERMISSION->{$PermissionName} ) == Kernel::System::Role::Permission::PERMISSION->{$PermissionName} || 0;
                    my $IsDeny            = ( $AttributePermissions{$Attribute} & Kernel::System::Role::Permission::PERMISSION->{DENY} )            == Kernel::System::Role::Permission::PERMISSION->{DENY} || 0;

                    $Self->_PermissionDebug($Self->{LevelIndent}.'    ', "found property \"$MatchingAttribute\" (Not: $Not, $PermissionName permission: $IsPermissionMatch, DENY: $IsDeny)");

                    if ( !$Not && !$IsPermissionMatch || $Not && $IsPermissionMatch || $IsDeny ) {
                        $Self->_PermissionDebug($Self->{LevelIndent}, "request data doesn't match the required criteria - denying request" );

                        my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
                        $Self->_Debug($Self->{LevelIndent}, sprintf("permission check (Property) for $Self->{RequestURI} took %i ms", $TimeDiff));

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

        my $TimeDiff = (Time::HiRes::time() - $StartTime) * 1000;
        $Self->_Debug($Self->{LevelIndent}, sprintf("permission check (Property) for $Self->{RequestURI} took %i ms", $TimeDiff));
    }

    return $Self->_Success();
}

=item _AddPermissionFilterForObject()

adds a permission filter

    my $Return = $CommonObject->_AddPermissionFilterForObject(
        Filter     => {},            # optional, if given the method adds the new filter the the existing one
        Object     => 'Ticket',
        Field      => 'QueueID',
        Operator   => 'EQ',
        Value      => 12,
        Not        => 0|1,
        UseAnd     => 0|1,
        AlwaysTrue => 1              # optional, used for Wildcards
    );

    $Return = %Filter

=cut

sub _AddPermissionFilterForObject {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{AlwaysTrue} ) {
        for my $Needed (qw(Object Field Operator Value)) {
            if ( !defined $Param{$Needed} ) {

                # use Forbidden here to prevent access to data
                return;
            }
        }
        use Data::Dumper;
        $Self->_PermissionDebug($Self->{LevelIndent}, "adding permission filter: " . Dumper( \%Param ) );
    }
    else {
        $Self->_PermissionDebug($Self->{LevelIndent}, "adding ALWAYS TRUE filter" );
    }

    my $Logical = $Param{UseAnd} ? 'AND' : 'OR';

    # init PermissionFilters if not done already
    $Self->{PermissionFilters} ||= [];

    # store the required filter information for use in PrepareData
    push( @{ $Self->{PermissionFilters} }, {%Param} );

    my %Filter;
    $Filter{ $Param{Object} }->{$Logical} = [];
    push( @{ $Filter{ $Param{Object} }->{$Logical} }, { %Param } );

    if ( IsHashRef($Param{Filter}) ) {
        $Param{Filter}->{ $Param{Object} }->{$Logical} = [] if !IsArrayRef($Param{Filter}->{ $Param{Object} }->{$Logical});
        push( @{ $Param{Filter}->{ $Param{Object} }->{$Logical} }, { %Param } );
    }

    return %Filter;
}

sub _GetPermissionFilter {
    my ( $Self, %Param ) = @_;

    $Self->{PermissionFilters} ||= [];

    my %PermissionFilter;

    foreach my $Filter ( @{ $Self->{PermissionFilters} } ) {

        # prepare filter definition
        my %FilterDef = (
            Field      => $Filter->{Field},
            Operator   => $Filter->{Operator},
            Value      => $Filter->{Value},
            Not        => $Filter->{Not},
            AlwaysTrue => $Filter->{AlwaysTrue}
        );

        my $Logical = $Filter->{UseAnd} ? 'AND' : 'OR';

        # init filter and search if not done already
        $PermissionFilter{ $Filter->{Object} }->{$Logical} ||= [];

        # add definition to filters
        push( @{ $PermissionFilter{ $Filter->{Object} }->{$Logical} }, \%FilterDef );
    }

    return \%PermissionFilter;
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
        }

        # get the relevant attribute
        my $FlatData = Hash::Flatten::flatten(
            \%User,
            {
                HashDelimiter  => '.',
                ArrayDelimiter => ':'
            }
        );

        $Result = $FlatData->{$Attribute};

    }

    return $Result;
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

    my $NumWorkers = $Kernel::OM->Get('Config')->Get('API::Parallelity') || 4;

    my $WorkQueue : shared;
    $WorkQueue = Thread::Queue->new();
    my $ResultQueue : shared;
    $ResultQueue = Thread::Queue->new();

    $Self->_Debug("executing with parallel algorithm ($NumWorkers workers)");

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

                $Kernel::OM->Get('DB')->Disconnect();
                $DBD::Pg::VERSION = $DBDPg_VERSION;

                while ( (my $Item = $Param{WorkQueue}->dequeue) ne "END_OF_QUEUE" ) {
                    my $Result = $Sub->($Self, Item => $Item, %Param);

                    $ResultQueue->enqueue(Storable::freeze {
                        Item   => $Item,
                        Result => $Result, 
                    });
                }
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

    my $NumWorkers = $Kernel::OM->Get('Config')->Get('API::Parallelity') || 4;
    my $MinChecksPerWorker = $Kernel::OM->Get('Config')->Get('API::MinTasksPerWorker') || 10;

    return 1 if ( scalar(@{$Param{Items}}) >= $NumWorkers * $MinChecksPerWorker );
    return 0;
}

sub _Debug {
    my ( $Self, $Indent, $Message ) = @_;

    return if ( !$Kernel::OM->Get('Config')->Get('API::Debug') );

    $Indent ||= '';

    printf STDERR "(%5i) %-15s %s%s: %s\n", $$, "[API]", $Indent, $Self->{OperationConfig}->{Name}, "$Message";
}

sub _PermissionDebug {
    my ( $Self, $Indent, $Message ) = @_;

    return if ( !$Kernel::OM->Get('Config')->Get('Permission::Debug') );

    $Indent ||= '';

    printf STDERR "(%5i) %-15s %s%s\n", $$, "[Permission]", $Indent, $Message;
}


=item _FilterCustomerUserVisibleConfigItems()

filters config items ids for current customer user if necessary

    @ConfigItemIDList = $ConfigItemObject->_FilterCustomerUserVisibleConfigItems(
        ConfigItemIDList => \@ConfigItemList
    )

=cut

sub _FilterCustomerUserVisibleConfigItems {
    my ( $Self, %Param ) = @_;

    my @ConfigItemIDList = IsArrayRefWithData($Param{ConfigItemIDList}) ? @{$Param{ConfigItemIDList}} : ();

    if (
        IsArrayRefWithData(\@ConfigItemIDList) &&
        IsHashRefWithData($Self->{Authorization}) &&
        $Self->{Authorization}->{UserType} eq 'Customer'
    ) {
        my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
            UserID => $Self->{Authorization}->{UserID},
        );
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

        my $ItemIDs;
        if ( IsHashRefWithData(\%ContactData) ) {
            $ItemIDs = $Kernel::OM->Get('ITSMConfigItem')->GetAssignedConfigItemsForObject(
                ObjectType => 'Contact',
                Object     => \%ContactData
            );
        }

        if ( IsArrayRefWithData($ItemIDs) ) {
            my %ItemIDsHash = map { $_ => 1 } @{$ItemIDs};
            my @Result;
            foreach my $ConfigItemID ( @ConfigItemIDList ) {
                push(@Result, 0 + $ConfigItemID) if $ItemIDsHash{$ConfigItemID};
            }
            @ConfigItemIDList = @Result;
        } else {
            @ConfigItemIDList = ();
        }
    }

    return @ConfigItemIDList;
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
