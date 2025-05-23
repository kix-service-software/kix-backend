# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PID;

use strict;
use warnings;

use Sys::Hostname;

our @ObjectDependencies = (
    'Config',
    'DB',
    'Log',
);

=head1 NAME

Kernel::System::PID - to manage PIDs

=head1 SYNOPSIS

All functions to manage process ids

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $PIDObject = $Kernel::OM->Get('PID');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get hostname from system
    $Self->{Host} = hostname;

    return $Self;
}

=item PIDCreate()

create a new process id lock

    $PIDObject->PIDCreate(
        Name     => 'PostMasterPOP3',
    );

    or to create a new PID forced, without check if already exists (this will delete any process
    with the same name from any other host)

    $PIDObject->PIDCreate(
        Name  => 'PostMasterPOP3',
        Force => 1,
    );

    or to create a new PID with extra TTL time

    $PIDObject->PIDCreate(
        Name  => 'PostMasterPOP3',
        TTL   => 60 * 60 * 24 * 3, # for 3 days, per default 1h is used
    );

=cut

sub PIDCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name'
        );
        return;
    }

    # check if already exists
    my %ProcessID = $Self->PIDGet(%Param);

    if ( %ProcessID && !$Param{Force} ) {

        my $TTL = $Param{TTL} || 3600;
        if ( $ProcessID{Created} > ( time() - $TTL ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Can't create PID $ProcessID{Name}, because it's already running "
                    . "($ProcessID{Host}/$ProcessID{PID})!",
            );
            return;
        }

        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "Removed PID ($ProcessID{Name}/$ProcessID{Host}/$ProcessID{PID}, "
                . "because 1 hour old!",
        );
    }

    # do nothing if PID is the same
    my $PIDCurrent = $$;
    return 1 if $ProcessID{PID} && $PIDCurrent eq $ProcessID{PID};

    # delete if exists
    $Self->PIDDelete(%Param);

    # add new entry
    my $Time = time();
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => '
            INSERT INTO process_id
            (process_name, process_id, process_host, process_create, process_change)
            VALUES (?, ?, ?, ?, ?)',
        Bind => [ \$Param{Name}, \$PIDCurrent, \$Self->{Host}, \$Time, \$Time ],
    );

    return 1;
}

=item PIDGet()

get process id lock info

    my %PID = $PIDObject->PIDGet(
        Name => 'PostMasterPOP3',
    );

=cut

sub PIDGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name'
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql
    return if !$DBObject->Prepare(
        SQL => '
            SELECT process_name, process_id, process_host, process_create, process_change
            FROM process_id
            WHERE process_name = ?',
        Bind  => [ \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        %Data = (
            PID     => $Row[1],
            Name    => $Row[0],
            Host    => $Row[2],
            Created => $Row[3],
            Changed => $Row[4],
        );
    }

    return %Data;
}

=item PIDDelete()

delete the process id lock

    my $Success = $PIDObject->PIDDelete(
        Name  => 'PostMasterPOP3',
    );

    or to force delete even if the PID is registered by another host
    my $Success = $PIDObject->PIDDelete(
        Name  => 'PostMasterPOP3',
        Force => 1,
    );

=cut

sub PIDDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name'
        );
        return;
    }

    # set basic SQL statement
    my $SQL = '
        DELETE FROM process_id
        WHERE process_name = ?';

    my @Bind = ( \$Param{Name} );

    # delete only processes from this host if Force option was not set
    if ( !$Param{Force} ) {
        $SQL .= '
        AND process_host = ?';

        push @Bind, \$Self->{Host}
    }

    # sql
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    return 1;
}

=item PIDUpdate()

update the process id change time.
this might be useful as a keep alive signal.

    my $Success = $PIDObject->PIDUpdate(
        Name    => 'PostMasterPOP3',
    );

=cut

sub PIDUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Need Name'
            );
        }
        return;
    }

    my %PID = $Self->PIDGet( Name => $Param{Name} );

    if ( !%PID ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Cannot get PID'
            );
        }
        return;
    }

    # sql
    my $Time = time();
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => '
            UPDATE process_id
            SET process_change = ?
            WHERE process_name = ?',
        Bind => [ \$Time, \$Param{Name} ],
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
