# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::ReportResult;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    Cache
    DB
    Log
    User
    Valid
);

=head1 NAME

Kernel::System::Reporting::ReportResult - report extension for reporting lib

=head1 SYNOPSIS

All report result functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ReportResultGet()

returns a hash with the report data

    my %ReportResultData = $ReportingObject->ReportResultGet(
        ID             => 2,
        IncludeContent => 0|1               # default: 0
    );

This returns something like:

    %ReportResultData = (
        'ID'           => 2,
        'ReportID'     => 123,
        'Format'       => 'CSV'
        'ContentType'  => '...',
        'ContentSize'  => '...',
        'Content'      => '...',                        # if parameter "IncludeContent" is 1
        'CreateTime'   => '2010-04-07 15:41:15',
        'CreateBy'     => 1,
    );

=cut

sub ReportResultGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $IncludeContent = $Param{IncludeContent};
    $IncludeContent //= 0;

    # check cache
    my $CacheKey = 'ReportResultGet::' . $Param{ID}.'::'.$IncludeContent;
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    if ( $IncludeContent ) {
        return if !$Kernel::OM->Get('DB')->Prepare(
            SQL   => "SELECT id, report_id, format, content_type, content_size, create_time, create_by, content FROM report_result WHERE id = ?",
            Bind => [ \$Param{ID} ],
        );
    }
    else {
        return if !$Kernel::OM->Get('DB')->Prepare(
            SQL   => "SELECT id, report_id, format, content_type, content_size, create_time, create_by FROM report_result WHERE id = ?",
            Bind => [ \$Param{ID} ],
        );
    }
    my %Result;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Result = (
            ID          => $Row[0],
            ReportID    => $Row[1],
            Format      => $Row[2],
            ContentType => $Row[3],
            ContentSize => $Row[4],
            CreateTime  => $Row[5],
            CreateBy    => $Row[6],
        );

        if ( $IncludeContent ) {
            $Result{Content} = MIME::Base64::decode_base64($Row[7]);
        }
    }

    # no data found...
    if ( !%Result ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Report result with ID $Param{ID} not found!",
        );
        return;
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Result,
    );

    return %Result;
}

=item ReportResultAdd()

add a new report result

    my $ID = $ReportingObject->ReportResultAdd(
        ReportID    => 123
        Format      => 'CSV',
        ContentType => '...',               # optional
        Content     => '...',               # optional
        UserID      => 123,
    );

=cut

sub ReportResultAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ReportID Format UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get the content size and encode content
    my $ContentSize = bytes::length( $Param{Content} );

    my $Content = $Param{Content};
    $Kernel::OM->Get('Encode')->EncodeOutput(\$Content);
    $Content = MIME::Base64::encode_base64($Content);

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO report_result (report_id, format, content_type, content_size, content, create_time, create_by) '
             . 'VALUES (?, ?, ?, ?, ?, current_timestamp, ?)',
        Bind => [
            \$Param{ReportID}, \$Param{Format}, \$Param{ContentType}, \$ContentSize, \$Content, \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM report_result WHERE report_id = ? and format = ? and create_by = ? ORDER BY id',
        Bind => [
            \$Param{ReportID}, \$Param{Format}, \$Param{UserID},
        ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0]
    }

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'ReportResult',
        ObjectID  => $ID,
    );

    return $ID;
}

=item ReportResultList()

returns a list of all ReportResultIDs for a given ReportID

    my @ReportResultIDs = $ReportingObject->ReportResultList(
        ReportID => 123,
    );

=cut

sub ReportResultList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ReportID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # create cache key
    my $CacheKey = 'ReportResultList::' . $Param{ReportID};

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    my $SQL = 'SELECT id FROM report_result WHERE report_id = ? ORDER by id';

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => $SQL,
        Bind => [
            \$Param{ReportID}
        ]
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push @Result, $Row[0];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \@Result,
        TTL   => $Self->{CacheTTL},
    );

    return @Result;
}

=item ReportResultDelete()

deletes a report result

    my $Success = $ReportingObject->ReportResultDelete(
        ID => 123,
    );

=cut

sub ReportResultDelete {
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

    # check if this report exists
    my %ReportResult = $Self->ReportResultGet(
        ID => $Param{ID},
    );
    if ( !%ReportResult ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "A report result with the ID $Param{ID} does not exist.",
        );
        return;
    }

    # delete depending results in database
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM report_result WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'ReportResult',
        ObjectID  => $Param{ID},
    );

    return 1;

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
