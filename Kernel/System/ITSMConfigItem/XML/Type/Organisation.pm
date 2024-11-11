# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::Organisation;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Config
    Organisation
    Log
    ObjectSearch
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

    return q{} if !$Param{Value};

    my %OrganisationSearchList = $Self->{OrganisationObject}->OrganisationGet(
        ID => $Param{Value},
    );

    my $OrganisationDataStr = q{};
    my $CustOrganisationMapRef =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::OrganisationBackendMapping');

    if ( $CustOrganisationMapRef && ref($CustOrganisationMapRef) eq 'HASH' ) {

        for my $MappingField ( sort( keys( %{$CustOrganisationMapRef} ) ) ) {
            if ( $OrganisationSearchList{ $CustOrganisationMapRef->{$MappingField} } ) {
                $OrganisationDataStr .= q{ }
                    . $OrganisationSearchList{ $CustOrganisationMapRef->{$MappingField} };
            }
        }

    }

    $OrganisationDataStr =~ s/\s+$//g;
    $OrganisationDataStr =~ s/^\s+//g;

    return $OrganisationDataStr;
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

    my $Result;
    if (
        defined $Param{Result}
        && $Param{Result} eq 'DisplayValue'
    ) {
        $Result = $Self->ValueLookup(
            Value => $Param{Value}
        );
    }
    else {
        # check what should be exported: Number, ID or Name
        my $CustOrganisationContent =
            $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::Organisation::Content');

        return $Param{Value} if ( !$CustOrganisationContent || ( $CustOrganisationContent eq 'ID' ) );

        # get Organisation data
        my %Organisation = $Self->{OrganisationObject}->OrganisationGet(
            ID => $Param{Value},
        );

        # get Organisation attribute content
        $Result = $Organisation{$CustOrganisationContent};
        $Result =~ s/\s+$//g;
        $Result =~ s/^\s+//g;

    }

    return $Result;
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
    my @OrganisationIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Organisation',
        Result     => 'ARRAY',
        Search     => {
            OR => [
                {
                    Field    => 'Fulltext',
                    Operator => 'CONTAINS',
                    Type     => 'STRING',
                    Value    => $Param{Value}
                }
            ]
        },
        UserType => 'Agent',
        UserID   => 1
    );

    if (
        @OrganisationIDs
        && ( scalar( @OrganisationIDs ) == 1 )
    ) {
        return $OrganisationIDs[0];
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

    # return empty string unchanged
    return '' if ( $Param{Value} eq '' );

    # check if content should be Number, ID or Name
    my $CustOrganisationContent =
        $Self->{ConfigObject}->Get('ITSMCIAttributeCollection::Organisation::Content');

    return $Param{Value} if ( !$CustOrganisationContent );

    my $OrganisationDataStr = q{};

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

        # check if it is a valid Organisation
        my $ID = $Self->{OrganisationObject}->OrganisationLookup(
            Name => $Param{Value}
        );

        if ($ID) {
            $OrganisationDataStr = $ID;
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
