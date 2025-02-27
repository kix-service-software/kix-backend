# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Channel;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'DB',
    'Log',
);

=head1 NAME

Kernel::System::Channel - communcation channel management

=head1 SYNOPSIS

All channel functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Channel';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item ChannelGet()

get Channel

    my %Channel = $ChannelObject->ChannelGet(
        ID => 123           # required
    );

=cut

sub ChannelGet {
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

    # check cache
    my $CacheKey = "ChannelGet::$Param{ID}";
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT id, name, comments, valid_id, create_time, create_by, change_time, change_by FROM channel WHERE id = ?',
        Bind => [ \$Param{ID} ]
    );

    # fetch the result
    my %Channel;
    while (my @Row = $Kernel::OM->Get('DB')->FetchrowArray()) {
        $Channel{ID}         = $Row[0];
        $Channel{Name}       = $Row[1];
        $Channel{Comment}    = $Row[2];
        $Channel{ValidID}    = $Row[3];
        $Channel{CreateTime} = $Row[4];
        $Channel{CreateBy}   = $Row[5];
        $Channel{ChangeTime} = $Row[6];
        $Channel{ChangeBy}   = $Row[7];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Channel,
    );

    return %Channel;
}

=item ChannelList()

get Channel list

    my %List = $ChannelObject->ChannelList();

=cut

sub ChannelList {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheKey = "ChannelList";
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    $Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id, name FROM channel'
    );

    # fetch the result
    my %ChannelList;
    while (my @Row = $Kernel::OM->Get('DB')->FetchrowArray()) {
        $ChannelList{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%ChannelList,
    );

    return %ChannelList;
}

=item ChannelLookup()

get id or name of a channel

    my $Channel = $ChannelObject->ChannelLookup( ID => $ChannelID );

    my $ChannelID = $ChannelObject->ChannelLookup( Name => $Channel );

=cut

sub ChannelLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} && !$Param{ID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Got no Name or ID!',
            );
        }
        return;
    }

    # get (already cached) type list
    my %ChannelList = $Self->ChannelList(
        Valid => 0,
    );

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{ID} ) {
        $Key        = 'ID';
        $Value      = $Param{ID};
        $ReturnData = $ChannelList{ $Param{ID} };
    }
    else {
        $Key   = 'Name';
        $Value = $Param{Name};
        my %ChannelListReverse = reverse %ChannelList;
        $ReturnData = $ChannelListReverse{ $Param{Name} };
    }

    # check if data exists
    if ( !defined $ReturnData ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No $Key for $Value found!",
            );
        }
        return;
    }

    return $ReturnData;
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
