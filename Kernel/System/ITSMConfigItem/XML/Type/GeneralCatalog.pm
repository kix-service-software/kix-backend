# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::GeneralCatalog;

use strict;
use warnings;

our @ObjectDependencies = (
    'GeneralCatalog',
    'Log',
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::GeneralCatalog - xml backend module

=head1 SYNOPSIS

All xml functions of general catalog objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeGeneralCatalogBackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::GeneralCatalog');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

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
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Item!',
        );
        return;
    }

    return if !$Param{Value};

    # get item list
    my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => $Param{Item}->{Input}->{Class} || '',
    );

    return if !$ItemList;
    return if ref $ItemList ne 'HASH';

    my $Value = $ItemList->{ $Param{Value} };

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
    my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => $Param{Item}->{Input}->{Class} || '',
    );

    return $ItemList->{ $Param{Value} } || $Param{Value};
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11,
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # get item list
    my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => $Param{Item}->{Input}->{Class} || '',
    );

    # reverse the list
    my %Name2ID = reverse %{$ItemList};

    my $GeneralCatalogID = $Name2ID{ $Param{Value} };

    if ( !$GeneralCatalogID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "General catalog lookup of'$Param{Value}' failed!",
        );
        return;
    }

    return $GeneralCatalogID;

}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11,
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # get item list
    my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class  => $Param{Item}->{Input}->{Class} || q{},
        Silent => $Param{Silent}
    );

    # reverse the list
    my %Name2ID = reverse %{$ItemList};

    my $GeneralCatalogID = $Name2ID{ $Param{Value} };

    if ( !$GeneralCatalogID ) {
        return if $Param{Silent};
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "General catalog lookup of '$Param{Value}' failed!",
        );
        return;
    }

    return $GeneralCatalogID;
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

    # get the values for the General catalog class
    my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => $Param{Input}->{Class},
    );

    if (!$ItemList->{$Value}) {
        return 'not a valid GeneralCatalog item'
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
