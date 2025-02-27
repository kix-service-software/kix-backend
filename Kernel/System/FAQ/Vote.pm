# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::FAQ::Vote;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    ClientRegistration
    Cache
    DB
    Log
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
        Rate      => 1,
        UserID    => 1,
    );

Returns:

    $Success = 1; # or undef if vote could not be added

=cut

sub VoteAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(CreatedBy ItemID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );

            return;
        }
    }

    my $VoteIDs = $Self->VoteSearch(
        ItemID    => $Param{ItemID},
        CreatedBy => $Param{CreatedBy},
        UserID    => $Param{UserID}
    );

    if ( IsArrayRefWithData($VoteIDs) ) {
        for my $VoteID ( @{$VoteIDs} ) {
            $Self->VoteDelete(
                VoteID => $VoteID,
                UserID => $Param{UserID}
            );
        }
    }

    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Do(
        SQL => <<'END',
INSERT INTO faq_voting (created_by, item_id, rate, created )
VALUES ( ?, ?, ?, current_timestamp )
END
        Bind => [
            \$Param{CreatedBy}, \$Param{ItemID}, \$Param{Rate},
        ],
    );

    # get new category id
    return if !$DBObject->Prepare(
        SQL => <<'END',
SELECT id
FROM faq_voting
WHERE created_by = ? AND item_id = ?
END
        Bind  => [
            \$Param{CreatedBy}, \$Param{ItemID}
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
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
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
    return 1 if !%Vote;

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => <<'END',
DELETE FROM faq_voting
WHERE id = ?
END
        Bind => [ \$Param{VoteID} ],
    );

    # clear cache
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
        Namespace => 'FAQ.Article.Vote',
        ObjectID  => $Vote{ItemID} . q{::} . $Param{VoteID},
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
        SQL   => <<'END',
SELECT id, created_by, item_id, created, rate
FROM faq_voting
WHERE id = ?
END
        Bind  => [ \$Param{VoteID} ],
        Limit => 1,
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        %Data = (
            ID        => $Row[0],
            CreatedBy => $Row[1],
            ItemID    => $Row[2],
            Created   => $Row[3],
            Rating    => $Row[4],
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

    my $SQL      = <<'END';
SELECT id
FROM faq_voting
END
    my $SQLWhere = ' WHERE item_id = ?';
    my @Bind;

    push(@Bind, \$Param{ItemID});

    if (
        defined $Param{CreatedBy}
        && $Param{CreatedBy}
    ) {
        $SQLWhere .= ' AND created_by = ?';
        push(@Bind, \$Param{CreatedBy});
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL   => $SQL . $SQLWhere,
        Bind  => \@Bind,
        Limit => $Param{Limit} // 500,
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
        SQL => <<'END',
SELECT count(*), avg(rate)
FROM faq_voting
WHERE item_id = ?
END
        Bind  => [ \$Param{ItemID} ],
        Limit => $Param{Limit} // 500,
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
