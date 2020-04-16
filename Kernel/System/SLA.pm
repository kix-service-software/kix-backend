# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SLA;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Cache',
    'CheckItem',
    'DB',
# ---
# GeneralCatalog
# ---
    'GeneralCatalog',
# ---
    'Log',
    'Valid',
);

=head1 NAME

Kernel::System::SLA - sla lib

=head1 SYNOPSIS

All sla functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SLAObject = $Kernel::OM->Get('SLA');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get configured preferences object
    my $GeneratorModule = $Kernel::OM->Get('Config')->Get('SLA::PreferencesModule')
        || 'Kernel::System::SLA::PreferencesDB';

    # get preferences object
    $Self->{PreferencesObject} = $Kernel::OM->Get($GeneratorModule);

    $Self->{CacheType} = 'SLA';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    # KIX4OTRS-capeIT
    # load service extension modules
    my $CustomModule = $Kernel::OM->Get('Config')->Get('SLA::CustomModule');
    if ($CustomModule) {
        my %ModuleList;
        if ( ref $CustomModule eq 'HASH' ) {
            %ModuleList = %{$CustomModule};
        }
        else {
            $ModuleList{Init} = $CustomModule;
        }
        MODULEKEY:
        for my $ModuleKey ( sort keys %ModuleList ) {
            my $Module = $ModuleList{$ModuleKey};
            next MODULEKEY if !$Module;
            next MODULEKEY if !$Kernel::OM->Get('Main')->RequireBaseClass($Module);
        }
    }
    # EO KIX4OTRS-capeIT

    return $Self;
}

=item SLAList()

return a hash list of slas

    my %SLAList = $SLAObject->SLAList(
        Valid     => 0,  # (optional) default 1 (0|1)
        UserID    => 1,
    );

=cut

sub SLAList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!'
        );
        return;
    }

    # set valid param
    if ( !defined $Param{Valid} ) {
        $Param{Valid} = 1;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');


    my %SQLTable;
    $SQLTable{sla} = 'sla s';
    my @SQLWhere;

    # add valid part
    if ( $Param{Valid} ) {

        # get valid object
        my $ValidObject = $Kernel::OM->Get('Valid');

        # create the valid list
        my $ValidIDs = join ', ', $ValidObject->ValidIDsGet();

        push @SQLWhere, "s.valid_id IN ( $ValidIDs )";
    }

    # create the table and where strings
    my $TableString = join q{, }, values %SQLTable;
    my $WhereString = @SQLWhere ? ' WHERE ' . join q{ AND }, @SQLWhere : '';

    # ask database
    $DBObject->Prepare(
        SQL => "SELECT s.id, s.name FROM $TableString $WhereString",
    );

    # fetch the result
    my %SLAList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $SLAList{ $Row[0] } = $Row[1];
    }

    return %SLAList;
}

=item SLAGet()

Returns an SLA as a hash

    my %SLAData = $SLAObject->SLAGet(
        SLAID  => 123,
        UserID => 1,
    );

Returns:

    my %SLAData = (
          'SLAID'               => '2',
          'Name'                => 'Diamond Pacific - S2',
          'Calendar'            => '2',
          'FirstResponseTime'   => '60',  # in minutes according to business hours
          'FirstResponseNotify' => '70',  # in percent
          'UpdateTime'          => '360', # in minutes according to business hours
          'UpdateNotify'        => '70',  # in percent
          'SolutionTime'        => '960', # in minutes according to business hours
          'SolutionNotify'      => '80',  # in percent
          'ValidID'             => '1',
          'Comment'             => 'Some Comment',
# ---
# GeneralCatalog
# ---
          'TypeID'                  => '5',
          'Type'                    => 'Incident',
          'MinTimeBetweenIncidents' => '4000',  # in minutes
# ---
          'CreateBy'            => '93',
          'CreateTime'          => '2011-06-16 22:54:54',
          'ChangeBy'            => '93',
          'ChangeTime'          => '2011-06-16 22:54:54',
    );

=cut

sub SLAGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(SLAID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check if result is already cached
    my $CacheKey = 'Cache::SLAGet::' . $Param{SLAID};
    my $Cached   = $Kernel::OM->Get('Cache')->Get(
        Type           => $Self->{CacheType},
        Key            => $CacheKey,
        CacheInMemory  => 1,
        CacheInBackend => 0,
    );

    if ( ref $Cached eq 'HASH' ) {
        return %{$Cached};
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get sla from db
    $DBObject->Prepare(
        SQL => 'SELECT id, name, calendar_name, first_response_time, first_response_notify, '
            . 'update_time, update_notify, solution_time, solution_notify, '
            . 'valid_id, comments, create_time, create_by, change_time, change_by '
# ---
# GeneralCatalog
# ---
            . ', type_id, min_time_bet_incidents '
# ---
            . 'FROM sla WHERE id = ?',
        Bind => [
            \$Param{SLAID},
        ],
        Limit => 1,
    );

    # fetch the result
    my %SLAData;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $SLAData{SLAID}               = $Row[0];
        $SLAData{Name}                = $Row[1];
        $SLAData{Calendar}            = $Row[2] || '';
        $SLAData{FirstResponseTime}   = $Row[3];
        $SLAData{FirstResponseNotify} = $Row[4];
        $SLAData{UpdateTime}          = $Row[5];
        $SLAData{UpdateNotify}        = $Row[6];
        $SLAData{SolutionTime}        = $Row[7];
        $SLAData{SolutionNotify}      = $Row[8];
        $SLAData{ValidID}             = $Row[9];
        $SLAData{Comment}             = $Row[10] || '';
        $SLAData{CreateTime}          = $Row[11];
        $SLAData{CreateBy}            = $Row[12];
        $SLAData{ChangeTime}          = $Row[13];
        $SLAData{ChangeBy}            = $Row[14];
# ---
# GeneralCatalog
# ---
        $SLAData{TypeID}                  = $Row[15];
        $SLAData{MinTimeBetweenIncidents} = $Row[16] || 0;
# ---
    }

    # check sla
    if ( !$SLAData{SLAID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such SLAID ($Param{SLAID})!",
        );
        return;
    }
# ---
# GeneralCatalog
# ---
    # get sla type list
    my $SLATypeList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
        Class => 'ITSM::SLA::Type',
    );
    $SLAData{Type} = $SLATypeList->{ $SLAData{TypeID} } || '';
# ---

    # get sla preferences
    my %Preferences = $Self->SLAPreferencesGet( SLAID => $Param{SLAID} );

    # merge hash
    if (%Preferences) {
        %SLAData = ( %SLAData, %Preferences );
    }

    # cache result
    $Kernel::OM->Get('Cache')->Set(
        Type => $Self->{CacheType},
        TTL  => $Self->{CacheTTL},
        Key  => $CacheKey,

        # make a local copy of the sla data to avoid it being altered in-memory later
        Value          => {%SLAData},
        CacheInMemory  => 1,
        CacheInBackend => 0,
    );

    return %SLAData;
}

=item SLALookup()

returns the name or the sla id

    my $SLAName = $SLAObject->SLALookup(
        SLAID => 123,
    );

    or

    my $SLAID = $SLAObject->SLALookup(
        Name => 'SLA Name',
    );

=cut

sub SLALookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{SLAID} && !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need SLAID or Name!',
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( $Param{SLAID} ) {

        # check cache
        my $CacheKey = 'Cache::SLALookup::ID::' . $Param{SLAID};
        my $Cached   = $Kernel::OM->Get('Cache')->Get(
            Type           => $Self->{CacheType},
            Key            => $CacheKey,
            CacheInMemory  => 1,
            CacheInBackend => 0,
        );
        if ( defined $Cached ) {
            return $Cached;
        }

        # lookup
        $DBObject->Prepare(
            SQL   => 'SELECT name FROM sla WHERE id = ?',
            Bind  => [ \$Param{SLAID}, ],
            Limit => 1,
        );

        # fetch the result
        my $Name = '';
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $Name = $Row[0];
        }

        # cache
        $Kernel::OM->Get('Cache')->Set(
            Type           => $Self->{CacheType},
            TTL            => $Self->{CacheTTL},
            Key            => $CacheKey,
            Value          => $Name,
            CacheInMemory  => 1,
            CacheInBackend => 0,
        );

        return $Name;
    }
    else {

        # check cache
        my $CacheKey = 'Cache::SLALookup::Name::' . $Param{Name};
        my $Cached   = $Kernel::OM->Get('Cache')->Get(
            Type           => $Self->{CacheType},
            Key            => $CacheKey,
            CacheInMemory  => 1,
            CacheInBackend => 0,
        );
        if ( defined $Cached ) {
            return $Cached;
        }

        # lookup
        $DBObject->Prepare(
            SQL   => 'SELECT id FROM sla WHERE name = ?',
            Bind  => [ \$Param{Name} ],
            Limit => 1,
        );

        # fetch the result
        my $SLAID = '';
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $SLAID = $Row[0];
        }

        # cache
        $Kernel::OM->Get('Cache')->Set(
            Type           => $Self->{CacheType},
            TTL            => $Self->{CacheTTL},
            Key            => $CacheKey,
            Value          => $SLAID,
            CacheInMemory  => 1,
            CacheInBackend => 0,
        );

        return $SLAID;
    }
}

=item SLAAdd()

add a sla

    my $SLAID = $SLAObject->SLAAdd(
        Name                => 'SLA Name',
        Calendar            => 'Calendar1',  # (optional)
        FirstResponseTime   => 120,          # (optional)
        FirstResponseNotify => 60,           # (optional) notify agent if first response escalation is 60% reached
        UpdateTime          => 180,          # (optional)
        UpdateNotify        => 80,           # (optional) notify agent if update escalation is 80% reached
        SolutionTime        => 580,          # (optional)
        SolutionNotify      => 80,           # (optional) notify agent if solution escalation is 80% reached
        ValidID             => 1,
        Comment             => 'Comment',    # (optional)
        UserID              => 1,
# ---
# GeneralCatalog
# ---
        TypeID                  => 2,
        MinTimeBetweenIncidents => 3443,     # (optional)
# ---
    );

=cut

sub SLAAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
# ---
# GeneralCatalog
# ---
#    for my $Argument (qw(Name ValidID UserID)) {
    for my $Argument (qw(Name ValidID UserID TypeID)) {
# ---
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # set default values
    $Param{Calendar}            ||= '';
    $Param{Comment}             ||= '';
    $Param{FirstResponseTime}   ||= 0;
    $Param{FirstResponseNotify} ||= 0;
    $Param{UpdateTime}          ||= 0;
    $Param{UpdateNotify}        ||= 0;
    $Param{SolutionTime}        ||= 0;
    $Param{SolutionNotify}      ||= 0;
# ---
# GeneralCatalog
# ---
    $Param{MinTimeBetweenIncidents} ||= 0;
# ---

    # get check item object
    my $CheckItemObject = $Kernel::OM->Get('CheckItem');

    # cleanup given params
    for my $Argument (qw(Name Comment)) {
        $CheckItemObject->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # find exiting sla's with the same name
    $DBObject->Prepare(
        SQL   => 'SELECT id FROM sla WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $NoAdd;
    while ( $DBObject->FetchrowArray() ) {
        $NoAdd = 1;
    }

    # abort insert of new sla, if name already exists
    if ($NoAdd) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't add new SLA! '$Param{Name}' already exists.",
        );
        return;
    }

    # add sla to database
    return if !$DBObject->Do(
# ---
# GeneralCatalog
# ---
#        SQL => 'INSERT INTO sla '
#            . '(name, calendar_name, first_response_time, first_response_notify, '
#            . 'update_time, update_notify, solution_time, solution_notify, '
#            . 'valid_id, comments, create_time, create_by, change_time, change_by) VALUES '
#            . '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
#        Bind => [
#            \$Param{Name},                \$Param{Calendar},       \$Param{FirstResponseTime},
#            \$Param{FirstResponseNotify}, \$Param{UpdateTime},     \$Param{UpdateNotify},
#            \$Param{SolutionTime},        \$Param{SolutionNotify}, \$Param{ValidID}, \$Param{Comment},
#            \$Param{UserID}, \$Param{UserID},
#        ],
        SQL => 'INSERT INTO sla '
            . '(name, calendar_name, first_response_time, first_response_notify, '
            . 'update_time, update_notify, solution_time, solution_notify, '
            . 'valid_id, comments, create_time, create_by, change_time, change_by, '
            . 'type_id, min_time_bet_incidents) VALUES '
            . '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?, ?, ?)',
        Bind => [
            \$Param{Name},                \$Param{Calendar},   \$Param{FirstResponseTime},
            \$Param{FirstResponseNotify}, \$Param{UpdateTime}, \$Param{UpdateNotify},
            \$Param{SolutionTime}, \$Param{SolutionNotify}, \$Param{ValidID}, \$Param{Comment},
            \$Param{UserID}, \$Param{UserID}, \$Param{TypeID}, \$Param{MinTimeBetweenIncidents},
        ],
# ---
    );

    # get sla id
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM sla WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $SLAID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $SLAID = $Row[0];
    }

    # check sla id
    if ( !$SLAID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't find SLAID for '$Param{Name}'!",
        );
        return;
    }

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'SLA',
        ObjectID  => $SLAID,
    );

    return $SLAID;
}

=item SLAUpdate()

update a existing sla

    my $True = $SLAObject->SLAUpdate(
        SLAID               => 2,
        Name                => 'SLA Name',
        Calendar            => 'Calendar1',  # (optional)
        FirstResponseTime   => 120,          # (optional)
        FirstResponseNotify => 60,           # (optional) notify agent if first response escalation is 60% reached
        UpdateTime          => 180,          # (optional)
        UpdateNotify        => 80,           # (optional) notify agent if update escalation is 80% reached
        SolutionTime        => 580,          # (optional)
        SolutionNotify      => 80,           # (optional) notify agent if solution escalation is 80% reached
        ValidID             => 1,
        Comment             => 'Comment',    # (optional)
        UserID              => 1,
# ---
# GeneralCatalog
# ---
        TypeID                  => 2,
        MinTimeBetweenIncidents => 3443,  # (optional)
# ---
    );

=cut

sub SLAUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
# ---
# GeneralCatalog
# ---
#    for my $Argument (qw(SLAID Name ValidID UserID)) {
    for my $Argument (qw(SLAID Name ValidID UserID TypeID)) {
# ---
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # set default values
    $Param{Calendar}            ||= '';
    $Param{Comment}             ||= '';
    $Param{FirstResponseTime}   ||= 0;
    $Param{FirstResponseNotify} ||= 0;
    $Param{UpdateTime}          ||= 0;
    $Param{UpdateNotify}        ||= 0;
    $Param{SolutionTime}        ||= 0;
    $Param{SolutionNotify}      ||= 0;
# ---
# GeneralCatalog
# ---
    $Param{MinTimeBetweenIncidents} ||= 0;
# ---

    # get check item object
    my $CheckItemObject = $Kernel::OM->Get('CheckItem');

    # cleanup given params
    for my $Argument (qw(Name Comment)) {
        $CheckItemObject->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # find exiting sla's with the same name
    return if !$DBObject->Prepare(
        SQL   => 'SELECT id FROM sla WHERE name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $Update = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Row[0] != $Param{SLAID} ) {
            $Update = $Row[0];
        }
    }

    # abort update of sla, if name already exists
    if ($Update) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't update SLA! '$Param{Name}' already exists.",
        );
        return;
    }

    # reset cache
    $Kernel::OM->Get('Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => 'Cache::SLAGet::' . $Param{SLAID},
    );
    $Kernel::OM->Get('Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => 'Cache::SLALookup::Name::' . $Param{Name},
    );
    $Kernel::OM->Get('Cache')->Delete(
        Type => $Self->{CacheType},
        Key  => 'Cache::SLALookup::ID::' . $Param{SLAID},
    );

    return if !$DBObject->Do(
# ---
# GeneralCatalog
# ---
#        SQL => 'UPDATE sla SET name = ?, calendar_name = ?, '
#            . 'first_response_time = ?, first_response_notify = ?, '
#            . 'update_time = ?, update_notify = ?, solution_time = ?, solution_notify = ?, '
#            . 'valid_id = ?, comments = ?, change_time = current_timestamp, change_by = ? '
#            . 'WHERE id = ?',
#        Bind => [
#            \$Param{Name},                \$Param{Calendar},       \$Param{FirstResponseTime},
#            \$Param{FirstResponseNotify}, \$Param{UpdateTime},     \$Param{UpdateNotify},
#            \$Param{SolutionTime},        \$Param{SolutionNotify}, \$Param{ValidID}, \$Param{Comment},
#            \$Param{UserID}, \$Param{SLAID},
#        ],
        SQL => 'UPDATE sla SET name = ?, calendar_name = ?, '
            . 'first_response_time = ?, first_response_notify = ?, '
            . 'update_time = ?, update_notify = ?, solution_time = ?, solution_notify = ?, '
            . 'valid_id = ?, comments = ?, change_time = current_timestamp, change_by = ?, '
            . 'type_id = ?, min_time_bet_incidents = ? '
            . 'WHERE id = ?',
        Bind => [
            \$Param{Name},                \$Param{Calendar},   \$Param{FirstResponseTime},
            \$Param{FirstResponseNotify}, \$Param{UpdateTime}, \$Param{UpdateNotify},
            \$Param{SolutionTime}, \$Param{SolutionNotify}, \$Param{ValidID}, \$Param{Comment},
            \$Param{UserID}, \$Param{TypeID}, \$Param{MinTimeBetweenIncidents}, \$Param{SLAID},
        ],
# ---
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'SLA',
        ObjectID  => $Param{SLAID},
    );

    return 1;
}

=item SLAPreferencesSet()

set SLA preferences

    $SLAObject->SLAPreferencesSet(
        SLAID => 123,
        Key       => 'UserComment',
        Value     => 'some comment',
        UserID    => 123,
    );

=cut

sub SLAPreferencesSet {
    my $Self = shift;

    return $Self->{PreferencesObject}->SLAPreferencesSet(@_);
}

=item SLAPreferencesGet()

get SLA preferences

    my %Preferences = $SLAObject->SLAPreferencesGet(
        SLAID => 123,
        UserID    => 123,
    );

=cut

sub SLAPreferencesGet {
    my $Self = shift;

    return $Self->{PreferencesObject}->SLAPreferencesGet(@_);
}

sub SLADelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(SLAID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');
    return if !$DBObject->Prepare(
        SQL  => 'DELETE FROM SLA WHERE id = ?',
        Bind => [ \$Param{SLAID} ],
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'SLA',
        ObjectID  => $Param{SLAID},
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
