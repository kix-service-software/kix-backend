# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::DateTime;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::DateTime - xml backend module

=head1 SYNOPSIS

All xml functions of date objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeDateTimeBackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::DateTime');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ValueLookup()

get the date time data of a version

    my $Value = $BackendObject->ValueLookup(
        Value => '2007-03-26 22:01',  # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return $Param{Value} || '';
}

=item StatsAttributeCreate()

create a attribute array for the stats framework

    my $Attribute = $BackendObject->StatsAttributeCreate();

=cut

sub StatsAttributeCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Name Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # create attribute
    my $Attribute = [
        {
            Name             => $Param{Name},
            UseAsXvalue      => 1,
            UseAsValueSeries => 1,
            UseAsRestriction => 1,
            Element          => $Param{Key},
            TimePeriodFormat => 'DateInputFormatLong',
            Block            => 'Time',
            Values           => {
                TimeStart => $Param{Key} . 'NewerDate',
                TimeStop  => $Param{Key} . 'OlderDate',
            },
        },
    ];

    return $Attribute;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # convert the raw data to a system time format
    my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => $Param{Value},
    );

    # convert it back to a standard time stamp
    my $TimeStamp = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
        SystemTime => $SystemTime,
    );

    return $TimeStamp;
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    my $ValidateResult = $Self->ValidateValue(%Param);
    if ( "$ValidateResult" ne "1" ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Value \"$Param{Value}\" is not a valid datetime!",
        );
        return;
    }
    return $Param{Value};
}

=item ValidateValue()

validate given value for this particular attribute type

    my $Value = $BackendObject->ValidateValue(
        Value => ..., # (optional)
    );

=cut

sub ValidateValue {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};

    # check and convert for date format like "2011-05-18"
    if ( $Value =~ m{\A (\d{4} - \d{2} - \d{2} \z) }xms ) {
        $Value = $1 . ' 00:00:00';
    }

    # convert the raw data to a system time format
    my $SystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
        String => $Value,
    );
    if (!$SystemTime) {
        return 'not a valid datetime';
    }

    # convert it back to a standard time stamp
    my $TimeStamp = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
        SystemTime => $SystemTime,
    );
    if (!$TimeStamp) {
        return 'not a valid datetime';
    }

    return 1;
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
