# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::DynamicField;

use strict;
use warnings;

our @ObjectDependencies = (
    'DynamicField',
    'Log'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::DynamicField - xml backend module

=head1 SYNOPSIS

All xml functions of DynamicField objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeDummyBackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::DynamicField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{DynamicFieldObject} = $Kernel::OM->Get('DynamicField');
    $Self->{LogObject}          = $Kernel::OM->Get('Log');

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Item  => $ItemRef,
        Value => 11,        # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Item} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'Need Item!',
        );
        return;
    }

    return if !$Param{Value};

    # get item list
    my $ItemList = $Self->{DynamicFieldObject}->DynamicFieldGet(
        Name => $Param{Item}->{Input}->{Name} || '',
    );

    return if !$ItemList;
    return if ref $ItemList->{Config}->{PossibleValues} ne 'HASH';

    my $Value = $ItemList->{Config}->{PossibleValues}->{$Param{Value}};

    return $Value;
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

    my @Values = split '#####', $Param{Value};
    @Values = grep {$_} @Values;

    return \@Values;
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

    # get item list
    my $ItemList = $Self->{DynamicFieldObject}->DynamicFieldGet(
        Name => $Param{Item}->{Input}->{Name} || '',
    );

    return $ItemList->{Config}->{PossibleValues}->{$Param{Value}} || $Param{Value};
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

    my @Values = split '#####', $Param{Value};
    @Values = grep {$_} @Values;

    return \@Values;
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

    # return empty string unchanged
    return '' if ( $Param{Value} eq '' );

    # get item list
    my $ItemList = $Self->{DynamicFieldObject}->DynamicFieldGet(
        Name => $Param{Item}->{Input}->{Name} || '',
    );

    # reverse the list
    my %Name2ID = reverse %{$ItemList->{Config}->{PossibleValues}};

    my $DynamicFieldID = $Name2ID{$Param{Value}};

    if ( !$DynamicFieldID ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "DynamicField lookup of'$Param{Value}' failed!",
        );
        return;
    }

    return $DynamicFieldID;
}

1;


=head1 VERSION

$Revision$ $Date$

=cut




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
