# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::GeneralCatalog;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Config
    Cache
    CheckItem
    ClientRegistration
    DB
    Log
    Main
);

=head1 NAME

Kernel::System::GeneralCatalog - general catalog lib

=head1 SYNOPSIS

All general catalog functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $GeneralCatalogObject = $Kernel::OM->Get('GeneralCatalog');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # load generator preferences module
    my $GeneratorModule = $Kernel::OM->Get('Config')->Get('GeneralCatalog::PreferencesModule')
        || 'Kernel::System::GeneralCatalog::PreferencesDB';
    if ( $Kernel::OM->Get('Main')->Require($GeneratorModule) ) {
        $Self->{PreferencesObject} = $GeneratorModule->new(%Param);
    }

    # define cache settings
    $Self->{CacheType}   = 'GeneralCatalog';
    $Self->{OSCacheType} = 'ObjectSearch_GeneralCatalog';
    $Self->{CacheTTL}    = 60 * 60 * 3;

    return $Self;
}

=item ClassList()

return an array reference of all general catalog classes

    my $ArrayRef = $GeneralCatalogObject->ClassList();

=cut

sub ClassList {
    my ( $Self, %Param ) = @_;

    # check if result is already cached
    my $CacheKey = 'ClassList';
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # ask database
    $Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT DISTINCT(general_catalog_class) '
            . 'FROM general_catalog ORDER BY general_catalog_class',
    );

    # fetch the result
    my @ClassList;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push @ClassList, $Row[0];
    }

    # cache the result
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@ClassList,
    );

    return \@ClassList;
}

=item ClassRename()

rename a general catalog class

    my $True = $GeneralCatalogObject->ClassRename(
        ClassOld => 'ITSM::ConfigItem::State',
        ClassNew => 'ITSM::ConfigItem::DeploymentState',
    );

=cut

sub ClassRename {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ClassOld ClassNew)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # cleanup given params
    for my $Argument (qw(ClassOld ClassNew)) {
        $Kernel::OM->Get('CheckItem')->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
            RemoveAllSpaces   => 1,
        );
    }

    return 1 if $Param{ClassNew} eq $Param{ClassOld};

    # check if new class name already exists
    $Kernel::OM->Get('DB')->Prepare(
        SQL   => 'SELECT id FROM general_catalog WHERE general_catalog_class = ?',
        Bind  => [ \$Param{ClassNew} ],
        Limit => 1,
    );

    # fetch the result
    my $AlreadyExists = 0;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $AlreadyExists = 1;
    }

    if ($AlreadyExists) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't rename class $Param{ClassOld}! New classname already exists."
        );
        return;
    }

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # reset cache object search
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    # rename general catalog class
    my $Result = $Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE general_catalog SET general_catalog_class = ? '
            . 'WHERE general_catalog_class = ?',
        Bind => [ \$Param{ClassNew}, \$Param{ClassOld} ],
    );

    return if !$Result;

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'GeneralCatalog.Class',
        ObjectID  => $Param{ClassOld}.'::'.$Param{ClassNew},
    );

    return 1;
}

=item ItemList()

returns a list as a hash reference of one general catalog class

    my $HashRef = $GeneralCatalogObject->ItemList(
        Class         => 'ITSM::Service::Type',
        Valid         => 0,                      # (optional) default 1
        Preferences   => {                       # (optional) default {}
            Permission => 2,                     # or whatever preferences can be used
        },
    );

=cut

sub ItemList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Class} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Class!'
        );
        return;
    }

    # set default value
    if ( !defined $Param{Valid} ) {
        $Param{Valid} = 1;
    }

    my $PreferencesCacheKey = '';
    my $PreferencesTable    = '';
    my $PreferencesWhere    = '';
    my @PreferencesBind;

    # handle given preferences
    if ( exists $Param{Preferences} && ref $Param{Preferences} eq 'HASH' ) {

        $PreferencesTable = ', general_catalog_preferences';
        my @Wheres;

        # add all preferences given to where-clause
        for my $Key ( sort keys %{ $Param{Preferences} } ) {

            if ( ref( $Param{Preferences}->{$Key} ) ne 'ARRAY' ) {
                $Param{Preferences}->{$Key} = [ $Param{Preferences}->{$Key} ];
            }

            push @Wheres, '(pref_key = ? AND pref_value IN ('
                . join( ', ', map {'?'} @{ $Param{Preferences}->{$Key} } )
                . '))';

            push @PreferencesBind, \$Key, map { \$_ } @{ $Param{Preferences}->{$Key} };

            # add functionality list to cache key
            $PreferencesCacheKey .= '####' if $PreferencesCacheKey;
            $PreferencesCacheKey .= join q{####}, $Key, map {$_} @{ $Param{Preferences}->{$Key} };
        }

        $PreferencesWhere = 'AND general_catalog.id = general_catalog_preferences.general_catalog_id';
        $PreferencesWhere .= ' AND ' . join ' AND ', @Wheres;
    }

    # create sql string
    my $SQL = "SELECT general_catalog.id, name FROM general_catalog $PreferencesTable "
        . "WHERE general_catalog_class = ? $PreferencesWhere ";
    my @BIND = ( \$Param{Class}, @PreferencesBind );

    # add valid string to sql string
    if ( $Param{Valid} ) {
        $SQL .= 'AND valid_id = 1 ';
    }

    # create cache key
    my $CacheKey = 'ItemList::' . $Param{Class} . '####' . $Param{Valid} . '####' . $PreferencesCacheKey;

    # check if result is already cached
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # ask database
    $Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => \@BIND,
    );

    # fetch the result
    my %Data;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # just return without logging an error and without caching the empty result
    return if !%Data;

    # cache the result
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return \%Data;
}

=item ItemGet()

get item attributes

    my $ItemDataRef = $GeneralCatalogObject->ItemGet(
        ItemID        => 3,
        NoPreferences => 1,       # not required -> 0|1 (default 0)
                                  # returns data without preferences
    );

    or

    my $ItemDataRef = $GeneralCatalogObject->ItemGet(
        Class         => 'ITSM::Service::Type',
        Name          => 'Underpinning Contract',
        NoPreferences => 1,       # not required -> 0|1 (default 0)
                                  # returns data without preferences
    );

returns

    my $Item = {
        'ItemID'     => '23',
        'Class'      => 'ITSM::Service::Type',
        'Name'       => 'Underpinning Contract'
        'Comment'    => 'Some Comment',
        'ValidID'    => '1',
        'CreateTime' => '2012-01-12 09:36:24',
        'CreateBy'   => '1',
        'ChangeTime' => '2012-01-12 09:36:24',
        'ChangeBy'   => '1',
    };

=cut

sub ItemGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ItemID} && ( !$Param{Class} || $Param{Name} eq '' ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ItemID OR Class and Name!'
        );
        return;
    }

    # create sql string
    my $SQL = 'SELECT id, general_catalog_class, name, valid_id, comments, '
        . 'create_time, create_by, change_time, change_by FROM general_catalog WHERE ';
    my @BIND;

    $Param{NoPreferences} ||= 0;

    # add options to sql string
    if ( $Param{Class} && $Param{Name} ne '' ) {

        # check if result is already cached
        my $CacheKey = 'ItemGet::Class::' . $Param{Class} . '::' . $Param{Name} . '::' . $Param{NoPreferences};
        my $Cache    = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # add class and name to sql string
        $SQL .= 'general_catalog_class = ? AND name = ?';
        push @BIND, ( \$Param{Class}, \$Param{Name} );
    }
    else {

        # check if result is already cached
        my $CacheKey = 'ItemGet::ItemID::' . $Param{ItemID} . '::' . $Param{NoPreferences};
        my $Cache    = $Kernel::OM->Get('Cache')->Get(
            Type => $Self->{CacheType},
            Key  => $CacheKey,
        );
        return $Cache if $Cache;

        # add item id to sql string
        $SQL .= 'id = ?';
        push @BIND, \$Param{ItemID};
    }

    # ask database
    $Kernel::OM->Get('DB')->Prepare(
        SQL   => $SQL,
        Bind  => \@BIND,
        Limit => 1,
    );

    # fetch the result
    my %ItemData;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $ItemData{ItemID}     = $Row[0];
        $ItemData{Class}      = $Row[1];
        $ItemData{Name}       = $Row[2];
        $ItemData{ValidID}    = $Row[3];
        $ItemData{Comment}    = $Row[4] || '';
        $ItemData{CreateTime} = $Row[5];
        $ItemData{CreateBy}   = $Row[6];
        $ItemData{ChangeTime} = $Row[7];
        $ItemData{ChangeBy}   = $Row[8];
    }

    # check item
    if ( !$ItemData{ItemID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Item not found in database!',
            );
        }
        return;
    }

    # get general catalog preferences
    if(!$Param{NoPreferences}) {
        my %Preferences = $Self->GeneralCatalogPreferencesGet( ItemID => $ItemData{ItemID} );

        # merge hash
        if (%Preferences) {
            %ItemData = ( %ItemData, %Preferences );
        }
    }

    # cache the result
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => 'ItemGet::Class::' . $ItemData{Class} . '::' . $ItemData{Name} . '::' . $Param{NoPreferences},
        Value => \%ItemData,
    );
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => 'ItemGet::ItemID::' . $ItemData{ItemID} . '::' . $Param{NoPreferences},
        Value => \%ItemData,
    );

    return \%ItemData;
}

=item ItemAdd()

add a new general catalog item

    my $ItemID = $GeneralCatalogObject->ItemAdd(
        Class         => 'ITSM::Service::Type',
        Name          => 'Item Name',
        ValidID       => 1,
        Comment       => 'Comment',              # (optional)
        UserID        => 1,
    );

=cut

sub ItemAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Class ValidID UserID)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # name must be not empty, but number zero (0) is allowed
    if (
        !defined $Param{Name}
        || $Param{Name} eq q{}
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Name!",
        );
        return;
    }

    # set default values
    for my $Argument (qw(Comment)) {
        $Param{$Argument} ||= q{};
    }

    # cleanup given params
    for my $Argument (qw(Class)) {
        $Kernel::OM->Get('CheckItem')->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
            RemoveAllSpaces   => 1,
        );
    }
    for my $Argument (qw(Name Comment)) {
        $Kernel::OM->Get('CheckItem')->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # find exiting item with same name
    $Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id FROM general_catalog '
            . 'WHERE general_catalog_class = ? AND name = ?',
        Bind  => [ \$Param{Class}, \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $NoAdd;
    while ( $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $NoAdd = 1;
    }

    # abort insert of new item, if item name already exists
    if ($NoAdd) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't add new item! General catalog item with same name already exists in this class.",
        );
        return;
    }

    # insert new item
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'INSERT INTO general_catalog '
            . '(general_catalog_class, name, valid_id, comments, '
            . 'create_time, create_by, change_time, change_by) VALUES '
            . '(?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Class}, \$Param{Name},
            \$Param{ValidID},
            \$Param{Comment}, \$Param{UserID},
            \$Param{UserID},
        ],
    );

    # find id of new item
    $Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id FROM general_catalog '
            . 'WHERE general_catalog_class = ? AND name = ?',
        Bind  => [ \$Param{Class}, \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $ItemID;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $ItemID = $Row[0];
    }

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # reset cache object search
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'GeneralCatalog',
        ObjectID  => $ItemID,
    );

    return $ItemID;
}

=item ItemUpdate()

update an existing general catalog item

    my $True = $GeneralCatalogObject->ItemUpdate(
        ItemID        => 123,
        Name          => 'Item Name',
        ValidID       => 1,
        Comment       => 'Comment',    # (optional)
        UserID        => 1,
    );

=cut

sub ItemUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ItemID ValidID UserID)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # name must be not empty, but number zero (0) is allowed
    if (
        !defined $Param{Name}
        || $Param{Name} eq q{}
    ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Name!",
        );
        return;
    }

    # set default values
    for my $Argument (qw(Comment)) {
        $Param{$Argument} ||= q{};
    }

    # cleanup given params
    for my $Argument (qw(Class)) {
        $Kernel::OM->Get('CheckItem')->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
            RemoveAllSpaces   => 1,
        );
    }
    for my $Argument (qw(Name Comment)) {
        $Kernel::OM->Get('CheckItem')->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # get class of item
    $Kernel::OM->Get('DB')->Prepare(
        SQL   => 'SELECT general_catalog_class FROM general_catalog WHERE id = ?',
        Bind  => [ \$Param{ItemID} ],
        Limit => 1,
    );

    # fetch the result
    my $Class;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Class = $Row[0];
    }

    if ( !$Class ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't update item! General catalog item not found in this class.",
        );
        return;
    }

    # find exiting item with same name
    $Kernel::OM->Get('DB')->Prepare(
        SQL   => 'SELECT id FROM general_catalog WHERE general_catalog_class = ? AND name = ?',
        Bind  => [ \$Class, \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $Update = 1;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        if ( $Param{ItemID} ne $Row[0] ) {
            $Update = 0;
        }
    }

    if ( !$Update ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Can't update item! General catalog item with same name already exists in this class.",
        );
        return;
    }

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # reset cache object search
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    my $Result = $Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE general_catalog SET '
            . 'name = ?, valid_id = ?, comments = ?, '
            . 'change_time = current_timestamp, change_by = ? '
            . 'WHERE id = ?',
        Bind => [
            \$Param{Name},
            \$Param{ValidID}, \$Param{Comment},
            \$Param{UserID},  \$Param{ItemID},
        ],
    );

    return if !$Result;

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'GeneralCatalog',
        ObjectID  => $Param{ItemID},
    );

    return 1;
}

=item ItemLookup()

get id or name for an item

    my $Item = $GeneralCatalogObject->ItemLookup( ItemID => $ItemID );

    my $ItemID = $GeneralCatalogObject->ItemLookup( Class => $Class, Name => $Name );

=cut

sub ItemLookup {
    my ( $Self, %Param ) = @_;
    my $ReturnData;
    my $What;

    # check needed stuff
    if ( (!$Param{Class} || !$Param{Name}) && !$Param{ItemID} ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Class and Name or ItemID!',
        );
        return;
    }

    if ( !$Param{ItemID} ) {

        # get (already cached) item list
        my $ItemList = $Self->ItemList(
            Class => $Param{Class},
            Valid => 0,
        );
        my %ItemListReverse = reverse %{$ItemList||{}};
        $ReturnData = $ItemListReverse{$Param{Name}};
        $What = "class \"$Param{Class}\" and name \"$Param{Name}\"";
    }
    else {
        my $Item = $Self->ItemGet(
            ItemID => $Param{ItemID}
        );
        $ReturnData = IsHashRefWithData($Item) ? $Item->{Name} : '';
        $What = "ID $Param{ItemID}";
    }

    # check if data exists
    if ( !defined $ReturnData ) {
        return if $Param{Silent};

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No item for $What found!",
        );
        return;
    }

    return $ReturnData;
}

=item GeneralCatalogPreferencesSet()

set GeneralCatalog preferences

    $GeneralCatalogObject->GeneralCatalogPreferencesSet(
        ItemID => 123,
        Key    => 'UserComment',
        Value  => 'some comment',
    );

=cut

sub GeneralCatalogPreferencesSet {
    my $Self = shift;

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # reset cache object search
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    return $Self->{PreferencesObject}->GeneralCatalogPreferencesSet(@_);
}

=item GeneralCatalogPreferencesGet()

get GeneralCatalog preferences

    my %Preferences = $GeneralCatalogObject->GeneralCatalogPreferencesGet(
        ItemID => 123,
    );

=cut

sub GeneralCatalogPreferencesGet {
    my $Self = shift;

    return $Self->{PreferencesObject}->GeneralCatalogPreferencesGet(@_);
}

=item GeneralCatalogPreferencesDelete()

delete all GeneralCatalog preferences

    my $Success = $GeneralCatalogObject->GeneralCatalogPreferencesDelete(
        ItemID => 123,
    );

=cut

sub GeneralCatalogPreferencesDelete {
    my $Self = shift;

    return $Self->{PreferencesObject}->GeneralCatalogPreferencesDelete(@_);
}

sub GeneralCatalogItemDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(GeneralCatalogItemID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # delete all preferences
    $Self->GeneralCatalogPreferencesDelete(
        ItemID => $Param{GeneralCatalogItemID},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    return if !$DBObject->Prepare(
        SQL  => 'DELETE FROM general_catalog WHERE id = ?',
        Bind => [ \$Param{GeneralCatalogItemID} ],
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # reset cache object search
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'GeneralCatalog',
        ObjectID  => $Param{ItemID},
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
