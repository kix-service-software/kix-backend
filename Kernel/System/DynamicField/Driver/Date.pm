# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::Date;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use Kernel::Language qw(Translatable);

use base qw(Kernel::System::DynamicField::Driver::BaseDateTime);

our @ObjectDependencies = qw(
    Config
    DB
    DynamicFieldValue
    Main
    Log
    Time
);

=head1 NAME

Kernel::System::DynamicField::Driver::Date

=head1 SYNOPSIS

DynamicFields Date Driver delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=over 4

=item new()

usually, you want to create an instance of this
by using Kernel::System::DynamicField::Backend->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # set field properties
    $Self->{Properties} = {
        'IsSearchable'    => 1,
        'IsSortable'      => 1,
        'SearchOperators' => ['EQ','NE','GT','GTE','LT','LTE'],
        'SearchValueType' => 'DATE'
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions
        = $Kernel::OM->Get('Config')->Get('DynamicFields::Extension::Driver::Date');

    EXTENSION:
    for my $ExtensionKey ( sort keys %{$DynamicFieldDriverExtensions} ) {

        # skip invalid extensions
        next EXTENSION if !IsHashRefWithData( $DynamicFieldDriverExtensions->{$ExtensionKey} );

        # create a extension config shortcut
        my $Extension = $DynamicFieldDriverExtensions->{$ExtensionKey};

        # check if extension has a new module
        if ( $Extension->{Module} ) {

            # check if module can be loaded
            if (
                !$Kernel::OM->Get('Main')->RequireBaseClass( $Extension->{Module} )
                )
            {
                die "Can't load dynamic fields backend module"
                    . " $Extension->{Module}! $@";
            }
        }

        # check if extension contains more properties
        if ( IsHashRefWithData( $Extension->{Properties} ) ) {

            %{ $Self->{Properties} } = (
                %{ $Self->{Properties} },
                %{ $Extension->{Properties} }
            );
        }
    }

    return $Self;
}

sub ValueValidate {
    my ( $Self, %Param ) = @_;

    my $Prefix          = 'DynamicField_' . $Param{DynamicFieldConfig}->{Name};
    my $DateRestriction = $Param{DynamicFieldConfig}->{Config}->{DateRestriction};

    if (
        $Param{Value} &&
        $Param{Value} =~ m/^\d{4}-\d{2}-\d{2}/ &&
        $Param{Value} !~ m/\s(23:59:59|00:00:00)$/
    ) {
        $Param{Value} =~ s/^(\d{4}-\d{2}-\d{2}).*/$1 00:00:00/
    }

    # check for no time in date fields
    if (
        $Param{Value}
        && $Param{Value} !~ m/^\d{4}-\d{2}-\d{2}/
        && !$Param{Silent}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "The value for the field Date is invalid!\n"
                . "The date has to be something like \"YYYY-MM-DD\"",
        );
        return
    }

    my $Success = $Kernel::OM->Get('DynamicFieldValue')->ValueValidate(
        Value => {
            ValueDateTime => $Param{Value}
        },
        UserID => $Param{UserID},
        Silent => $Param{Silent} || 0
    );

    if (
        $Success
        && !$Param{SearchValidation}
        && $DateRestriction
    ) {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Time');

        my $ValueSystemTime = $TimeObject->TimeStamp2SystemTime(
            String => $Param{Value},
            Silent => $Param{Silent} || 0
        );
        my $SystemTime = $TimeObject->SystemTime();
        my ( $SystemTimePast, $SystemTimeFuture ) = $SystemTime;

        # if validating date only value, allow today for selection
        if ( $Param{DynamicFieldConfig}->{FieldType} eq 'Date' ) {

            # calculate today system time boundaries
            my @Today = $TimeObject->SystemTime2Date(
                SystemTime => $SystemTime,
                Silent     => $Param{Silent} || 0
            );
            $SystemTimePast = $TimeObject->Date2SystemTime(
                Year   => $Today[5],
                Month  => $Today[4],
                Day    => $Today[3],
                Hour   => 0,
                Minute => 0,
                Second => 0,
                Silent => $Param{Silent} || 0
            );
            $SystemTimeFuture = $SystemTimePast + 60 * 60 * 24 - 1;    # 23:59:59
        }

        if ( $DateRestriction eq 'DisableFutureDates' && $ValueSystemTime > $SystemTimeFuture ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "The value for the field Date is in the future! The date needs to be in the past!",
            );
            return;
        }
        elsif ( $DateRestriction eq 'DisablePastDates' && $ValueSystemTime < $SystemTimePast ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "The value for the field Date is in the past! The date needs to be in the future!",
            );
            return;
        }
    }

    return $Success;
}


sub ValueSet {
    my ( $Self, %Param ) = @_;

    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    # make sure about time value
    my $Index = 0;
    for my $Value (@Values) {
        if (
            $Value &&
            $Value =~ m/^\d{4}-\d{2}-\d{2}/ &&
            $Value !~ m/\s(23:59:59|00:00:00)$/
        ) {
            $Values[$Index] =~ s/^(\d{4}-\d{2}-\d{2}).*/$1 00:00:00/;
        }
        $Index++;
    }

    return $Self->SUPER::ValueSet(
        %Param,
        Value => \@Values
    );
}

sub RandomValueSet {
    my ( $Self, %Param ) = @_;

    my $YearValue  = int( rand(40) ) + 1_990;
    my $MonthValue = int( rand(9) ) + 1;
    my $DayValue   = int( rand(10) ) + 10;

    my $Value = $YearValue . '-0' . $MonthValue . q{-} . $DayValue . ' 00:00:00';

    my $Success = $Self->ValueSet(
        %Param,
        Value => $Value,
    );

    if ( !$Success ) {
        return {
            Success => 0,
        };
    }
    return {
        Success => 1,
        Value   => $Value,
    };
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
