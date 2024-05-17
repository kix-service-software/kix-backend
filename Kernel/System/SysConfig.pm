# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SysConfig;

use strict;
use warnings;

use File::Basename;
use XML::Simple;

use Kernel::System::VariableCheck qw(:all);
use Kernel::System::EventHandler;

use vars qw(@ISA);

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    DB
    Log
);

=head1 NAME

Kernel::System::SysConfig

=head1 SYNOPSIS

Add address book functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a SysConfig object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $SysConfigObject = $Kernel::OM->Get('SysConfig');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    @ISA = qw(
        Kernel::System::EventHandler
    );

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'SysConfig::EventModulePost',
    );

    $Self->{CacheType} = 'SysConfig';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 30;   # 30 days

    # get list of supported SysConfig option types
    $Self->{OptionTypes} = { map {$_ => 1 } $Self->OptionTypeList() };

    foreach my $OptionType ( keys %{$Self->{OptionTypes}} ) {
        my $Backend = 'Kernel::System::SysConfig::OptionType::' . $OptionType;

        if ( !$Kernel::OM->Get('Main')->Require($Backend) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to require $Backend!"
            );
        }

        my $BackendObject = $Backend->new( %{$Self} );
        if ( !$BackendObject ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create instance of $Backend!"
            );
        }

        $Self->{OptionTypeModules}->{$OptionType} = $BackendObject;
    }

    return $Self;
}

=item OptionTypeList()

returns a list of supported SysConfig option types.

    @OptionTypeList = $RoleObject->OptionTypeList();

=cut

sub OptionTypeList {
    my ( $Self, %Param ) = @_;

    # get all type modules - don't use the MainObject because we will have a deep recursion due to ring deps
    my @Files = glob $Kernel::OM->Get('Config')->Get('Home').'/Kernel/System/SysConfig/OptionType/*.pm';

    my @Result = map { my $Module = fileparse($_, '.pm'); $Module } grep { not m/Base\.pm/ } @Files;

    return @Result;
}

=item Exists()

Check if a SysConfig option exists.

    my $Exists = $SysConfigObject->Exists(
        Name => '...',
    );

=cut

sub Exists {
    my ( $Self, %Param ) = @_;

    my %Result;

    # check needed stuff
    for (qw(Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check cache
    my $CacheKey = 'Exists::' . $Param{Name};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => "SELECT name FROM sysconfig WHERE (name = ? or name like ?)",
        Bind => [ \$Param{Name}, \"$Param{Name}###%" ],
    );

    my $Exists = 0;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Exists = 1;
        last;
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => $Exists,
    );

    return $Exists;
}

=item OptionGet()

Get a SysConfig option.

    my %Data = $SysConfigObject->OptionGet(
        Name => '...',
    );

=cut

sub OptionGet {
    my ( $Self, %Param ) = @_;

    my %Result;

    # check needed stuff
    for (qw(Name)) {
        if ( !$Param{$_} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    # check cache
    my $CacheKey = 'OptionGet::' . $Param{Name};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => "SELECT name, context, context_metadata, description, access_level, experience_level,
                  type, group_name, setting, is_required, is_modified, default_value, value, comments,
                  default_valid_id, valid_id, create_time, create_by, change_time, change_by
                  FROM sysconfig WHERE name = ?",
        Bind => [ \$Param{Name} ],
    );

    my %Data;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Data = (
            Name            => $Row[0],
            Context         => $Row[1],
            ContextMetadata => $Row[2],
            Description     => $Row[3],
            AccessLevel     => $Row[4],
            ExperienceLevel => $Row[5],
            Type            => $Row[6],
            Group           => $Row[7],
            Setting         => $Row[8],
            IsRequired      => $Row[9],
            IsModified      => $Row[10],
            Default         => $Row[11],
            Value           => $Row[12],
            Comment         => $Row[13],
            DefaultValidID  => $Row[14],
            ValidID         => $Row[15],
            CreateTime      => $Row[16],
            CreateBy        => $Row[17],
            ChangeTime      => $Row[18],
            ChangeBy        => $Row[19],
        );
    }

    # no data found...
    if ( !%Data ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "SysConfig option '$Param{Name}' not found!",
            );
        }
        return;
    }

    # decode JSON attrs
    foreach my $Attr ( qw(Default Value) ) {
        $Data{$Attr} = $Self->{OptionTypeModules}->{$Data{Type}}->Decode(
            Data => $Data{$Attr}
        );
    }
    $Data{Setting} = $Kernel::OM->Get('JSON')->Decode(
        Data => $Data{Setting}
    );

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

=item OptionGetAll()

Get all SysConfig options (for performance reasons).

    my %AllOptions = $SysConfigObject->OptionGetAll();

=cut

sub OptionGetAll {
    my ( $Self, %Param ) = @_;

    my %Result;

    # check cache
    my $CacheKey = 'OptionGetAll';
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => "SELECT name, context, context_metadata, description, access_level, experience_level,
                  type, group_name, setting, is_required, is_modified, default_value, value, comments,
                  default_valid_id, valid_id, create_time, create_by, change_time, change_by
                  FROM sysconfig"
    );

    # fetch the result
    my $FetchResult = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'Name', 'Context', 'ContextMetadata', 'Description', 'AccessLevel', 'ExperienceLevel', 'Type', 'Group', 'Setting', 'IsRequired',
                     'IsModified', 'Default', 'Value', 'Comment', 'DefaultValidID', 'ValidID', 'CreateTime', 'CreateBy', 'ChangeTime', 'ChangeBy']
    );

    # no data found...
    if ( ref $FetchResult ne 'ARRAY' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Error while fetching SysConfig options",
        );
        return;
    }

    my %Data = map {
        $_->{Setting} = $Kernel::OM->Get('JSON')->Decode(
            Data => $_->{Setting}
        );
        $_->{Default} = $Self->{OptionTypeModules}->{$_->{Type}}->Decode(
            Data => $_->{Default}
        );
        $_->{Value} = $Self->{OptionTypeModules}->{$_->{Type}}->Decode(
            Data => $_->{Value}
        );
        $_->{Name} => $_
    } @{$FetchResult};

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    );

    return %Data;
}

=item OptionAdd()

Adds a new SysConfig option

    my $Result = $SysConfigObject->OptionAdd(
        Name            => 'some name',
        Description     => 'some description',
        Type            => 1,
        AccessLevel     => 'internal',
        Context         => '...'                    # optional
        ContextMetadata => '...'                    # optional
        ExperienceLevel => 200,                     # optional
        Group           => 'some group',            # optional
        IsRequired      => 1,                       # optional, default = 0
        Setting         => 'whatever',              # optional
        Default         => 'whatever',              # optional
        Comment         => '',                      # optional
        DefaultValidID  => 1,                       # optional, default = 1
        UserID          => 1
    );

=cut

sub OptionAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name Description Type AccessLevel UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( !$Self->{OptionTypes}->{$Param{Type}} ) {
        $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Type \"$Param{Type} not supported!" );
        return;
    }

    if ( $Param{Setting} && ref $Param{Setting} ) {
        # always encode the Setting config to JSON
        $Param{Setting} = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Setting}
        );
    }
    if ( $Param{Default} && ref $Param{Default} ) {
        $Param{Default} = $Self->{OptionTypeModules}->{$Param{Type}}->Encode(
            Data => $Param{Default}
        )
    }

    my $IsRequired = $Param{IsRequired} // 0;

    $Param{DefaultValidID} = !defined $Param{DefaultValidID} || $Param{DefaultValidID} == 1 ? 1 : 2;

    # do the db insert...
    my $Result = $Kernel::OM->Get('DB')->Do(
        SQL  => "INSERT INTO sysconfig
                 (name, context, context_metadata, description, access_level, experience_level, type, group_name, setting,
                  is_required, is_modified, default_value, comments, default_valid_id, valid_id,
                  create_time, create_by, change_time, change_by)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)",
        Bind => [
            \$Param{Name}, \$Param{Context}, \$Param{ContextMetadata}, \$Param{Description},
            \$Param{AccessLevel}, \$Param{ExperienceLevel}, \$Param{Type}, \$Param{Group},
            \$Param{Setting}, \$IsRequired, \$Param{Default}, \$Param{Comment}, \$Param{DefaultValidID}, \$Param{DefaultValidID},
            \$Param{UserID}, \$Param{UserID}
        ],
    );

    # handle the insert result...
    if ( !$Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "DB insert failed!",
        );

        return;
    }

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # delete OS cache
    $Self->_ObjectSearchCacheCleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'SysConfigOption',
        ObjectID  => $Param{Name},
    );

    return 1;
}

=item OptionUpdate()

Update a SysConfig option

    my $Result = $SysConfigObject->OptionUpdate(
        Name            => 'some name',
        Description     => 'some description',      # optional
        Context         => '...'                    # optional
        ContextMetadata => '...'                    # optional
        AccessLevel     => 'internal',              # optional
        ExperienceLevel => 200,                     # optional
        Type            => 1,                       # optional
        Group           => 'some group',            # optional
        IsRequired      => 1,                       # optional
        Setting         => 'whatever',              # optional
        Default         => 'whatever',              # optional
        Value           => 'whatever'               # optional
        Comment         => '',                      # optional
        DefaultValidID  => 1,                       # optional
        ValidID         => 1,                       # optional
        UserID          => 1
    );

=cut

sub OptionUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name UserID)) {
        if ( !defined( $Param{$_} ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    if ( $Param{Type} && !$Self->{OptionTypes}->{$Param{Type}} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Type \"$Param{Type} not supported!"
            );
        }
        return;
    }

    my %OldOptionData = $Self->OptionGet(
        Name => $Param{Name},
    );

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key (qw(Name Context ContextMetadata Description AccessLevel ExperienceLevel Type Group IsRequired Setting Default Value Comment DefaultValidID ValidID)) {

        next KEY if defined $OldOptionData{$Key} && $OldOptionData{$Key} eq $Param{$Key};

        $ChangeRequired = 1;

        last KEY;
    }
    return 1 if (!$ChangeRequired);

    $Param{Default} = $Param{Default} // $OldOptionData{Default};

    $Param{DefaultValidID} = !defined $Param{DefaultValidID} ? $OldOptionData{DefaultValidID} : $Param{DefaultValidID} == 1 ? 1 : 2;

    # determine if this option has been modified
    my $IsModified = 0;
    if ( defined $Param{Value} && $Param{Value} ne '' && DataIsDifferent(Data1 => \($Param{Default} || ''), Data2 => \$Param{Value}) ) {
        $IsModified = 1;
    }
    else {

        # if there is no difference to the default, remove value
        $Param{Value} = undef;
    }

    if ( defined $Param{ValidID} && $Param{ValidID} != $Param{DefaultValidID} ) {
        $IsModified = 1;
    } else {
        $Param{ValidID} = $Param{DefaultValidID};
    }

    # encode some attributes if necessary
    if ( $Param{Setting} && ref $Param{Setting} ) {
        $Param{Setting} = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Setting}
        );
    }
    if ( $Param{Default} && ref $Param{Default} ) {
        my $Type = $Param{Type} || $OldOptionData{Type};
        $Param{Default} = $Self->{OptionTypeModules}->{$Type}->Encode(
            Data => $Param{Default}
        )
    }
    if ( $Param{Value} && ref $Param{Value} ) {
        my $Type = $Param{Type} || $OldOptionData{Type};
        $Param{Value} = $Self->{OptionTypeModules}->{$Type}->Encode(
            Data => $Param{Value}
        )
    }

    # do the db update...
    my $Result = $Kernel::OM->Get('DB')->Do(
        SQL  => "UPDATE sysconfig SET
                 name = ?, context = ?, context_metadata = ?, description = ?, access_level = ?,
                 experience_level = ?, type = ?, group_name = ?, setting = ?, is_required = ?,
                 is_modified = ?, default_value = ?, value = ?, comments = ?, default_valid_id = ?, valid_id = ?,
                 change_time = current_timestamp, change_by = ? WHERE name = ?",
        Bind => [
            \$Param{Name}, \$Param{Context}, \$Param{ContextMetadata}, \$Param{Description},
            \$Param{AccessLevel}, \$Param{ExperienceLevel}, \$Param{Type}, \$Param{Group},
            \$Param{Setting}, \$Param{IsRequired}, \$IsModified, \$Param{Default}, \$Param{Value},
            \$Param{Comment}, \$Param{DefaultValidID}, \$Param{ValidID}, \$Param{UserID}, \$Param{Name}
        ],
    );

    # handle the update result...
    if ( !$Result ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "DB update failed!",
            );
        }
        return;
    }

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # delete OS cache
    $Self->_ObjectSearchCacheCleanUp();

    my %OptionData = $Self->OptionGet(
        Name => $Param{Name},
    );

    $Self->EventHandler(
        Event => 'SysConfigOptionUpdate',
        Data  => {
            Name      => $Param{Name},
            OldOption => \%OldOptionData,
            NewOption => \%OptionData
        },
        UserID => $Param{UserID} || 1,
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'SysConfigOption',
        ObjectID  => $Param{Name},
    );

    return 1;
}

=item OptionList()

Returns an array with all SysConfig option names.

    my @List = $SysConfigObject->OptionList();

=cut

sub OptionList {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheKey = 'OptionList';
    my $CacheResult = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );
    return @{$CacheResult} if (IsArrayRefWithData($CacheResult));

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT name FROM sysconfig',
    );

    my @Result;
    while ( my @Data = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(@Result, $Data[0]);
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

    return @Result;
}

=item OptionDelete()

Delete a SysConfig option.

    my $Result = $SysConfigObject->OptionDelete(
        Name => '...',
    );

=cut

sub OptionDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM sysconfig WHERE name = ?',
        Bind => [ \$Param{Name} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # delete OS cache
    $Self->_ObjectSearchCacheCleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'SysConfigOption',
        ObjectID  => $Param{Name},
    );

    return 1;
}

=item ValueGet()

Get the value of a SysConfig option

    my $Value = $SysConfigObject->ValueGet(
        Name => 'some name',
    );

=cut

sub ValueGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my %OptionData = $Self->OptionGet(
        Name => $Param{Name},
    );

    return $OptionData{Value};
}

=item ValueGetAll()

Get the value of all (valid) SysConfig option

    my %AllOptions = $SysConfigObject->ValueGetAll(
        Valid    => 0|1,        # default: 0
        Modified => 0|1,        # default: 0
    );

=cut

sub ValueGetAll {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheKey = 'ValueGetAll::'.($Param{Valid} || '').'::'.($Param{Modified} || '');
    my $CacheResult = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );
    return %{$CacheResult} if IsHashRefWithData($CacheResult);

    my $Where = '';
    if ( $Param{Valid} ) {
        $Where = 'WHERE valid_id = 1'
    }
    if ( $Param{Modified} ) {
        if ( $Where ) {
            $Where .= ' AND is_modified = 1';
        }
        else {
            $Where = 'WHERE is_modified = 1';
        }
    }

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => "SELECT name, type, default_value, value, valid_id FROM sysconfig ".$Where
    );

    # fetch the result
    my $FetchResult = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'Name', 'Type', 'Default', 'Value', 'ValidID' ]
    );

    # no data found...
    if ( ref $FetchResult ne 'ARRAY' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Error while fetching SysConfig option values",
        );
        return;
    }

    my %Result = map {
        my $Value = defined $_->{Value} && $_->{Value} ne '' ? $_->{Value} : $_->{Default};
        if ( $Value && $Self->{OptionTypeModules}->{$_->{Type}} ) {
            $Value = $Self->{OptionTypeModules}->{$_->{Type}}->Decode(
                Data => $Value
            );
        }
        $_->{Name} => $Value
    } @{$FetchResult};

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Result,
    );

    return %Result;
}

=item ValueSet()

Set the value of a SysConfig option

    my $Success = $SysConfigObject->ValueSet(
        Name   => 'some name',
        Value  => ...
        UserID => 1,
    );

=cut

sub ValueSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name UserID)) {
        if ( !defined( $Param{$_} ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    my %OptionData = $Self->OptionGet(
        Name   => $Param{Name},
        Silent => $Param{Silent},
    );
    return if ( !%OptionData );

    my $Result = $Self->OptionUpdate(
        %OptionData,
        Value  => $Param{Value},
        UserID => $Param{UserID},
        Silent => $Param{Silent},
    );

    return $Result;
}

=item CleanUp()

Delete all SysConfig options.

    my $Result = $SysConfigObject->CleanUp();

=cut

sub CleanUp {
    my ( $Self, %Param ) = @_;

    # get database object
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM sysconfig',
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # delete OS cache
    $Self->_ObjectSearchCacheCleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'SysConfigOption',
    );

    return 1;
}

=item Rebuild()

Rebuild the configuration database from XML files.

    my $Result = $SysConfigObject->Rebuild(
        Name => '...',
    );

=cut

sub Rebuild {
    my ( $Self, %Param ) = @_;

    my $Home = $ENV{KIX_HOME} || $Kernel::OM->Get('Config')->Get('Home');
    if ( !$Home ) {
        use FindBin qw($Bin);
        $Home = $Bin.'/..';
    }

    # add framework
    my @Directories = (
        $Home.'/Kernel/Config/Files'
    );

    # add plugin folders
    my @Plugins = $Kernel::OM->Get('Installation')->PluginList(
        Valid     => 1,
        InitOrder => 1
    );
    foreach my $Plugin ( @Plugins ) {
        my $Directory = $Plugin->{Directory}.'/Kernel/Config/Files';
        next if ! -e $Directory;

        push @Directories, $Directory;
    }

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    # This is the sorted configuration XML entry list that we must populate here.
    $Self->{XMLConfig} = [];

    my %HandledKeys;
    my %AllOptions = $Self->OptionGetAll();

    foreach my $Directory ( @Directories ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message  => "Rebuilding config from directory $Directory.",
        );

        # get list of XML config files
        my @Files = $MainObject->DirectoryRead(
            Directory => $Directory,
            Filter    => "*.xml",
            Recursive => 1,
        );

        my $XMLObject = XML::Simple->new( KeepRoot => 1, ForceArray => ['ConfigItem','Item'] );

        # read and parse each XML file
        my %Data;
        FILE:
        for my $File (sort @Files) {

            my $ConfigFile = $MainObject->FileRead(
                Location => $File,
                Mode     => 'binmode',
                Result   => 'SCALAR',
            );

            if ( !ref $ConfigFile || !${$ConfigFile} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Can't open file $File: $!",
                );
                next FILE;
            }

            $Data{$File} = $XMLObject->XMLin($ConfigFile);
        }

        my %RebuiltKeys = $Self->_RebuildFromFile(
            Data => \%Data,
        );
        %HandledKeys = (
            %HandledKeys,
            %RebuiltKeys
        );
    }

    # cleanup all no-longer existing options
    my @OptionList = $Self->OptionList();
    foreach my $Name ( @OptionList ) {
        next if $HandledKeys{$Name};

        # keep options with context
        next if IsHashRefWithData($AllOptions{$Name}) && $AllOptions{$Name}->{Context};

        # delete DB entry
        $Self->OptionDelete(
            Name => $Name
        );
    }

    return 1;
}

sub _RebuildFromFile {
    my ( $Self, %Param ) = @_;

    return if !IsHashRefWithData($Param{Data});

    my %Data = %{$Param{Data}};

    # These are the valid "init" values that the config XML may use. Settings must be processed in this order, and inside each group alphabetically.
    my %ValidInit = (
        Framework   => 1,
        Application => 1,
        Config      => 1,
        Changes     => 1,
    );

    # Temp hash for sorting
    my %XMLConfigTMP;

    # Loop over the sorted files and assign all configs to the init section
    for my $File ( sort keys %Data ) {

        # prepare default group based on filename
        my $DefaultGroup;
        if ( $File =~ /Kernel\/Config\/Files\/(.+?)\./ ) {
            $DefaultGroup = $1;
            $DefaultGroup =~ s/^\///g;
        }

        my $Init = $Data{$File}->{kix_config}->{init} || '';
        if ( !$ValidInit{$Init} ) {
            $Init = 'Unknown';    # Fallback for unknown init values
        }

        # Just use valid entries.
        if ( IsArrayRefWithData($Data{$File}->{kix_config}->{ConfigItem}) ) {
            my $ConfigItemList = $Data{$File}->{kix_config}->{ConfigItem};

            foreach my $ConfigItem ( @{$ConfigItemList} ) {
                # prepare group
                if ( $ConfigItem->{Group} ) {
                    $ConfigItem->{Group} = $DefaultGroup;
                }
            }

            push(
                @{ $XMLConfigTMP{$Init} },
                @{ $ConfigItemList }
            );
        }
    }

    # Now process the entries in init order and assign them to the xml entry list.
     for my $Init (qw(Framework Application Config Changes Unknown)) {
        for my $Option ( @{ $XMLConfigTMP{$Init} } ) {
            push(
                @{ $Self->{XMLConfig} },
                $Option
            );
        }
    }

    # Only the last config XML entry should be used, remove any previous ones.
    my %Seen;
    my @XMLConfigTmp;

    OPTION:
    for my $Option ( reverse @{ $Self->{XMLConfig} } ) {
        next OPTION if !$Option || !$Option->{Name} || $Seen{ $Option->{Name} }++;
        push @XMLConfigTmp, $Option;
    }
    $Self->{XMLConfig} = \@XMLConfigTmp;

    # read complete list of SysConfig options from database to reduce time in loop
    my %AllOptions = $Self->OptionGetAll();

    my $JSONObject = $Kernel::OM->Get('JSON');

    # update all keys
    my $Total = @{ $Self->{XMLConfig} };
    my $Count = 0;
    my %ExistingKeys;
    OPTIONRAW:
    for my $OptionRaw ( @{ $Self->{XMLConfig} } ) {

        # ignore options without name
        next if !$OptionRaw->{Name};

        # store key for cleanup
        $ExistingKeys{$OptionRaw->{Name}} = 1;

        # get Type
        my $Type = (keys %{$OptionRaw->{Setting}})[0];

        # check type
        if ( !$Self->{OptionTypeModules}->{$Type} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Item has unknown type \"$Type\".",
            );
            next;
        }

        my ($Setting, $DefaultValue) = $Self->{OptionTypeModules}->{$Type}->ValidateSetting(
            Setting => $OptionRaw->{Setting}->{$Type},
        );

        my %Option = (
            Name            => $OptionRaw->{Name},
            Description     => $OptionRaw->{Description}->{content} || '',
            AccessLevel     => $OptionRaw->{AccessLevel},
            Context         => $OptionRaw->{Context},
            ExperienceLevel => $OptionRaw->{ExperienceLevel},
            Type            => $Type,
            Group           => $OptionRaw->{Group},
            Setting         => $Setting,
            IsRequired      => $OptionRaw->{Required},
            Default         => $DefaultValue,
            DefaultValidID  => $OptionRaw->{Valid} == 1 ? 1 : 2,
        );

        # check if we have to extend an existing option (only types Hash and Array can be extended at the moment)
        if ( $OptionRaw->{Extend} ) {
            # check if the option to extend exists
            if ( !$AllOptions{ $OptionRaw->{Name} } ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Unable to extend option \"$Option{Name}\", because it doesn't exist.",
                );
                next;
            }

            # this options extends an existing option
            $Option{Default} = $Self->{OptionTypeModules}->{$Type}->Extend(
                Value  => $AllOptions{ $Option{Name} }->{Default},
                Extend => $DefaultValue,
            );
        }

        # check if this is a new option
        if ( !$AllOptions{ $Option{Name} } ) {
            # just import the new option
            my $Result = $Self->OptionAdd(
                %Option,
                UserID => 1,
            );
        }
        else {
            # we have to update the option
            my $Result = $Self->OptionUpdate(
                %{ $AllOptions{ $Option{Name} } },
                %Option,
                UserID => 1,
            );
        }

        $Count++;
    }

    return %ExistingKeys;
}

sub _ObjectSearchCacheCleanUp {
    my ( $Self, %Param ) = @_;

    # delete cache for OS ConfigItem
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'ObjectSearch_ConfigItem'
    );

    # delete cache for OS GeneralCatalog
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'ObjectSearch_GeneralCatalog'
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
