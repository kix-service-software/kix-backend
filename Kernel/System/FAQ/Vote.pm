# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FAQ::Vote;

use strict;
use warnings;

our @ObjectDependencies = (
    'Cache',
    'DB',
    'Log',
);

=head1 NAME

Kernel::System::FAQ::Vote - sub module of Kernel::System::FAQ

=head1 SYNOPSIS

All FAQ vote functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item VoteAdd()

add a vote

    my $VoteID = $FAQObject->VoteAdd(
        CreatedBy => 'Some Text',
        ItemID    => '123456',
        IP        => '54.43.30.1',
        Interface => 'Some Text',
        Rate      => 1,
        UserID    => 1,
    );

Returns:

    $Success = 1;              # or undef if vote could not be added

=cut

sub VoteAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(CreatedBy ItemID IP Interface UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Do(
        SQL => '
            INSERT INTO faq_voting (created_by, item_id, ip, interface, rate, created )
            VALUES ( ?, ?, ?, ?, ?, current_timestamp )',
        Bind => [
            \$Param{CreatedBy}, \$Param{ItemID}, \$Param{IP}, \$Param{Interface},
            \$Param{Rate},
        ],
    );

    # get new category id
    return if !$DBObject->Prepare(
        SQL => '
            SELECT id
            FROM faq_voting
            WHERE created_by = ? AND item_id = ? AND ip = ? AND interface = ?',
        Bind  => [
            \$Param{CreatedBy}, \$Param{ItemID}, \$Param{IP}, \$Param{Interface},
        ],
        Limit => 1,
    );

    my $VoteID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $VoteID = $Row[0];
    }

    # clear cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'FAQ.Article.Vote',
        ObjectID  => $Param{ItemID},
    );

    return $VoteID;
}

=item VoteDelete()

delete a vote

    my $DeleteSuccess = $FAQObject->VoteDelete(
        VoteID => 1,
        UserID => 1,
    );

Returns:

    $DeleteSuccess = 1;              # or undef if vote could not be deleted

=cut

sub VoteDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(VoteID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    my %Vote = $Self->VoteGet(
        VoteID => $Param{VoteID},
        UserID => 1,
    );

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => '
            DELETE FROM faq_voting
            WHERE id = ?',
        Bind => [ \$Param{VoteID} ],
    );

    # clear cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'FAQ.Article.Vote',
        ObjectID  => $Vote{ItemID}.'::'.$Param{VoteID},
    );

    return 1;
}

=item VoteGet()

get a vote information

    my %VoteData = $FAQObject->VoteGet(
        VoteID => 1,
        UserID => 1,
    );

Returns:

    %VoteData = (
        ItemID    => 23,
        ID        => 1,
        Rating    => 5,
        IP        => '192.168.0.1',
        Interface => '...',
        CreatedBy => 1,
        Created   => '2011-06-14 12:32:03',
    );

=cut

sub VoteGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(VoteID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL   => 'SELECT id, created_by, item_id, interface, ip, created, rate
                  FROM faq_voting
                  WHERE id = ?',
        Bind  => [ \$Param{VoteID} ],
        Limit => 1,
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        %Data = (
            ID        => $Row[0],
            CreatedBy => $Row[1],
            ItemID    => $Row[2],
            Interface => $Row[3],
            IP        => $Row[4],
            Created   => $Row[5],
            Rating    => $Row[6],
        );
    }

    return if !%Data;
    return %Data;
}

=item VoteSearch()

returns an array with VoteIDs

    my $VoteIDArrayref = $FAQObject->VoteSearch(
        ItemID => 1,
        UserID => 1,
    );

Returns:

    $VoteIDArrayref = [
        23,
        45,
    ];

=cut

sub VoteSearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ItemID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL => '
            SELECT id
            FROM faq_voting
            WHERE item_id = ?',
        Bind  => [ \$Param{ItemID} ],
        Limit => $Param{Limit} || 500,
    );

    my @VoteIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @VoteIDs, $Row[0];
    }

    return \@VoteIDs;
}

=item ItemVoteDataGet()

Returns a hash reference with the number of votes and the vote result.

    my $VoteDataHashRef = $FAQObject->ItemVoteDataGet(
        ItemID => 123,
        UserID => 1,
    );

Returns:

    $VoteDataHashRef = {
        Result => 3.5,
        Votes  => 5
    };

=cut

sub ItemVoteDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(ItemID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    # check cache
    my $CacheKey = 'ItemVoteDataGet::' . $Param{ItemID};
    my $Cache    = $CacheObject->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    return $Cache if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get vote from db
    return if !$DBObject->Prepare(
        SQL => '
            SELECT count(*), avg(rate)
            FROM faq_voting
            WHERE item_id = ?',
        Bind  => [ \$Param{ItemID} ],
        Limit => $Param{Limit} || 500,
    );

    # fetch the result
    my %Data;
    if ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{Votes}  = $Row[0];
        $Data{Result} = $Row[1];
    }

    # cache result
    $CacheObject->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Data,
        TTL   => $Self->{CacheTTL},
    );

    return \%Data;
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
