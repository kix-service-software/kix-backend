# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::Organisation;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Organisation',
    'Log'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::Organisation - xml backend module

=head1 SYNOPSIS

All xml functions of Organisation objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::Organisation');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}       = $Kernel::OM->Get('Config');
    $Self->{OrganisationObject} = $Kernel::OM->Get('Organisation');
    $Self->{LogObject}          = $Kernel::OM->Get('Log');

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Value => 11, # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return '' if !$Param{Value};

    my %OrganisationSearchList = $Self->{OrganisationObject}->OrganisationGet(
        ID => $Param{Value},
    );

    my $OrganisationDataStr = '';
    my $CustOrganisationMapRef =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::OrganisationBackendMapping');

    if ( $CustOrganisationMapRef && ref($CustOrganisationMapRef) eq 'HASH' ) {

        for my $MappingField ( sort( keys( %{$CustOrganisationMapRef} ) ) ) {
            if ( $OrganisationSearchList{ $CustOrganisationMapRef->{$MappingField} } ) {
                $OrganisationDataStr .= ' '
                    . $OrganisationSearchList{ $CustOrganisationMapRef->{$MappingField} };
            }
        }

    }

    $OrganisationDataStr =~ s/\s+$//g;
    $OrganisationDataStr =~ s/^\s+//g;

    return $OrganisationDataStr;
}

=item StatsAttributeCreate()

create a attribute array for the stats framework

    my $Attribute = $BackendObject->StatsAttributeCreate(
        Key => 'Key::Subkey',
        Name => 'Name',
        Item => $ItemRef,
    );

=cut

sub StatsAttributeCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Name Item)) {
        if ( !$Param{$Argument} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # create arrtibute
    my $Attribute = [
        {
            Name             => $Param{Name},
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 1,
            Element          => $Param{Key},
            Block            => 'InputField',
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
    return $Param{Value};
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    # check what should be exported: Number, ID or Name
    my $CustOrganisationContent =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::Organisation::Content');

    return $Param{Value} if ( !$CustOrganisationContent || ( $CustOrganisationContent eq 'ID' ) );

    # get Organisation data
    my %Organisation = $Self->{OrganisationObject}->OrganisationGet(
        ID => $Param{Value},
    );

    # get Organisation attribute content
    my $OrganisationDataStr = $Organisation{$CustOrganisationContent};

    $OrganisationDataStr =~ s/\s+$//g;
    $OrganisationDataStr =~ s/^\s+//g;

    return $OrganisationDataStr;
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

    # search for name....
    my %OrganisationSearch = $Self->{OrganisationObject}->OrganisationSearch(
        Search => '*' . $Param{Value} . '*',
    );

    if (
        %OrganisationSearch
        && ( scalar( keys %OrganisationSearch ) == 1 )
        )
    {
        my @Result = keys %OrganisationSearch;
        return $Result[0];
    }

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

    # check if content should be Number, ID or Name
    my $CustOrganisationContent =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::Organisation::Content');

    return $Param{Value} if ( !$CustOrganisationContent );

    my $OrganisationDataStr = '';

    if ($Param{Value} ne '') {
        if ( $CustOrganisationContent eq 'ID') {

            # check if it is a valid Organisation
            my $Number = $Self->{OrganisationObject}->OrganisationLookup(
                ID => $Param{Value}
            );

            if ($Number) {
                $OrganisationDataStr = $Param{Value};
            }
        } elsif ( $CustOrganisationContent eq 'Number') {

            # check if it is a valid Organisation
            my $ID = $Self->{OrganisationObject}->OrganisationLookup(
                Number => $Param{Value}
            );

            if ($ID) {
                $OrganisationDataStr = $ID;
            }
        } elsif ( $CustOrganisationContent eq 'Name') {

            # search for Organisation
            my %OrganisationSearchList = $Self->{OrganisationObject}->OrganisationSearch(
                Name  => $Param{Value},
                Limit => 1,
            );

            if (IsHashRefWithData(\%OrganisationSearchList)) {
                $OrganisationDataStr = [keys %OrganisationSearchList]->[0];
            }
        }
    }

    # warning if no dada found
    if ( !$OrganisationDataStr ) {
        $Self->{LogObject}->Log(
            Priority => 'warning',
            Message =>
                "Could not import Organisation: no Organisation ID found for $CustOrganisationContent ($Param{Value})!"
        );
        return $Param{Value};
    }

    $OrganisationDataStr =~ s/\s+$//g;
    $OrganisationDataStr =~ s/^\s+//g;

    return $OrganisationDataStr;
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
