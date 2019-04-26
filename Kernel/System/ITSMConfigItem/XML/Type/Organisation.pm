# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::Organisation;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Organisation',
    'Kernel::System::Log'
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
    my $BackendObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::XML::Type::Organisation');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{ConfigObject}       = $Kernel::OM->Get('Kernel::Config');
    $Self->{OrganisationObject} = $Kernel::OM->Get('Kernel::System::Organisation');
    $Self->{LogObject}          = $Kernel::OM->Get('Kernel::System::Log');

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

    # check what should be exported: CustomerID or OrganisationName
    my $CustOrganisationContent =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::Organisation::Content');

    return $Param{Value} if ( !$CustOrganisationContent || ( $CustOrganisationContent eq 'ID' ) );

    # get Organisation data
    my %Organisation = $Self->{OrganisationObject}->OrganisationGet(
        ID => $Param{Value},
    );

    # get company name
    my $OrganisationDataStr = $Organisation{Name};

    $OrganisationDataStr =~ s/\s+$//g;
    $OrganisationDataStr =~ s/^\s+//g;

    # return company name
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

    # check if content is CustomerID or OrganisationName
    my $CustOrganisationContent =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::Organisation::Content');

    return $Param{Value} if ( !$CustOrganisationContent );

    my $OrganisationDataStr = '';

    if ( $CustOrganisationContent eq 'ID' && $Param{Value} ne '' ) {
        # check if it is a valid CustomerID
        my %OrganisationSearchList = $Self->{OrganisationObject}->OrganisationGet(
            ID => $Param{Value},
        );

        if (%OrganisationSearchList) {
            $OrganisationDataStr = $Param{Value};
        }
    }
    elsif ( $CustOrganisationContent eq 'Name' && $Param{Value} ne '') {

        # search for Organisation data
        my %OrganisationSearchList = $Self->{OrganisationObject}->OrganisationSearch(
            Search => $Param{Value},
            Limit  => 500,
        );

        # check each found Organisation
        if (%OrganisationSearchList) {
            foreach my $OrgID ( keys(%OrganisationSearchList) ) {

                my %OrganisationData = $Self->{OrganisationObject}->OrganisationGet(
                    ID => $OrgID,
                );

                # if Name matches - use this OrgID and stop searching
                if ( $OrganisationData{Name} eq $Param{Value} ) {
                    $OrganisationDataStr = $OrganisationData{ID};
                    last;
                }
            }
        }
    }

    # warning if no dada found for the given ID or Name
    if ( !$OrganisationDataStr ) {
        $Self->{LogObject}->Log(
            Priority => 'warning',
            Message =>
                "Could not import Organisation: no ID found for Name $Param{Value}!"
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
