# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::Helper::ParameterConsumer;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::Reporting::Helper::ParameterConsumer - parameter handling helper class for reporting lib

=head1 SYNOPSIS

All parameter handling functions regarding the consumation of parameters.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item _ReplaceParametersInString()

Replace parameters in a string with their actual value or default.

Example:
    my $String = $Object->_ReplaceParametersInString(
        String   => '...'
        UseEmpty => 1           # optional, use empty string for all parameters that are not given
    );

=cut

sub _ReplaceParametersInString {
    my ( $Self, %Param ) = @_;

    return $Param{String} if !$Param{String} || !$Self->{Config};

    my %EmptyValuesForDataType = (
        'STRING'   => '',
        'NUMERIC'  => 0,
        'DATE'     => '0001-01-01',
        'DATETIME' => '0001-01-01 00:00:00',
        'TIME'     => '00:00:00',
    );

    my $String = $Param{String};

    # replace parameters
    foreach my $Parameter ( $Self->_GetParameterDefinitionList() ) {
        my $ParameterValue = $Self->_GetParameterValue(
            Parameter => $Parameter->{Name}
        );        

        if ( !$ParameterValue ) {
            # try to use a configured fallback
            if ( $String =~ /\$\{Parameters\.$Parameter->{Name}\?(.*?)\}/gmx ) {
                $String =~ s/\$\{Parameters\.$Parameter->{Name}\?(.*?)\}/$1/gmx ;
                next;
            }

            if ( $Param{UseEmpty} ) {
                $ParameterValue = $EmptyValuesForDataType{uc($Parameter->{DataType})};
                $String =~ s/\$\{Parameters\.$Parameter->{Name}\?(.*?)\}/$ParameterValue/gmx ;
            }
            next;
        }

        if ( IsArrayRefWithData($ParameterValue) ) {
            $ParameterValue = uc($Parameter->{DataType}) eq 'STRING' ? join(',', (map { "'".$_."'"} @{$ParameterValue})) : join(',', @{$ParameterValue});
        }        
        $String =~ s/\$\{Parameters\.$Parameter->{Name}\??.*?\}/$ParameterValue/gmx;        
    }

    return $String;
}

=item _ReplaceParametersInHashRef()

Replace parameters in a HashRef with their actual value or default.

Example:
    my $String = $Object->_ReplaceParametersInHashRef(
        HashRef  => '...'
        UseEmpty => 1           # optional, use empty string for all parameters that are not given
    );

=cut

sub _ReplaceParametersInHashRef {
    my ( $Self, %Param ) = @_;

    foreach my $Key ( sort keys %{$Param{HashRef}} ) {
        if ( !IsArrayRef($Param{HashRef}->{$Key}) ) {
            $Param{HashRef}->{$Key} = $Self->_ReplaceParametersInString(
                String   => $Param{HashRef}->{$Key},
                UseEmpty => $Param{UseEmpty},
            );
        }
        else {
            foreach my $Item ( @{$Param{HashRef}->{$Key}} ) {
                $Item = $Self->_ReplaceParametersInString(
                    String   => $Item,
                    UseEmpty => $Param{UseEmpty},
                );
            }
        }
    }

}

=item _GetParameterDefinitionList()

get a list of all parameter definitions.

Example:
    my @ParameterDefinitionList = $Object->_GetParameterDefinitionList();

=cut

sub _GetParameterDefinitionList {
    my ( $Self, %Param ) = @_;

    return @{$Self->{Config}->{Parameters} || []};
}

=item _GetParameters()

get a list of all given parameters.

Example:
    my %Parameters = $Object->_GetParameters();

=cut

sub _GetParameters {
    my ( $Self, %Param ) = @_;

    return %{$Self->{Parameters} || {}};
}

=item _GetParameterValue()

get the given value of a parameter.

Example:
    my $Value = $Object->_GetParameterValue(
        Parameter => '...'
    );

=cut

sub _GetParameterValue {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Parameter)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my $Value = $Self->{Parameters}->{$Param{Parameter}};

    # set the default if no value is given and a default exists
    if ( !$Value ) {
        my $Definition = $Self->_GetParameterDefinition(
            Parameter => $Param{Parameter}
        );
        $Value = $Definition->{Default} if IsHashRefWithData($Definition) && $Definition->{Default};
    }

    return $Value;
}

=item _GetParameterDefinition()

get the definition of a parameter.

Example:
    my $Definition = $Object->_GetParameterDefinition(
        Parameter => '...'
    );

=cut

sub _GetParameterDefinition {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Parameter)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    my %ParametersHash = map { $_->{Name} => $_ } @{$Self->{Config}->{Parameters} || []};

    return $ParametersHash{$Param{Parameter}};
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
