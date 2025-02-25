# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ObjectTag;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Cache
    Log
    DB
);

=head1 NAME

KIXPro::Kernel::System::ObjectTag

=head1 SYNOPSIS

All object tags functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ObjectTagObject = $Kernel::OM->Get('Template');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{CacheType} = 'ObjectTag';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item ObjectTagGet()

Returns data of one ObjectTag

    my %ObjectTag = $ObjectTagObject->ObjectTagGet(
        ID => 1
    );

=cut

sub ObjectTagGet {
    my ($Self, %Param) = @_;

    # check needed stuff
    for ( qw(ID) ) {
        if (!$Param{$_}) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
                Silent   => $Param{Silent}
            );
            return;
        }
    }

    # check cache
    my $CacheKey = 'ObjectTag::Get::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => <<'END',
SELECT id, name, object_id, object_type, create_time, create_by, change_time, change_by
FROM object_tags WHERE id = ?
END
        Bind => [ \$Param{ID} ],
    );

    my %ObjectTag;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %ObjectTag = (
            ID         => $Row[0],
            Name       => $Row[1],
            ObjectID   => $Row[2],
            ObjectType => $Row[3],
            CreateTime => $Row[4],
            CreateBy   => $Row[5],
            ChangeTime => $Row[6],
            ChangeBy   => $Row[7]
        );
    }

    # no data found...
    if ( !%ObjectTag ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No object tag with ID $Param{ID} found!",
            Silent   => $Param{Silent}
        );
        return;
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%ObjectTag,
    );

    return %ObjectTag
}

=item ObjectTagAdd()

add a object tag

    my $ObjectTagID = $ObjectTagObject->ObjectTagAdd(
        Name   => '...',
        UserID => 1,
    );

=cut

sub ObjectTagAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Name ObjectType ObjectID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
                Silent   => $Param{Silent}
            );
            return;
        }
    }

    # cleanup given params
    for my $Argument (qw(Name)) {
        $Kernel::OM->Get('CheckItem')->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # find exiting ObjectTag with the same name
    my $TagID = $Self->ObjectTagExists(
        %Param
    );

    # abort insert of new ObjectTag, if already exists
    if ($TagID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Can't add new ObjectTag! A ObjectTag with name '$Param{Name}' already exists.",
            Silent   => $Param{Silent}
        );
        return $TagID;
    }

    # add object tag to database
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => <<'END',
INSERT INTO object_tags (name, object_id, object_type, create_time, create_by, change_time, change_by)
VALUES (?, ?, ?, current_timestamp, ?, current_timestamp, ?)
END
        Bind => [
            \$Param{Name}, \$Param{ObjectID}, \$Param{ObjectType},
            \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get object tag id
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => 'SELECT id FROM object_tags WHERE name = ? AND object_id = ? AND object_type = ?',
        Bind  => [ \$Param{Name}, \$Param{ObjectID}, \$Param{ObjectType} ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $ID = $Row[0];
    }

    # check object tag id
    if ( !$ID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't find ID for '$Param{Name}'!",
            Silent   => $Param{Silent}
        );
        return;
    }

    # delete cache
    $Self->_CacheCleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'ObjectTag',
        ObjectID  => $ID,
    );

    return $ID;
}

sub ObjectTagExists {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Name ObjectID ObjectType)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
                Silent   => $Param{Silent}
            );
            return;
        }
    }

    # ask database
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => <<'END',
SELECT id
FROM object_tags
WHERE name = ? AND object_id = ? AND object_type = ?
LIMIT 1
END
        Bind => [ \$Param{Name}, \$Param{ObjectID}, \$Param{ObjectType} ]
    );

    # fetch the result
    my $Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $Result = $Row[0];
        last;
    }

    return $Result;
}

sub ObjectTagDelete {
    my ( $Self, %Param ) = @_;

    if (
        !$Param{ID}
        && !$Param{Name}
        && !$Param{ObjectID}
        && !$Param{ObjectType}
    ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ID or Name or ObjectID or ObjectType!",
            Silent   => $Param{Silent}
        );
        return;
    }

    my $SQL = 'DELETE FROM object_tags WHERE ';
    my @SQLWhere;
    my @Bind;

    if ( $Param{ID} ) {
        push( @SQLWhere, 'id = ?' );
        push( @Bind, \$Param{ID} );
    }
    else {
        if ( $Param{Name} ) {
            push( @SQLWhere, 'name = ?' );
            push( @Bind, \$Param{Name} );
        }

        if ( $Param{ObjectType} ) {
            if ( $Param{ObjectID} ) {
                push( @SQLWhere, 'object_type = ?', 'object_id = ?' );
                push( @Bind, \$Param{ObjectType}, \$Param{ObjectID} );
            }
            else {
                push( @SQLWhere, 'object_type = ?' );
                push( @Bind, \$Param{ObjectType} );
            }
        }
    }

    $SQL .= (@SQLWhere ? join( ' AND ', @SQLWhere) : q{} );

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    # reset cache
    $Self->_CacheCleanUp();

    return 1;
}


sub _CacheCleanUp {
    my ( $Self, %Param ) = @_;

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'ObjectSearch_ObjectTag',
    );

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'ObjectSearch_ObjectTagLink',
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
