# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectIcon;

use strict;
use warnings;

use bytes;
use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

use base qw(Kernel::System::EventHandler);

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    Cache
    DB
    Log
);

=head1 NAME

Kernel::System::ObjectIcon

=head1 SYNOPSIS

Add address book functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a ObjectIcon object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ObjectIconObject = $Kernel::OM->Get('ObjectIcon');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'ObjectIcon';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 30;   # 30 days

    # init of event handler
    $Self->EventHandlerInit(
        Config => 'ObjectIcon::EventModulePost',
    );

    return $Self;
}

=item ObjectIconGet()

Get an objecticon.

    my %Result = $ObjectIconObject->ObjectIconGet(
        ID      => 123,
    );

=cut

sub ObjectIconGet {
    my ( $Self, %Param ) = @_;

    my %Result;

    # check required params...
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ClientID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'ObjectIconGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL   => "SELECT id, object, object_id, content_type, content, create_by, create_time, change_by, change_time
                  FROM object_icon WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Data;

    # fetch the result
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Data = (
            ID          => $Data[0],
            Object      => $Data[1],
            ObjectID    => $Data[2],
            ContentType => $Data[3],
            Content     => $Data[4],
            CreateBy    => $Data[5],
            CreateTime  => $Data[6],
            ChangeBy    => $Data[7],
            ChangeTime  => $Data[8],
        );
    }

    # no data found...
    if ( !%Data ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No ObjectIcon with ID $Param{ID} found!",
        );
        return;
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


=item ObjectIconAdd()

Adds a new objecticon

    my $Result = $ObjectIconObject->ObjectIconAdd(
        Object          => 'TicketState'
        ObjectID        => '12',
        ContentType     => 'image/png',
        Content         => '...',
        UserID          => 1,
    );

=cut

sub ObjectIconAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Object ObjectID ContentType Content UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return if !$Self->ObjectIconValidate( %Param );

    my $DBObject = $Kernel::OM->Get('DB');

    # do the db insert...
    my $DBInsert = $DBObject->Do(
        SQL  => "INSERT INTO object_icon (object, object_id, content_type, content, create_by, create_time, change_by, change_time)
                 VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp)",
        Bind => [
            \$Param{Object},
            \$Param{ObjectID},
            \$Param{ContentType},
            \$Param{Content},
            \$Param{UserID},
            \$Param{UserID},
        ],
    );

    #handle the insert result...
    if ($DBInsert) {

        # delete cache
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $Self->{CacheType}
        );

        return if !$DBObject->Prepare(
            SQL => 'SELECT id FROM object_icon WHERE object = ? AND object_id = ?',
            Bind => [
                \$Param{Object}, \$Param{ObjectID}
            ],
            Limit => 1,
        );

        # fetch results
        my $ID;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $ID = $Row[0];
        }

        # trigger event
        $Self->EventHandler(
            Event => 'ObjectIconAdd',
            Data  => {
                ID       => $ID,
                Object   => $Param{Object},
                ObjectID => $Param{ObjectID},
            },
            UserID => $Param{UserID},
        );

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'CREATE',
            Namespace => 'ObjectIcon',
            ObjectID  => $ID,
        );

        return $ID;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "DB insert failed!",
        );
    }

    return;
}

=item ObjectIconUpdate()

Update an objecticon

    my $Result = $ObjectIconObject->ObjectIconUpdate(
        ID              => 123
        Object          => 'TicketState'
        ObjectID        => '12',
        ContentType     => 'image/png',
        Content         => '...',
        UserID          => 1,
    );

=cut

sub ObjectIconUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Object ObjectID ContentType Content UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    return if !$Self->ObjectIconValidate( %Param );

    # do the db insert...
    my $DBUpdate = $Kernel::OM->Get('DB')->Do(
        SQL  => "UPDATE object_icon SET object = ?, object_id = ?, content_type = ?, content = ?, change_by = ?, change_time = current_timestamp WHERE id = ?",
        Bind => [
            \$Param{Object},
            \$Param{ObjectID},
            \$Param{ContentType},
            \$Param{Content},
            \$Param{UserID},
            \$Param{ID},
        ],
    );

    #handle the insert result...
    if ($DBUpdate) {

        # delete cache
        $Kernel::OM->Get('Cache')->CleanUp(
            Type => $Self->{CacheType}
        );

        # trigger event
        $Self->EventHandler(
            Event => 'ObjectIconUpdate',
            Data  => {
                ID       => $Param{ID},
                Object   => $Param{Object},
                ObjectID => $Param{ObjectID},
            },
            UserID => $Param{UserID},
        );

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'UPDATE',
            Namespace => 'ObjectIcon',
            ObjectID  => $Param{ID},
        );

        return $Param{ID};
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "DB update failed!",
        );
    }

    return;
}

=item ObjectIconList()

Returns a ArrayRef with all objecticons

    my $IDs = $ObjectIconObject->ObjectIconList(
        Object   => '...',          # optional
        ObjectID => '...'           # optional
    );

=cut

sub ObjectIconList {
    my ( $Self, %Param ) = @_;
    my %Result;
    my @SQLWhere;
    my @BindVars;

    # check cache
    my $CacheKey = 'ObjectIconList::'.($Param{Object}||'').'::'.($Param{ObjectID}||'');
    my $CacheResult = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );

    return $CacheResult if (IsArrayRefWithData($CacheResult));

    if ($Param{Object}) {
        push(@SQLWhere, 'object = ?');
        push(@BindVars, \$Param{Object});
    }

    if ($Param{ObjectID}) {
        push(@SQLWhere, 'object_id = ?');
        push(@BindVars, \$Param{ObjectID});
    }

    my $SQL = "SELECT id FROM object_icon";

    if (@SQLWhere) {
        $SQL .= ' WHERE '.join(' AND ', @SQLWhere);
    }

    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@BindVars,
    );

    my @Result;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        push(@Result, $Data[0]);
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

    return \@Result;
}

=item ObjectIconDelete()

Delete an objecticon.

    my $Result = $ObjectIconObject->ObjectIconDelete(
        ID      => 123,
    );

=cut

sub ObjectIconDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get old data before delete
    my %OldData = $Self->ObjectIconGet(
        ID => $Param{ID},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL  => 'DELETE FROM object_icon WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # trigger event
    $Self->EventHandler(
        Event => 'ObjectIconDelete',
        Data  => {
            ID       => $Param{ID},
            Object   => $OldData{Object},
            ObjectID => $OldData{ObjectID},
        },
        UserID => $Param{UserID},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'ObjectIcon',
        ObjectID  => $Param{ID},
    );

    return 1;
}

sub ObjectIconValidate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(Content) ) {
        if ( !IsString( $Param{ $Needed } ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
                Silent   => $Param{Silent}
            );
            return;
        }
    }

    # check size
    my $MaxAllowedSize = $Kernel::OM->Get('Config')->Get('ObjectIcon::MaxAllowedSize');
    my $ContentSize = bytes::length( MIME::Base64::decode_base64( $Param{Content} ) );
    if ( !$ContentSize ) {
        $Kernel::OM->Get('Log')->Log( 
            Priority => 'error', 
            Message  => 'Content is empty!',
            Silent   => $Param{Silent}
        );

        return;
    }
    elsif ( $ContentSize > $MaxAllowedSize ) {
        $Kernel::OM->Get('Log')->Log( 
            Priority => 'error', 
            Message  => "Size exceeds maximum allowed size ($MaxAllowedSize bytes)!",
            Silent   => $Param{Silent}
        );

        return;
    }

    return 1;
}

sub DESTROY {
    my $Self = shift;

    # execute all transaction events
    $Self->EventHandlerTransaction();

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
