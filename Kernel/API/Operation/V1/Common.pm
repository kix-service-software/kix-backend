# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Common;

use strict;
use warnings;
use Hash::Flatten;
use Data::Sorting qw(:arrays);

use Kernel::API::Operation;
use Kernel::API::Validator;
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Common - Base class for all Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

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
    my $Webservice = $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceGet(
        ID => $Param{WebserviceID},
    );

    if ( !IsHashRefWithData($Webservice) ) {
        return $Self->_Error(
            Code    => 'Webservice.InternalError',
            Message =>
                'Could not determine Web service configuration'
                . ' in Kernel::API::Operation::V1::Common::Init()',
        );
    }

    return $Self->_Success();
}

=item PrepareData()

prepare data, check given parameters and parse them according to type

    my $Return = $CommonObject->PrepareData(
        Data   => {
            ...
        },
        Parameters => {
            <Parameter> => {                                            # if Parameter is a attribute of a hashref, just separate it by ::, i.e. "User::UserFirstname"
                Type                => 'ARRAY' | 'ARRAYtoHASH',         # optional, use this to parse a comma separated string into an array or a hash with all array entries as keys and 1 as values
                Required            => 1,                               # optional
                RequiredIfNot       => [ '<AltParameter>', ... ]        # optional, specify the alternate parameters to be checked, if one of them has a value
                RequiredIf          => [ '<Parameter>', ... ]           # optional, specify the parameters that should be checked for values
                RequiresValueIfUsed => 1                                # optional
                Default             => ...                              # optional
                OneOf               => [...]                            # optional
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

    # prepare field filter
    if ( exists($Param{Data}->{filter}) && IsStringWithData($Param{Data}->{filter}) ) {
        my $Result = $Self->_ValidateFilter(
            Filter => $Param{Data}->{filter},
        );
        if ( IsHashRefWithData($Result) ) {
            # error occured
            return $Result;
        }
    }

    # prepare field selector
    if ( (exists($Param{Data}->{fields}) && IsStringWithData($Param{Data}->{fields})) || IsStringWithData($Self->{OperationConfig}->{'FieldSet::Default'}) ) {
        my $FieldSet = $Param{Data}->{fields} || ':Default';
        if ($FieldSet =~ /^:(.*?)/ ) {
            # get pre-defined FieldSet
            $FieldSet = $Self->{OperationConfig}->{'FieldSet:'.$FieldSet};
        }
        foreach my $FieldSelector ( split(/,/, $FieldSet) ) {
            my ($Object, $Field) = split(/\./, $FieldSelector, 2);
            if ($Field =~ /^\[(.*?)\]$/g ) {
                my @Fields = split(/\s*;\s*/, $1);
                $Self->{Fields}->{$Object} = \@Fields;
            }
            else {
                if ( !IsArrayRefWithData($Self->{Fields}->{$Object}) ) {
                    $Self->{Fields}->{$Object} = [];
                }
                push @{$Self->{Fields}->{$Object}}, $Field;
            }
        }
    }
    
    # prepare limiter
    if ( exists($Param{Data}->{limit}) && IsStringWithData($Param{Data}->{limit}) ) {
        foreach my $Limiter ( split(/,/, $Param{Data}->{limit}) ) {
            my ($Object, $Limit) = split(/\:/, $Limiter, 2);
            if ( $Limit && $Limit =~ /\d+/ ) {
               $Self->{Limit}->{$Object} = $Limit;
            }
            else {
                $Self->{Limit}->{__COMMON} = $Object;
            }
        }
    }

    # prepare offset
    if ( exists($Param{Data}->{offset}) && IsStringWithData($Param{Data}->{offset}) ) {
        foreach my $Offset ( split(/,/, $Param{Data}->{offset}) ) {
            my ($Object, $Index) = split(/\:/, $Offset, 2);
            if ( $Index && $Index =~ /\d+/ ) {
               $Self->{Offset}->{$Object} = $Index;
            }
            else {
                $Self->{Offset}->{__COMMON} = $Object;
            }
        }
    }

    # prepare sorter
    if ( exists($Param{Data}->{sort}) && IsStringWithData($Param{Data}->{sort}) ) {
        foreach my $Sorter ( split(/,/, $Param{Data}->{sort}) ) {
            my ($Object, $FieldSort) = split(/\./, $Sorter, 2);
            my ($Field, $Type) = split(/\:/, $FieldSort);
            my $Direction = 'ascending';
            $Type = uc($Type || 'TEXTUAL');

            # check if sort type is valid
            if ( $Type && $Type !~ /(NUMERIC|TEXTUAL|NATURAL|DATE|DATETIME)/g ) {
                return $Self->_Error(
                    Code    => 'PrepareData.InvalidSort',
                    Message => "Unknown type $Type in $Sorter!",
                );                
            }
            
            # should we sort ascending or descending
            if ( $Field =~ /^-(.*?)$/g ) {
                $Field = $1;
                $Direction = 'descending';
            }
            
            if ( !IsArrayRefWithData($Self->{Sorter}->{$Object}) ) {
                $Self->{Sort}->{$Object} = [];
            }
            push @{$Self->{Sort}->{$Object}}, { 
                Field => $Field, 
                Direction => $Direction, 
                Type  => ($Type || 'cmp')
            };
        }
    }

    # prepare expander
    if ( exists($Param{Data}->{expand}) && IsStringWithData($Param{Data}->{expand}) ) {
        foreach my $Expander ( split(/,/, $Param{Data}->{expand}) ) {            
            my ($Object, $Attribute) = split(/\./, $Expander, 2);

            my @Attributes;
            if ($Attribute =~ /^\[(.*?)\]$/g ) {
               @Attributes = split(/\s*;\s*/, $1);
            }
            else {
               push(@Attributes, $Attribute);
            }

            foreach $Attribute ( @Attributes ) {
                # ignore this expander if it isn't possible in this operation
                next if ( !$Self->{OperationConfig}->{'Expandable::'.$Attribute} );

                my %ExpanderDef = (
                    Attribute => $Attribute,
                );
                foreach my $DefPart ( split(/,/, $Self->{OperationConfig}->{'Expandable::'.$Attribute})) {
                    my ($Key, $Value) = split(/=/, $DefPart, 2);
                    $ExpanderDef{$Key} = $Value;
                }

                if ( IsStringWithData($ExpanderDef{Add}) ) {
                    $ExpanderDef{Add} = [ split(/;/, $ExpanderDef{Add}) ];
                }

                if ( !IsArrayRefWithData($Self->{Expand}->{$Object}) ) {
                    $Self->{Expand}->{$Object} = [];
                }
                push @{$Self->{Expand}->{$Object}}, \%ExpanderDef;
            }
        }
    }

    my %Data = %{$Param{Data}};

    # store data for later use
    $Self->{RequestData} = \%Data;

    # if needed flatten hash structure for easier access to sub structures
    if ( ref($Param{Parameters}) eq 'HASH' ) {
        
        if ( grep(/::/, keys %{$Param{Parameters}}) ) {
            my $FlatData = Hash::Flatten::flatten(
                $Param{Data},
                {
                    HashDelimiter => '::',
                }
            );

            # add pseudo entries for substructures for requirement checking
            foreach my $Entry ( keys %{$FlatData} ) {
                next if $Entry !~ /^.*?::.*?::/g;

                my @Parts = split(/::/, $Entry);
                pop(@Parts);
                my $DummyKey = join('::', @Parts);

                next if exists($FlatData->{$DummyKey});
                $FlatData->{$DummyKey} = {};
            }

            %Data = (
                %Data,
                %{$FlatData},
            );
        }

        my %Parameters = %{$Param{Parameters}};

        # always add include parameter
        $Parameters{'include'} = {
            Type => 'ARRAYtoHASH',
        };

        foreach my $Parameter ( sort keys %Parameters ) {

            # check requirement
            if ( $Parameters{$Parameter}->{Required} && !exists($Data{$Parameter}) ) {
                $Result->{Success} = 0;
                $Result->{Message} = "Required parameter $Parameter is missing!",
                last;
            }
            elsif ( $Parameters{$Parameter}->{RequiredIfNot} && ref($Parameters{$Parameter}->{RequiredIfNot}) eq 'ARRAY' ) {
                my $AltParameterHasValue = 0;
                foreach my $AltParameter ( @{$Parameters{$Parameter}->{RequiredIfNot}} ) {
                    if ( exists($Data{$AltParameter}) && defined($Data{$AltParameter}) ) {
                        $AltParameterHasValue = 1;
                        last;
                    }
                }
                if ( !exists($Data{$Parameter}) && !$AltParameterHasValue ) {
                    $Result->{Success} = 0;
                    $Result->{Message} = "Required parameter $Parameter or ".( join(" or ", @{$Parameters{$Parameter}->{RequiredIfNot}}) )." is missing!",
                    last;
                }
            }

            # check complex requirement (required if another parameter has value)
            if ( $Parameters{$Parameter}->{RequiredIf} && ref($Parameters{$Parameter}->{RequiredIf}) eq 'ARRAY' ) {
                my $OtherParameterHasValue = 0;
                foreach my $OtherParameter ( @{$Parameters{$Parameter}->{RequiredIf}} ) {
                    if ( exists($Data{$OtherParameter}) && defined($Data{$OtherParameter}) ) {
                        $OtherParameterHasValue = 1;
                        last;
                    }
                }
                if ( !exists($Data{$Parameter}) && $OtherParameterHasValue ) {
                    $Result->{Success} = 0;
                    $Result->{Message} = "Required parameter $Parameter is missing!",
                    last;
                }
            }

            # parse into arrayref if parameter value is scalar and ARRAY type is needed
            if ( $Parameters{$Parameter}->{Type} && $Parameters{$Parameter}->{Type} =~ /(ARRAY|ARRAYtoHASH)/ && $Data{$Parameter} && ref($Data{$Parameter}) ne 'ARRAY' ) {
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                    Value     => [ split('\s*,\s*', $Data{$Parameter}) ],
                );
            }

            # convert array to hash if we have to 
            if ( $Parameters{$Parameter}->{Type} && $Parameters{$Parameter}->{Type} eq 'ARRAYtoHASH' && $Data{$Parameter} && ref($Param{Data}->{$Parameter}) eq 'ARRAY' ) {
                my %NewHash = map { $_ => 1 } @{$Param{Data}->{$Parameter}};
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                    Value     => \%NewHash,
                );
            }            

            # set default value
            if ( !$Data{$Parameter} && exists($Parameters{$Parameter}->{Default}) ) {
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                    Value     => $Parameters{$Parameter}->{Default},
                );
            }

            # check valid values
            if ( exists($Parameters{$Parameter}->{OneOf}) && ref($Parameters{$Parameter}->{OneOf}) eq 'ARRAY' ) {
                if ( !grep(/^$Data{$Parameter}$/g, @{$Parameters{$Parameter}->{OneOf}}) ) {
                    $Result->{Success} = 0;
                    $Result->{Message} = "Parameter $Parameter is not one of '".(join(',', @{$Parameters{$Parameter}->{OneOf}}))."'!",
                    last;
                }
            }

            # check if we have an optional parameter that needs a value
            if ( $Parameters{$Parameter}->{RequiresValueIfUsed} && exists($Data{$Parameter}) && !defined($Data{$Parameter}) ) {
                $Result->{Success} = 0;
                $Result->{Message} = "Optional parameter $Parameter is used without a value!",
                last;
            }
        }
    }

    # store include for later
    $Self->{Include} = $Param{Data}->{include};
    
    return $Result; 
}

=item _Success()

helper function to return a successful result.

    my $Return = $CommonObject->_Success(
        ...
    );

=cut

sub _Success {
    my ( $Self, %Param ) = @_;

    # honor a filter, if we have one
    if ( IsHashRefWithData($Self->{Filter}) ) {
        $Self->_ApplyFilter(
            Data => \%Param,
        );
    }

    # honor a sorter, if we have one
    if ( IsHashRefWithData($Self->{Sort}) ) {
        $Self->_ApplySort(
            Data => \%Param,
        );
    }
    
    # honor a field selector, if we have one
    if ( IsHashRefWithData($Self->{Fields}) ) {
        $Self->_ApplyFieldSelector(
            Data => \%Param,
        );
    }

    # honor an offset, if we have one
    if ( IsHashRefWithData($Self->{Offset}) ) {
        $Self->_ApplyOffset(
            Data => \%Param,
        );
    }

    # honor a limiter, if we have one
    if ( IsHashRefWithData($Self->{Limit}) ) {
        $Self->_ApplyLimit(
            Data => \%Param,
        );
    }

    # honor a generic include, if we have one
    if ( IsHashRefWithData($Self->{Include}) ) {
        $Self->_ApplyInclude(
            Data => \%Param,
        );
    }

    # honor an expander, if we have one
    if ( IsHashRefWithData($Self->{Expand}) ) {
        $Self->_ApplyExpand(
            Data => \%Param,
        );
    }

    # prepare result
    my $Code    = $Param{Code};
    my $Message = $Param{Message};
    delete $Param{Code};
    delete $Param{Message};

    # return structure
    return {
        Success      => 1,
        Code         => $Code,
        Message      => $Message,
        Data         => {
            %Param
        },
    };
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
        Data    => {
        },
    };
}

=item ExecOperation()

helper function to execute another operation to work with its result.

    my $Return = $CommonObject->ExecOperation(
        OperationType => '...'                              # required
        Data          => {

        }
    );

=cut

sub ExecOperation {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(OperationType Data)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'ExecOperation.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    # init new Operation object
    my $OperationObject = Kernel::API::Operation->new(
        DebuggerObject          => $Self->{DebuggerObject},
        Operation               => (split(/::/, $Param{OperationType}))[-1],
        OperationType           => $Param{OperationType},
        WebserviceID            => $Self->{WebserviceID},
        Authorization           => $Self->{Authorization},
    );

    # if operation init failed, bail out
    if ( ref $OperationObject ne 'Kernel::API::Operation' ) {
        return $Self->_Error(
            %{$OperationObject},
        );
    }

    return $OperationObject->Run(
        Data    => {
            %{$Param{Data}},
            include => $Self->{RequestData}->{include},
            expand  => $Self->{RequestData}->{expand},
        }
    );
}


# BEGIN INTERNAL

sub _ValidateFilter {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !$Param{Filter} ) {
        # nothing to do
        return;
    }    

    my %OperatorTypeMapping = (
        'EQ'         => { 'NUMERIC' => 1, 'STRING'  => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'NE'         => { 'NUMERIC' => 1, 'STRING'  => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'LT'         => { 'NUMERIC' => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'GT'         => { 'NUMERIC' => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'LTE'        => { 'NUMERIC' => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'GTE'        => { 'NUMERIC' => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'IN'         => { 'NUMERIC' => 1, 'STRING'  => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'CONTAINS'   => { 'STRING'  => 1 },
        'STARTSWITH' => { 'STRING'  => 1 },
        'ENDSWITH'   => { 'STRING'  => 1 },
        'LIKE'       => { 'STRING'  => 1 },
    );
    my $ValidOperators = join('|', keys %OperatorTypeMapping);
    my %ValidTypes;
    foreach my $Tmp ( values %OperatorTypeMapping ) {
        foreach my $Type ( keys %{$Tmp} ) { 
            $ValidTypes{$Type} = 1;
        } 
    }

    my $FilterDef = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
        Data => $Param{Filter}
    );

    foreach my $Object ( keys %{$FilterDef} ) {
        # do we have a object definition ?
        if ( !IsHashRefWithData($FilterDef->{$Object}) ) {
            return $Self->_Error(
                Code    => 'PrepareData.InvalidFilter',
                Message => "Invalid filter for object $Object!",
            );                
        }

        foreach my $BoolOperator ( keys %{$FilterDef->{$Object}} ) {
            if ( $BoolOperator !~ /^(AND|OR)$/g ) {
                return $Self->_Error(
                    Code    => 'PrepareData.InvalidFilter',
                    Message => "Invalid filter for object $Object!",
                );                
            }

            # do we have a valid boolean operator
            if ( !IsArrayRefWithData($FilterDef->{$Object}->{$BoolOperator}) ) {
                return $Self->_Error(
                    Code    => 'PrepareData.InvalidFilter',
                    Message => "Invalid filter for object $Object!, operator $BoolOperator",
                );                
            }

            # iterate filters
            foreach my $Filter ( @{$FilterDef->{$Object}->{$BoolOperator}} ) {
                $Filter->{Operator} = uc($Filter->{Operator} || '');
                $Filter->{Type} = uc($Filter->{Type} || 'STRING');

                # check if filter field is valid
                if ( !$Filter->{Field} ) {
                    return $Self->_Error(
                        Code    => 'PrepareData.InvalidFilter',
                        Message => "No field in $Object.$Filter->{Field}!",
                    );
                }
                # check if filter Operator is valid
                if ( $Filter->{Operator} !~ /^($ValidOperators)$/g ) {
                    return $Self->_Error(
                        Code    => 'PrepareData.InvalidFilter',
                        Message => "Unknown filter operator $Filter->{Operator} in $Object.$Filter->{Field}!",
                    );
                }
                # check if type is valid
                if ( !$ValidTypes{$Filter->{Type}} ) {
                    return $Self->_Error(
                        Code    => 'PrepareData.InvalidFilter',
                        Message => "Unknown type $Filter->{Type} in $Object.$Filter->{Field}!",
                    );                
                }
                # check if combination of filter Operator and type is valid
                if ( !$OperatorTypeMapping{$Filter->{Operator}}->{$Filter->{Type}} ) {
                    return $Self->_Error(
                        Code    => 'PrepareData.InvalidFilter',
                        Message => "Type $Filter->{Type} not valid for operator $Filter->{Operator} in $Object.$Filter->{Field}!",
                    );                                
                }

                # prepare value if it is a DATE type
                if ( $Filter->{Type} eq 'DATE' ) {
                    if ( $Filter->{Value} !~ /\d{4}-\d{2}-\d{2}/ && $Filter->{Value} !~ /\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}/ ) {
                        return $Self->_Error(
                            Code    => 'PrepareData.InvalidFilter',
                            Message => "Invalid date value $Filter->{Value} in $Object.$Filter->{Field}!",
                        );
                    }
                    my ($DatePart, $TimePart) = split(/T/, $Filter->{Value});

                    # convert Value to unixtime to later compares
                    $Filter->{Value} = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                        String => $DatePart.' 12:00:00',
                    );
                }

                if ( $Filter->{Type} eq 'DATETIME' ) {
                    if ( $Filter->{Value} !~ /\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}/ ) {
                        return $Self->_Error(
                            Code    => 'PrepareData.InvalidFilter',
                            Message => "Invalid datetime value $Filter->{Value} in $Object.$Filter->{Field}!",
                        );
                    }
                    my ($DatePart, $TimePart) = split(/T/, $Filter->{Value});
                    $TimePart =~ s/-/:/g;

                    # convert Value to unixtime to later compares
                    $Filter->{Value} = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                        String => $DatePart.' '.$TimePart,
                    );
                }
            }
        }

        # filter is ok
        $Self->{Filter} = $FilterDef;
    }

    return 1;
}

sub _ApplyFilter {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    OBJECT:
    foreach my $Object ( keys %{$Self->{Filter}} ) {
        if ( IsArrayRefWithData($Param{Data}->{$Object}) ) {
            # filter each contained hash
            my @FilteredResult;
            
            OBJECTITEM:
            foreach my $ObjectItem ( @{$Param{Data}->{$Object}} ) {                
                if ( ref($ObjectItem) eq 'HASH' ) {
                    my $Match = 1;

                    BOOLOPERATOR:
                    foreach my $BoolOperator ( keys %{$Self->{Filter}->{$Object}} ) {
                        my $BoolOperatorMatch = 1;

                        FILTER:
                        foreach my $Filter ( @{$Self->{Filter}->{$Object}->{$BoolOperator}} ) {
                            my $FilterMatch = 1;

                            my $FieldValue = $ObjectItem->{$Filter->{Field}};
                            my $FilterValue = $Filter->{Value};
                            my $Type = $Filter->{Type};

                            # check if the value references a field in our hash and take its value in this case
                            if ( $FilterValue =~ /^\$(.*?)$/ ) {
                                $FilterValue =  exists($ObjectItem->{$1}) ? $ObjectItem->{$1} : undef;
                            }

                            # replace wildcards with valid RegEx in FilterValue
                            $FilterValue =~ s/\*/.*?/g;

                            # prepare date compare
                            if ( $Type eq 'DATE' ) {
                                # convert values to unixtime
                                my ($DatePart, $TimePart) = split(/\s+/, $FieldValue);
                                $FieldValue = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                                    String => $DatePart.' 12:00:00',
                                );
                                # handle this as a numeric compare
                                $Type = 'NUMERIC';
                            }
                            # prepare datetime compare
                            elsif ( $Type eq 'DATETIME' ) {
                                # convert values to unixtime
                                $FieldValue = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                                    String => $FieldValue,
                                );
                                # handle this as a numeric compare
                                $Type = 'NUMERIC';
                            }

                            # equal (=)
                            if ( $Filter->{Operator} eq 'EQ' ) {
                                if ( $Type eq 'STRING' && $FieldValue ne $FilterValue ) {
                                    $FilterMatch = 0;
                                }
                                elsif ( $Type eq 'NUMERIC' && $FieldValue != $FilterValue ) {
                                    $FilterMatch = 0;
                                }                                
                            }
                            # not equal (!=)
                            elsif ( $Filter->{Operator} eq 'NE' ) {                        
                                if ( $Type eq 'STRING' && $FieldValue eq $FilterValue ) {
                                    $FilterMatch = 0;
                                }
                                elsif ( $Type eq 'NUMERIC' && $FieldValue == $FilterValue ) {
                                    $FilterMatch = 0;
                                }                                
                            }
                            # less than (<)
                            elsif ( $Filter->{Operator} eq 'LT' ) {                        
                                if ( $Type eq 'NUMERIC' && $FieldValue >= $FilterValue ) {
                                    $FilterMatch = 0;
                                }                                
                            }
                            # greater than (>)
                            elsif ( $Filter->{Operator} eq 'GT' ) {                        
                                if ( $Type eq 'NUMERIC' && $FieldValue <= $FilterValue ) {
                                    $FilterMatch = 0;
                                }                                
                            }
                            # less than or equal (<=)
                            elsif ( $Filter->{Operator} eq 'LTE' ) {                        
                                if ( $Type eq 'NUMERIC' && $FieldValue > $FilterValue ) {
                                    $FilterMatch = 0;
                                }                                
                            }
                            # greater than or equal (>=)
                            elsif ( $Filter->{Operator} eq 'GTE' ) {                        
                                if ( $Type eq 'NUMERIC' && $FieldValue < $FilterValue ) {
                                    $FilterMatch = 0;
                                }                                
                            }
                            # value is contained in an array or values
                            elsif ( $Filter->{Operator} eq 'IN' ) {
                                if ( !grep(/^$FieldValue$/g, @{$FilterValue}) ) {
                                    $FilterMatch = 0;
                                }
                            }
                            # the string contains a part
                            elsif ( $Filter->{Operator} eq 'CONTAINS' ) {                        
                                if ( $Type eq 'STRING' && $FieldValue !~ /$FilterValue/ ) {
                                    $FilterMatch = 0;
                                }
                            }
                            # the string starts with the part
                            elsif ( $Filter->{Operator} eq 'STARTSWITH' ) {                        
                                if ( $Type eq 'STRING' && $FieldValue !~ /^$FilterValue/ ) {
                                    $FilterMatch = 0;
                                }
                            }
                            # the string ends with the part
                            elsif ( $Filter->{Operator} eq 'ENDSWITH' ) {                        
                                if ( $Type eq 'STRING' && $FieldValue !~ /$FilterValue$/ ) {
                                    $FilterMatch = 0;
                                }
                            }
                            # the string matches the pattern
                            elsif ( $Filter->{Operator} eq 'LIKE' ) {                        
                                if ( $Type eq 'STRING' && $FieldValue !~ /^$FilterValue$/g ) {
                                    $FilterMatch = 0;
                                }
                            }                            

                            if ( $Filter->{Not} ) {
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
                    if ( $Match ) {
                        push @FilteredResult, $ObjectItem;
                    }
                }
            }
            $Param{Data}->{$Object} = \@FilteredResult;
        }
    } 

    return 1;
}

sub _ApplyFieldSelector {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Fields}} ) {
        if ( ref($Param{Data}->{$Object}) eq 'HASH' ) {
            # extract filtered fields from hash
            my %NewObject;
            foreach my $Field ( @{$Self->{Fields}->{$Object}} ) {
                if ( $Field eq '*' ) {
                    # include all fields
                    %NewObject = %{$Param{Data}->{$Object}};
                    last;
                }
                else {                    
                    $NewObject{$Field} = $Param{Data}->{$Object}->{$Field};
                }
            }
            $Param{Data}->{$Object} = \%NewObject;
        }
        elsif ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            # filter keys in each contained hash
            foreach my $ObjectItem ( @{$Param{Data}->{$Object}} ) {
                if ( ref($ObjectItem) eq 'HASH' ) {
                    my %NewObjectItem;
                    foreach my $Field ( @{$Self->{Fields}->{$Object}} ) {
                        if ( $Field eq '*' ) {
                            # include all fields
                            %NewObjectItem = %{$ObjectItem};
                            last;
                        }
                        else {                    
                            $NewObjectItem{$Field} = $ObjectItem->{$Field};
                        }
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

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Offset}} ) {
        if ( $Object eq '__COMMON' ) {
            foreach my $DataObject ( keys %{$Param{Data}} ) {
                # ignore the object if we have a specific start index for it
                next if exists($Self->{Offset}->{$DataObject});

                if ( ref($Param{Data}->{$DataObject}) eq 'ARRAY' ) {
                    my @ResultArray = splice @{$Param{Data}->{$DataObject}}, $Self->{Offset}->{$Object};
                    $Param{Data}->{$DataObject} = \@ResultArray;
                }
            }
        }
        elsif ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            my @ResultArray = splice @{$Param{Data}->{$Object}}, $Self->{Offset}->{$Object};
            $Param{$Object} = \@ResultArray;
        }
    } 
}

sub _ApplyLimit {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Limit}} ) {
        if ( $Object eq '__COMMON' ) {
            foreach my $DataObject ( keys %{$Param{Data}} ) {
                # ignore the object if we have a specific limiter for it
                next if exists($Self->{Limit}->{$DataObject});

                if ( ref($Param{Data}->{$DataObject}) eq 'ARRAY' ) {
                    my @LimitedArray = splice @{$Param{Data}->{$DataObject}}, 0, $Self->{Limit}->{$Object};
                    $Param{Data}->{$DataObject} = \@LimitedArray;
                }
            }
        }
        elsif ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            my @LimitedArray = splice @{$Param{Data}->{$Object}}, 0, $Self->{Limit}->{$Object};
            $Param{$Object} = \@LimitedArray;
        }
    } 
}

sub _ApplySort {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Sort}} ) {
        if ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            # sort array by given criteria
            my @SortCriteria;
            my %SpecialSort;
            foreach my $Sort ( @{$Self->{Sort}->{$Object}} ) {
                my $SortField = $Sort->{Field};
                my $Type = $Sort->{Type};

                # special handling for DATE and DATETIME sorts
                if ( $Sort->{Type} eq 'DATE' ) {
                    # handle this as a numeric compare
                    $Type = 'NUMERIC';
                    $SortField = $SortField.'_DateSort';
                    $SpecialSort{'_DateSort'} = 1;

                    # convert field values to unixtime
                    foreach my $ObjectItem ( @{$Param{Data}->{$Object}} ) {
                        my ($DatePart, $TimePart) = split(/\s+/, $ObjectItem->{$Sort->{Field}});
                        $ObjectItem->{$SortField} = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                            String => $DatePart.' 12:00:00',
                        );
                    }
                }
                elsif ( $Sort->{Type} eq 'DATETIME' ) {
                    # handle this as a numeric compare
                    $Type = 'NUMERIC';
                    $SortField = $SortField.'_DateTimeSort';
                    $SpecialSort{'_DateTimeSort'} = 1;

                    # convert field values to unixtime
                    foreach my $ObjectItem ( @{$Param{Data}->{$Object}} ) {
                        $ObjectItem->{$SortField} = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                            String => $ObjectItem->{$Sort->{Field}},
                        );
                    }
                }

                push @SortCriteria, { 
                    order     => $Sort->{Direction}, 
                    compare   => lc($Type), 
                    sortkey   => $SortField,                    
                };
            }

            my @SortedArray = sorted_arrayref($Param{Data}->{$Object}, @SortCriteria);

            # remove special sort attributes
            if ( %SpecialSort ) {
                SPECIALSORTKEY:
                foreach my $SpecialSortKey ( keys %SpecialSort ) {
                    foreach my $ObjectItem ( @SortedArray ) {
                        last SPECIALSORTKEY if !IsHashRefWithData($ObjectItem);

                        my %NewObjectItem;
                        foreach my $ItemAttribute ( keys %{$ObjectItem}) {
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

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    if ( $ENV{'REQUEST_METHOD'} ne 'GET' || !$Self->{OperationConfig}->{ObjectID} || !$Self->{RequestData}->{$Self->{OperationConfig}->{ObjectID}} ) {
        # no GET request or no ObjectID configured or given
        return;
    }

    my $GenericIncludes = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::GenericInclude');
    if ( IsHashRefWithData($GenericIncludes) ) {
        foreach my $Include ( keys %{$Self->{Include}} ) {
            next if !$GenericIncludes->{$Include};

            # we've found a requested generic include, now we have to handle it
            my $IncludeHandler = 'Kernel::API::Operation::' . $GenericIncludes->{$Include}->{Module};

            if ( !$Self->{IncludeHandler}->{$IncludeHandler} ) {
                if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($IncludeHandler) ) {

                    return $Self->_Error(
                        Code    => 'Operation.InternalError',
                        Message => "Can't load include handler $IncludeHandler!"
                    );
                }
                $Self->{IncludeHandler}->{$IncludeHandler} = $IncludeHandler->new(
                    %{$Self},
                );
            }

            my $Result = $Self->{IncludeHandler}->{$IncludeHandler}->Run(
                Controller => $Self->{OperationConfig}->{Controller},
                ObjectID   => $Self->{RequestData}->{$Self->{OperationConfig}->{ObjectID}},
                UserID     => $Self->{Authorization}->{UserID},
            );

            # add result to response
            $Param{Data}->{$Include} = $Result;
        }
    }

    return 1;
}

sub _ApplyExpand {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Expand}} ) {
        # which elements should be expanded
        foreach my $Expander ( @{$Self->{Expand}->{$Object}} ) {
            if ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
                foreach my $ObjectItem ( @{$Param{Data}->{$Object}} ) {
                    my $Result = $Self->_ExpandAttribute(
                        Expander => $Expander,
                        Data     => $ObjectItem,
                    );
                    if ( !$Result->{Success} ) {
                        return $Result;
                    }
                }
            } 
            elsif ( ref($Param{Data}->{$Object}) eq 'HASH' ) {
                my $Result = $Self->_ExpandObject(
                    Expander => $Expander,
                    Data     => $Param{Data}->{$Object},
                );

                if ( !$Result->{Success} ) {
                    return $Result;
                }
            }
        }
    }
}

sub _ExpandObject {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Expander Data)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => '_ExpandObject.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    my @Data;
    if ( ref($Param{Data}->{$Param{Expander}->{Attribute}}) eq 'ARRAY' ) {
        @Data = @{$Param{Data}->{$Param{Expander}->{Attribute}}};
    }
    elsif ( ref($Param{Data}->{$Param{Expander}->{Attribute}}) eq 'HASH' ) {
        # hashref isn't possible
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Expanding a hash is not possible!",
        );
    }
    else {
        # convert scalar into our data array for further use
        @Data = ( $Param{Data}->{$Param{Expander}->{Attribute}} );
    }

    my %ExecData = (
        include     => $Self->{RequestData}->{include},
        expand      => $Self->{RequestData}->{expand},
    );
    $ExecData{$Param{Expander}->{ID}} = join(',', sort @Data);

    if ( $Param{Expander}->{Add} && ref($Param{Expander}->{Add}) eq 'ARRAY' ) {
        foreach my $AddParam ( @{$Param{Expander}->{Add}} ) {
            $ExecData{$AddParam} = $Self->{RequestData}->{$AddParam},
        }
    }

    my $Result = $Self->ExecOperation(
        OperationType => $Param{Expander}->{Operation},
        Data          => \%ExecData,
    );
    if ( !IsHashRefWithData($Result) || !$Result->{Success} ) {
        return $Result;
    }

    if ( ref($Param{Data}->{$Param{Expander}->{Attribute}}) eq 'ARRAY' ) {
        if ( IsArrayRefWithData($Result->{Data}->{$Param{Expander}->{Return}}) ) {
            $Param{Data}->{$Param{Expander}->{Attribute}} = $Result->{Data}->{$Param{Expander}->{Return}};
        }
        else {
            $Param{Data}->{$Param{Expander}->{Attribute}} = [ $Result->{Data}->{$Param{Expander}->{Return}} ];
        }
    }
    else {
        $Param{Data}->{$Param{Expander}->{Attribute}} = $Result->{Data}->{$Param{Expander}->{Return}};
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
    if ( exists($Param{Value}) ) {
        $Value = $Param{Value};
    };
    
    if ($Param{Attribute} =~ /::/) {
        my ($SubKey, $Rest) = split(/::/, $Param{Attribute});
        $Self->_SetParameter(
            Data      => $Param{Data}->{$SubKey},
            Attribute => $Rest,
            Value     => $Param{Value}
        );    
    }
    else {
        $Param{Data}->{$Param{Attribute}} = $Value;
    }
    
    return 1;
}

sub _Trim {
    my ( $Self, %Param ) = @_;

    return if ( !$Param{Data} );

    # remove leading and trailing spaces
    if ( ref($Param{Data}) eq 'HASH' ) {
        foreach my $Attribute ( sort keys %{$Param{Data}} ) {
            $Param{Data}->{$Attribute} = $Self->_Trim(
                Data => $Param{Data}->{$Attribute}
            );
        }
    }
    elsif ( ref($Param{Data}) eq 'ARRAY' ) {
        foreach my $Attribute ( @{$Param{Data}} ) {
            $Param{Data}->{$Attribute} = $Self->_Trim(
                Data => $Param{Data}->{$Attribute}
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
