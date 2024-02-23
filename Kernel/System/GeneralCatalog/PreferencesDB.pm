# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::GeneralCatalog::PreferencesDB;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'DB',
    'Log',
);

=head1 NAME

Kernel::System::GeneralCatalog::PreferencesDB - some preferences functions for general catalog

=head1 SYNOPSIS

some preferences functions for general catalog

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $GeneralCatalogPreferencesDBObject = $Kernel::OM->Get('GeneralCatalog::PreferencesDB');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # preferences table data
    $Self->{PreferencesTable}      = 'general_catalog_preferences';
    $Self->{PreferencesTableKey}   = 'pref_key';
    $Self->{PreferencesTableValue} = 'pref_value';
    $Self->{PreferencesTableGcID}  = 'general_catalog_id';

    return $Self;
}

=item GeneralCatalogPreferencesSet()

Set preferences for an item

    $PreferencesObject->GeneralCatalogPreferencesSet(
        ItemID => 1234,
        Key    => 'Functionality',
        Value  => 'operational',
    );

=cut

sub GeneralCatalogPreferencesSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ItemID Key Value)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # delete old data
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => "DELETE FROM $Self->{PreferencesTable} WHERE "
            . "$Self->{PreferencesTableGcID} = ? AND $Self->{PreferencesTableKey} = ?",
        Bind => [
            \$Param{ItemID},
            \$Param{Key},
        ],
    );

    # insert new data
    return $Kernel::OM->Get('DB')->Do(
        SQL => "INSERT INTO $Self->{PreferencesTable} ($Self->{PreferencesTableGcID}, "
            . " $Self->{PreferencesTableKey}, $Self->{PreferencesTableValue}) "
            . " VALUES (?, ?, ?)",
        Bind => [
            \$Param{ItemID},
            \$Param{Key},
            \$Param{Value},
        ],
    );
}

=item GeneralCatalogPreferencesGet()

Get all Preferences for an item

    my %Preferences = $PreferencesObject->GeneralCatalogPreferencesGet(
        ItemID => 123,
    );

=cut

sub GeneralCatalogPreferencesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ItemID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # check if preferences are available
    if ( !$Kernel::OM->Get('Config')->Get('GeneralCatalogPreferences') ) {
        return;
    }

    # get preferences
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => "SELECT $Self->{PreferencesTableKey}, $Self->{PreferencesTableValue} "
            . " FROM $Self->{PreferencesTable} WHERE $Self->{PreferencesTableGcID} = ?",
        Bind => [ \$Param{ItemID} ],
    );

    my %Data;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # return data
    return %Data;
}


=item GeneralCatalogPreferencesDelete()

Deletes Preferences for an item

    my $Success = $PreferencesObject->GeneralCatalogPreferencesDelete(
        ItemID => 123,
        Key    => 'SomeKey'    # optional, without all entries are deleted
    );

=cut

sub GeneralCatalogPreferencesDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ItemID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $Where = "$Self->{PreferencesTableGcID} = ?";
    my @Bind = (\$Param{ItemID});

    if ($Param{Key}) {
        $Where .= " AND $Self->{PreferencesTableKey} = ?";
        push(@Bind, \$Param{Key});
    }

    # delete preferences
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => "DELETE FROM $Self->{PreferencesTable} WHERE $Where",
        Bind => \@Bind,
    );

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
