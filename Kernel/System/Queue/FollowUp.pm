# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Queue::FollowUp;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Queue::FollowUp - follow up extension for roles lib

=head1 SYNOPSIS

All role functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item FollowUpTypeList()

returns a list of followup types.

    %FollowUpTypeList = $QueueObject->FollowUpTypeList(
        Valid => 1          # optional
    );

=cut

sub FollowUpTypeList {
    my ( $Self, %Param ) = @_;

    # set default value
    my $Valid = $Param{Valid} ? 1 : 0;

    # create cache key
    my $CacheKey = 'FollowUpTypeList::' . $Valid;

    # read cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SQL = 'SELECT id, name FROM follow_up_possible';

    if ( $Param{Valid} ) {
        $SQL .= ' WHERE valid_id = 1'
    }

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare( 
        SQL => $SQL,
    );

    my %Result;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Result{$Row[0]} = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Result,
        TTL   => $Self->{CacheTTL},
    );

    return %Result;
}

=item FollowUpTypeGet()

returns the requested followup type.

    %FollowUpType = $QueueObject->FollowUpTypeGet(
        ID => 1
    );

This returns something like:

    %FollowUpType = (
        'ID'         => 2,
        'Name'       => '...',
        'Comment'    => '...',
        'ValidID'    => '1',
        'CreateTime' => '2010-04-07 15:41:15',
        'CreateBy'   => 1,
        'ChangeTime' => '2010-04-07 15:41:15',
        'ChangeBy'   => 1
    );

=cut

sub FollowUpTypeGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'FollowUpTypeGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;
    
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare( 
        SQL   => "SELECT id, name, comments, valid_id, create_time, create_by, change_time, change_by FROM follow_up_possible WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;
    
    # fetch the result
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        %Result = (
            ID         => $Row[0],
            Name       => $Row[1],
            Comment    => $Row[2],
            ValidID    => $Row[3],
            CreateTime => $Row[4],
            CreateBy   => $Row[5],
            ChangeTime => $Row[6],
            ChangeBy   => $Row[7],
        );
    }
    
    # no data found...
    if ( !%Result ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "FollowUpType with ID $Param{ID} not found!",
        );
        return;
    }
    
    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Result,
    ); 

    return %Result;
}

=item GetFollowUpOption()

get FollowUpOption for the given QueueID

    my $FollowUpOption = $QueueObject->GetFollowUpOption( QueueID => $QueueID );

returns any of 'possible', 'reject', 'new ticket'.

=cut

sub GetFollowUpOption {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{QueueID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need QueueID!'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # fetch queues data
    return if !$DBObject->Prepare(
        SQL => 'SELECT sf.name FROM follow_up_possible sf, queue sq '
            . ' WHERE sq.follow_up_id = sf.id AND sq.id = ?',
        Bind  => [ \$Param{QueueID} ],
        Limit => 1,
    );

    my $Return = '';
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Return = $Row[0];
    }

    return $Return;
}

=item GetFollowUpLockOption()

get FollowUpLockOption for the given QueueID

    my $FollowUpLockOption = $QueueObject->GetFollowUpLockOption( QueueID => $QueueID );

returns '1' if ticket should be locked after a follow up, '0' if not.

=cut

sub GetFollowUpLockOption {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{QueueID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need QueueID!'
        );
        return;
    }

    # get (already cached) queue data
    my %Queue = $Self->QueueGet(
        ID => $Param{QueueID},
    );

    return if !%Queue;
    return $Queue{FollowUpLock};
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
