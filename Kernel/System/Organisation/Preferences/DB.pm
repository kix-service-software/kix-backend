# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Organisation::Preferences::DB;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Organisation';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # preferences table data
    $Self->{PreferencesTable} = $ConfigObject->Get('OrganisationPreferences')->{Params}->{Table}
        || 'organisation_prefs';
    $Self->{PreferencesTableKey} = $ConfigObject->Get('OrganisationPreferences')->{Params}->{TableKey}
        || 'preferences_key';
    $Self->{PreferencesTableValue} = $ConfigObject->Get('OrganisationPreferences')->{Params}->{TableValue}
        || 'preferences_value';
    $Self->{PreferencesTableOrgID} = $ConfigObject->Get('OrganisationPreferences')->{Params}->{TableUserID}
        || 'org_id';

    # set lower if database is case sensitive
    $Self->{Lower} = '';
    if ( $Kernel::OM->Get('DB')->GetDatabaseFunction('CaseSensitive') ) {
        $Self->{Lower} = 'LOWER';
    }

    # create cache prefix
    $Self->{CachePrefix} = 'Organisation'
        . $Self->{PreferencesTable}
        . $Self->{PreferencesTableKey}
        . $Self->{PreferencesTableValue}
        . $Self->{PreferencesTableOrgID};

    return $Self;
}

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    return if !$Param{OrganisationID};
    return if !$Param{Key};

    my $Value = defined $Param{Value} ? $Param{Value} : '';

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # delete old data
    return if !$DBObject->Do(
        SQL => "
            DELETE FROM $Self->{PreferencesTable}
            WHERE $Self->{PreferencesTableOrgID} = ?
                AND $Self->{PreferencesTableKey} = ?",
        Bind => [ \$Param{OrganisationID}, \$Param{Key} ],
    );

    # insert new data
    return if !$DBObject->Do(
        SQL => "
            INSERT INTO $Self->{PreferencesTable}
            ($Self->{PreferencesTableOrgID}, $Self->{PreferencesTableKey}, $Self->{PreferencesTableValue})
            VALUES (?, ?, ?)",
        Bind => [ \$Param{OrganisationID}, \$Param{Key}, \$Value ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return 1;
}

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    return if !$Param{ContactID};

    my $CacheKey = $Self->{CachePrefix} . "::GetPreferences::" . $Param{ContactID};

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get preferences
    return if !$DBObject->Prepare(
        SQL => "
            SELECT $Self->{PreferencesTableKey}, $Self->{PreferencesTableValue}
            FROM $Self->{PreferencesTable}
            WHERE $Self->{PreferencesTableOrgID} = ?",
        Bind => [ \$Param{OrganisationID} ],
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

sub SearchPreferences {
    my ( $Self, %Param ) = @_;

    my $Key   = $Param{Key}   || '';
    my $Value = $Param{Value} || '';

    my $CacheKey = $Self->{CachePrefix} . "::SearchPreferences::" . $Key . '::' . $Value;

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my $Lower = '';
    if ( $DBObject->GetDatabaseFunction('CaseSensitive') ) {
        $Lower = 'LOWER';
    }

    my $SQL = "
        SELECT $Self->{PreferencesTableOrgID}, $Self->{PreferencesTableValue}
        FROM $Self->{PreferencesTable}
        WHERE $Self->{PreferencesTableKey} = ?";
    my @Bind = ( \$Key );

    if ($Value) {
        $SQL .= " AND $Lower($Self->{PreferencesTableValue}) LIKE $Lower(?)";
        push @Bind, \$Value;
    }

    # get preferences
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
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
