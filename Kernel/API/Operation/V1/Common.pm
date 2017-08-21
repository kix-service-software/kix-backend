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
        ErrorMessage => 'Error Message',
    }

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # check needed
    if ( !$Param{WebserviceID} ) {
        return {
            Success      => 0,
            ErrorMessage => "Got no WebserviceID!",
        };
    }

    # get webservice configuration
    my $Webservice = $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceGet(
        ID => $Param{WebserviceID},
    );

    if ( !IsHashRefWithData($Webservice) ) {
        return {
            Success => 0,
            ErrorMessage =>
                'Could not determine Web service configuration'
                . ' in Kernel::API::Operation::V1::Common::Init()',
        };
    }

    return {
        Success => 1,
    };
}

=item PrepareData()

prepare data, check given parameters and parse them according to type

    my $Return = $CommonObject->PrepareData(
        Data   => {
            ...
        },
        Parameters => {
            <Parameter> => {                                            # if Parameter is a attribute of a hashref, just separate it by ::, i.e. "User::UserFirstname"
                Type                => 'ARRAY',                         # optional, use this to parse a comma separated string into an array
                Required            => 1,                               # optional
                RequiredIfNot       => [ '<AltParameter>', ... ]        # optional, specify the alternate parameters to be checked, if one of them has a value
                RequiresValueIfUsed => 1                                # optional
                Default             => ...                              # optional
                OneOf               => [...]                            # optional
            }
        }
    );

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        ErrorMessage => 'Error Message',
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
            return $Self->ReturnError(
                ErrorCode    => 'PrepareData.MissingParameter',
                ErrorMessage => "PrepareData: $Needed parameter is missing!",
            );
        }
    }

    # prepare field filter
    if ( exists($Param{Data}->{Filter}) ) {
        foreach my $Filter ( split(/,/, $Param{Data}->{Filter}) ) {
            my ($Object, $FieldFilter) = split(/\./, $Filter);
            my ($Field, $Operation, $Value) = split(/\:/, $FieldFilter);
            $Operation = uc($Operation);
            if ( $Operation !~ /^(EQ|NE|GT|LT|GTE|LTE|IN|CONTAINS)$/g ) {
                return $Self->ReturnError(
                    ErrorCode    => 'PrepareData.InvalidFilterOperation',
                    ErrorMessage => "PrepareData: unknown filter operation in $Filter!",
                );                
            }
            if ( !IsArrayRefWithData($Self->{FieldFilter}->{$Object}) ) {
                $Self->{FieldFilter}->{$Object} = [];
            }
            push @{$Self->{FieldFilter}->{$Object}}, { 
                Field     => $Field, 
                Operation => $Operation, 
                Value     => $Value
            };
        }
    }

    # prepare field selector
    if ( exists($Param{Data}->{Fields}) ) {
        foreach my $FieldSelector ( split(/,/, $Param{Data}->{Fields}) ) {
            my ($Object, $Field) = split(/\./, $FieldSelector);
            if ( !IsArrayRefWithData($Self->{FieldSelector}->{$Object}) ) {
                $Self->{FieldSelector}->{$Object} = [];
            }
            push @{$Self->{FieldSelector}->{$Object}}, $Field;
        }
    }

    # prepare limiter
    if ( exists($Param{Data}->{Limit}) ) {
        foreach my $Limiter ( split(/,/, $Param{Data}->{Limit}) ) {
            my ($Object, $Limit) = split(/\:/, $Limiter);
            if ( $Limit && $Limit !~ /\d+/ ) {
               $Self->{Limiter}->{$Object} = $Limit;
            }
            else {
                $Self->{Limiter}->{__COMMON} = $Object;
            }
        }
    }

    # prepare sorter
    if ( exists($Param{Data}->{Sort}) ) {
        foreach my $Sorter ( split(/,/, $Param{Data}->{Sort}) ) {
            my ($Object, $FieldSort) = split(/\./, $Sorter);
            my ($Field, $Direction, $Type) = split(/\:/, $FieldSort);
            $Direction = uc($Direction);
            if ( $Direction !~ /(ASC|DESC)/g ) {
                return $Self->ReturnError(
                    ErrorCode    => 'PrepareData.InvalidSortDirection',
                    ErrorMessage => "PrepareData: unknown sort direction in $Sorter!",
                );                
            }
            if ( !IsArrayRefWithData($Self->{Sorter}->{$Object}) ) {
                $Self->{Sorter}->{$Object} = [];
            }
            push @{$Self->{Sorter}->{$Object}}, { 
                Field => $Field, 
                Direction => $Direction, 
                Type  => lc($Type || 'cmp')
            };
        }
    }

    my %Data = %{$Param{Data}};

    # if needed flatten hash structure for easier access to sub structures
    if ( ref($Param{Parameters}) eq 'HASH' ) {
        
        if ( grep(/::/, keys %{$Param{Parameters}}) ) {
            my $FlatData = Hash::Flatten::flatten(
                $Param{Data},
                {
                    HashDelimiter => '::',
                }
            );
            %Data = (
                %Data,
                %{$FlatData},
            );
        }

        foreach my $Parameter ( sort keys %{$Param{Parameters}} ) {

            # check requirement
            if ( $Param{Parameters}->{$Parameter}->{Required} && !exists($Data{$Parameter}) ) {
                $Result->{Success} = 0;
                $Result->{ErrorMessage} = "PrepareData: required parameter $Parameter is missing!",
                last;
            }
            elsif ( $Param{Parameters}->{$Parameter}->{RequiredIfNot} && ref($Param{Parameters}->{$Parameter}->{RequiredIfNot}) eq 'ARRAY' ) {
                my $AltParameterHasValue = 0;
                foreach my $AltParameter ( @{$Param{Parameters}->{$Parameter}->{RequiredIfNot}} ) {
                    if ( exists($Data{$AltParameter}) && defined($Data{$AltParameter}) ) {
                        $AltParameterHasValue = 1;
                        last;
                    }
                }
                if ( !exists($Data{$Parameter}) && !$AltParameterHasValue ) {
                    $Result->{Success} = 0;
                    $Result->{ErrorMessage} = "PrepareData: required parameter $Parameter or ".( join(" or ", @{$Param{Parameters}->{$Parameter}->{RequiredIfNot}}) )." is missing!",
                    last;
                }
            }

            # parse into arrayref if parameter value is scalar and ARRAY type is needed
            if ( $Param{Parameters}->{$Parameter}->{Type} && $Param{Parameters}->{$Parameter}->{Type} eq 'ARRAY' && $Data{$Parameter} && ref($Data{$Parameter}) ne 'ARRAY' ) {
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                Value     => [ split('\s*,\s*', $Data{$Parameter}) ],
                );
            }

            # set default value
            if ( !$Data{$Parameter} && exists($Param{Parameters}->{$Parameter}->{Default}) ) {
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                    Value     => $Param{Parameters}->{$Parameter}->{Default},
                );
            }

            # check valid values
            if ( exists($Param{Parameters}->{$Parameter}->{OneOf}) && ref($Param{Parameters}->{$Parameter}->{OneOf}) eq 'ARRAY' ) {
                if ( !grep(/^$Data{$Parameter}$/g, @{$Param{Parameters}->{$Parameter}->{OneOf}}) ) {
                    $Result->{Success} = 0;
                    $Result->{ErrorMessage} = "PrepareData: parameter $Parameter is not one of '".(join(',', @{$Param{Parameters}->{$Parameter}->{OneOf}}))."'!",
                    last;
                }
            }

            # check if we have an optional parameter that needs a value
            if ( $Param{Parameters}->{$Parameter}->{RequiresValueIfUsed} && exists($Data{$Parameter}) && !defined($Data{$Parameter}) ) {
                $Result->{Success} = 0;
                $Result->{ErrorMessage} = "PrepareData: optional parameter $Parameter is used without a value!",
                last;
            }
        }
    }
    
    return $Result; 
}

=item ReturnSuccess()

helper function to return a successful result.

    my $Return = $CommonObject->ReturnSuccess(
        ...
    );

=cut

sub ReturnSuccess {
    my ( $Self, %Param ) = @_;

    # honor a sorter, if we have one
    if ( IsHashRefWithData($Self->{Sorter}) ) {
        $Self->_Sorter(
            Data => \%Param,
        );
    }
    
    # honor a field selector, if we have one
    if ( IsHashRefWithData($Self->{FieldSelector}) ) {
        $Self->_FieldSelector(
            Data => \%Param,
        );
    }

    # honor a limiter, if we have one
    if ( IsHashRefWithData($Self->{Limiter}) ) {
        $Self->_Limiter(
            Data => \%Param,
        );
    }

    # return structure
    return {
        Success      => 1,
        Data         => {
            %Param
        },
    };
}

=item ReturnError()

helper function to return an error message.

    my $Return = $CommonObject->ReturnError(
        ErrorCode    => Ticket.AccessDenied,
        ErrorMessage => 'You don't have rights to access this ticket',
    );

=cut

sub ReturnError {
    my ( $Self, %Param ) = @_;

    $Self->{DebuggerObject}->Error(
        Summary => $Param{ErrorCode},
        Data    => $Param{ErrorMessage},
    );

    # return structure
    return {
        Success      => 0,
        ErrorMessage => "$Param{ErrorCode}: $Param{ErrorMessage}",
        Data         => {
            Error => {
                ErrorCode    => $Param{ErrorCode},
                ErrorMessage => $Param{ErrorMessage},
            },
        },
    };
}

=item ExecOperation()

helper function to execute another operation to work with its result.

    my $Return = $CommonObject->ExecOperation(
        Operation => '...'                              # required
        Data      => {

        }
    );

=cut

sub ExecOperation {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Operation Data)) {
        if ( !$Param{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'ExecOperation.MissingParameter',
                ErrorMessage => "ExecOperation: $Needed parameter is missing!",
            );
        }
    }

    my $Operation = 'Kernel::API::Operation::'.$Param{Operation};

    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($Operation) ) {
        return $Self->ReturnError(
            ErrorCode    => 'ExecOperation.OperationNotFound',
            ErrorMessage => "ExecOperation: $Operation not found!",
        );
    }
    my $OperationObject = $Operation->new( %{$Self} );

    return $OperationObject->Run(
        Data => $Param{Data},
    );
}


# BEGIN INTERNAL

sub _Filter {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Sorter}} ) {
        if ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
        }
    } 
}

sub _FieldSelector {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{FieldSelector}} ) {
        if ( ref($Param{Data}->{$Object}) eq 'HASH' ) {
            # extract filtered fields from hash
            my %NewObject;
            foreach my $Field ( @{$Self->{FieldSelector}->{$Object}} ) {
                $NewObject{$Field} = $Param{Data}->{$Object}->{$Field};
            }
            $Param{Data}->{$Object} = \%NewObject;
        }
        elsif ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            # filter keys in each contained hash
            foreach my $ObjectItem ( @{$Param{Data}->{$Object}} ) {
                if ( ref($ObjectItem) eq 'HASH' ) {
                    my %NewObject;
                    foreach my $Field ( @{$Self->{FieldSelector}->{$Object}} ) {
                        $NewObject{$Field} = $ObjectItem->{$Field};
                    }
                    $ObjectItem = \%NewObject;
                }
            }
        }
    } 

    return 1;
}

sub _Limiter {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Limiter}} ) {
        if ( $Object eq '__COMMON' ) {
            foreach my $DataObject ( keys %{$Param{Data}} ) {
                # ignore the object if we have a specific limiter for it
                next if exists($Self->{Limiter}->{$Object});

                if ( ref($Param{Data}->{$DataObject}) eq 'ARRAY' ) {
                    my @LimitedArray = splice @{$Param{Data}->{$DataObject}}, 0, $Self->{Limiter}->{$DataObject};
                    $Param{Data}->{$DataObject} = \@LimitedArray;
                }
            }
        }
        elsif ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            my @LimitedArray = splice @{$Param{Data}->{$Object}}, 0, $Self->{Limiter}->{$Object};
            $Param{$Object} = \@LimitedArray;
        }
    } 
}

sub _Sorter {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Sorter}} ) {
        if ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            # sort array by given criteria
            my @SortCriteria;
            foreach my $Sorter ( @{$Self->{Sorter}->{$Object}} ) {
                my $Direction;
                if ( $Sorter->{Direction} eq 'ASC' ) {
                    $Direction = 'ascending'; 
                }
                elsif ( $Sorter->{Direction} eq 'DESC' ) {
                    $Direction = 'descending';
                }
                push @SortCriteria, { 
                    Direction   => $Direction, 
                    compare => $Sorter->{Type}, 
                    sortkey => $Sorter->{Field}
                };
            }
            my @SortedArray = sorted_arrayref($Param{Data}->{$Object}, @SortCriteria);
            $Param{Data}->{$Object} = \@SortedArray;
        }
    } 
}

sub _SetParameter {
    my ( $Self, %Param ) = @_;
    
    # check needed stuff
    for my $Needed (qw(Data Attribute)) {
        if ( !$Param{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => '_SetParameter.MissingParameter',
                ErrorMessage => "_SetParameter: $Needed parameter is missing!",
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

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
