# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2024 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. This program is
# licensed under the AGPL-3.0 with code licensed under the GPL-3.0.
# For details, see the enclosed files LICENSE (AGPL) and
# LICENSE-GPL3 (GPL3) for license information. If you did not receive
# this files, see https://www.gnu.org/licenses/agpl.txt (APGL) and
# https://www.gnu.org/licenses/gpl-3.0.txt (GPL3).
# --

package Kernel::System::MailAccount;

use strict;
use warnings;

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    DB
    Log
    Main
    Queue
    Valid
);

=head1 NAME

Kernel::System::MailAccount - to manage mail accounts

=head1 SYNOPSIS

All functions to manage the mail accounts.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $MailAccountObject = $Kernel::OM->Get('MailAccount');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item MailAccountAdd()

adds a new mail account

    $MailAccount->MailAccountAdd(
        Login         => 'mail',
        Password      => 'SomePassword',
        Host          => 'pop3.example.com',
        Type          => 'POP3',
        IMAPFolder    => 'Some Folder', # optional, only valid for IMAP-type accounts
        ValidID       => 1,
        Trusted       => 0,
        DispatchingBy => 'Queue', # PostmasterDefaultQueue|From|Queue
        QueueID       => 12,
        UserID        => 123,
### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
        OAuth2_ProfileID => 'Custom1',
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
    );

=cut

sub MailAccountAdd {
    my ( $Self, %Param ) = @_;

### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
    if ( $Param{Type} && $Param{Type} =~ m/_OAuth2$/xmsi ) {
        if ( !$Param{OAuth2_ProfileID} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need Profile for OAuth2!"
            );
            return;
        }
        $Param{Password} = '-';
    }
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
    else {
        # set value to undef/NULL to prevent database errors
        $Param{OAuth2_ProfileID} = undef;
    }

    # check needed stuff
    for (qw(Login Password Host Type DispatchingBy ValidID Trusted UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "$_ not defined!"
            );
            return;
        }
    }
    for (qw(Login Password Host Type DispatchingBy ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if dispatching is by From
    if ( $Param{DispatchingBy} eq 'From' ) {
        $Param{QueueID} = 0;
    }
    # check if dispatching is by PostmasterDefaultQueue
    elsif ( $Param{DispatchingBy} eq 'PostmasterDefaultQueue' ) {
        $Param{QueueID} = -1;
    }
    elsif ( $Param{DispatchingBy} eq 'Queue' && !$Param{QueueID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need QueueID for dispatching!"
        );
        return;
    }
    elsif ( $Param{DispatchingBy} ne 'Queue' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Invalid value '$Param{DispatchingBy}' for DispatchingBy!"
        );
        return;
    }

    # only set IMAP folder on IMAP type accounts
    # fallback to 'INBOX' if none given
    if ( $Param{Type} =~ m{ IMAP .* }xmsi ) {
        if ( !defined $Param{IMAPFolder} || !$Param{IMAPFolder} ) {
            $Param{IMAPFolder} = 'INBOX';
        }
    }
    else {
        $Param{IMAPFolder} = '';
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql
    return if !$DBObject->Do(
        SQL =>
            'INSERT INTO mail_account (login, pw, host, account_type, valid_id, comments, queue_id, '
### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
#            . ' imap_folder, trusted, create_time, create_by, change_time, change_by)'
#            . ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
            . ' imap_folder, oauth2_profile_id, trusted, create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
        Bind => [
            \$Param{Login},   \$Param{Password}, \$Param{Host},    \$Param{Type},
            \$Param{ValidID}, \$Param{Comment},  \$Param{QueueID}, \$Param{IMAPFolder},
### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
#            \$Param{Trusted}, \$Param{UserID},   \$Param{UserID},
            \$Param{OAuth2_ProfileID}, \$Param{Trusted}, \$Param{UserID},   \$Param{UserID},
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
        ],
    );

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM mail_account WHERE login = ? AND host = ? AND account_type = ?',
        Bind => [ \$Param{Login}, \$Param{Host}, \$Param{Type} ],
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'MailAccount',
        ObjectID  => $ID,
    );

    return $ID;
}

=item MailAccountGet()

returns a hash of mail account data

    my %MailAccount = $MailAccount->MailAccountGet(
        ID => 123,
    );

### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
#(returns: ID, Login, Password, Host, Type, QueueID, Trusted, IMAPFolder, Comment, DispatchingBy, ValidID)
(returns: ID, Login, Password, Host, Type, QueueID, Trusted, IMAPFolder, OAuth2_Profile, Comment, DispatchingBy, ValidID)
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###

=cut

sub MailAccountGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ID!"
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql
    return if !$DBObject->Prepare(
        SQL =>
            'SELECT login, pw, host, account_type, queue_id, imap_folder, trusted, comments, valid_id, '
### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
#            . ' create_by, create_time, change_by, change_time FROM mail_account WHERE id = ?',
            . ' create_by, create_time, change_by, change_time, oauth2_profile_id FROM mail_account WHERE id = ?',
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
        Bind => [ \$Param{ID} ],
    );

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Data = (
            ID         => $Param{ID},
            Login      => $Data[0],
            Password   => $Data[1],
            Host       => $Data[2],
            Type       => $Data[3] || 'POP3',    # compat for old setups
            QueueID    => $Data[4],
            IMAPFolder => $Data[5],
            Trusted    => $Data[6],
            Comment    => $Data[7],
            ValidID    => $Data[8],
            CreateBy   => $Data[9],
            CreateTime => $Data[10],
            ChangeBy   => $Data[11],
            ChangeTime => $Data[12],
### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
            OAuth2_ProfileID => $Data[13],
### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
        );
    }
    if ( $Data{ID} ) {

        if ( $Data{QueueID} == 0 ) {
            $Data{DispatchingBy} = 'From';
            $Data{QueueID}       = undef;
        }
        elsif ( $Data{QueueID} == -1 ) {
            $Data{DispatchingBy} = 'PostmasterDefaultQueue';
            $Data{QueueID}       = undef;
        }
        else {
            $Data{DispatchingBy} = 'Queue';
        }

        # only return IMAP folder on IMAP type accounts
        # fallback to 'INBOX' if none given
        if ( $Data{Type} =~ m{ IMAP .* }xmsi ) {
            if ( defined $Data{IMAPFolder} && !$Data{IMAPFolder} ) {
                $Data{IMAPFolder} = 'INBOX';
            }
        }
        else {
            $Data{IMAPFolder} = '';
        }
    }
    return %Data;
}

=item MailAccountUpdate()

update a new mail account

    $MailAccount->MailAccountUpdate(
        ID            => 1,
        Login         => 'mail',
        Password      => 'SomePassword',
        Host          => 'pop3.example.com',
        Type          => 'POP3',
        IMAPFolder    => 'Some Folder', # optional, only valid for IMAP-type accounts
        ValidID       => 1,
        Trusted       => 0,
        DispatchingBy => 'Queue', # PostmasterDefaultQueue|From|Queue
        QueueID       => 12,
        UserID        => 123,
### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
        OAuth2_ProfileID => 'Custom1',
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
    );

=cut

sub MailAccountUpdate {
    my ( $Self, %Param ) = @_;

### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
    if ( $Param{Type} && $Param{Type} =~ m/_OAuth2$/xmsi ) {
        if ( !$Param{OAuth2_ProfileID} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need Profile for OAuth2!"
            );
            return;
        }
        $Param{Password} = '-';
    }
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
    else {
        # set value to undef/NULL to prevent database errors
        $Param{OAuth2_ProfileID} = undef;
    }

    # check needed stuff
    for (qw(ID Login Password Host Type DispatchingBy ValidID Trusted UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "$_ not defined!"
            );
            return;
        }
    }

    for (qw(ID Login Password Host Type DispatchingBy ValidID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if dispatching is by From
    if ( $Param{DispatchingBy} eq 'From' ) {
        $Param{QueueID} = 0;
    }
    # check if dispatching is by PostmasterDefaultQueue
    elsif ( $Param{DispatchingBy} eq 'PostmasterDefaultQueue' ) {
        $Param{QueueID} = -1;
    }
    elsif ( $Param{DispatchingBy} eq 'Queue' && !$Param{QueueID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need QueueID for dispatching!"
        );
        return;
    }
    elsif ( $Param{DispatchingBy} ne 'Queue' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Invalid value '$Param{DispatchingBy}' for DispatchingBy!"
        );
        return;
    }

    # only set IMAP folder on IMAP type accounts
    # fallback to 'INBOX' if none given
    if ( $Param{Type} =~ m{ IMAP .* }xmsi ) {
        if ( !defined $Param{IMAPFolder} || !$Param{IMAPFolder} ) {
            $Param{IMAPFolder} = 'INBOX';
        }
    }
    else {
        $Param{IMAPFolder} = '';
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE mail_account SET login = ?, pw = ?, host = ?, account_type = ?, '
            . ' comments = ?, imap_folder = ?, trusted = ?, valid_id = ?, change_time = current_timestamp, '
### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
#            . ' change_by = ?, queue_id = ? WHERE id = ?',
            . ' oauth2_profile_id = ?, change_by = ?, queue_id = ? WHERE id = ?',
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
        Bind => [
            \$Param{Login},   \$Param{Password},   \$Param{Host},    \$Param{Type},
            \$Param{Comment}, \$Param{IMAPFolder}, \$Param{Trusted}, \$Param{ValidID},
### Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
#            \$Param{UserID},  \$Param{QueueID},    \$Param{ID},
            \$Param{OAuth2_ProfileID}, \$Param{UserID},  \$Param{QueueID},    \$Param{ID},
### EO Code licensed under the GPL-3.0, Copyright (C) 2019-2024 Rother OSS GmbH, https://otobo.de/ ###
        ],
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'MailAccount',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item MailAccountDelete()

deletes a mail account

    $MailAccount->MailAccountDelete(
        ID => 123,
    );

=cut

sub MailAccountDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need ID!"
        );
        return;
    }

    # sql
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM mail_account WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'MailAccount',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item MailAccountList()

returns a list (Key, Name) of all mail accounts

    my %List = $MailAccount->MailAccountList(
        Valid => 0, # just valid/all accounts
    );

=cut

sub MailAccountList {
    my ( $Self, %Param ) = @_;

    # get valid object
    my $ValidObject = $Kernel::OM->Get('Valid');

    my $Where = $Param{Valid}
        ? 'WHERE valid_id IN ( ' . join ', ', $ValidObject->ValidIDsGet() . ' )'
        : '';

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare(
        SQL => "SELECT id, host, login FROM mail_account $Where",
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = "$Row[1] ($Row[2])";
    }

    return %Data;
}

=item MailAccountBackendList()

returns a list of usable backends

    my %List = $MailAccount->MailAccountBackendList();

=cut

sub MailAccountBackendList {
    my ( $Self, %Param ) = @_;

    my $Directory = $Kernel::OM->Get('Config')->Get('Home') . '/Kernel/System/MailAccount/';

    my @List = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => $Directory,
        Filter    => '*.pm',
    );

    my %Backends;
    for my $File (@List) {

        # remove .pm
        $File =~ s/^.*\/(.+?)\.pm$/$1/;
        my $GenericModule = "Kernel::System::MailAccount::$File";

        # try to load module $GenericModule
        if ( $Kernel::OM->Get('Main')->Require($GenericModule) ) {
            if ( eval { $GenericModule->new() } ) {
                $Backends{$File} = $File;
            }
        }
    }

    return %Backends;
}

=item MailAccountFetch()

fetch emails by using backend

    my $Ok = $MailAccount->MailAccountFetch(
        Login         => 'mail',
        Password      => 'SomePassword',
        Host          => 'pop3.example.com',
        Type          => 'POP3', # POP3,POP3s,IMAP,IMAPS
        Trusted       => 0,
        DispatchingBy => 'Queue', # PostmasterDefaultQueue|From|Queue
        QueueID       => 12,
        UserID        => 123,
    );

=cut

sub MailAccountFetch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Login Password Host Type Trusted DispatchingBy UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # dispatching to configured default queue
    if ( $Param{DispatchingBy} eq 'PostmasterDefaultQueue' ) {
        # get configured default queue name
        my $DefaultQueueName = $Kernel::OM->Get('Config')->Get('PostmasterDefaultQueue');

        # overwrite queue id parameter by lookup
        $Param{QueueID} = $Kernel::OM->Get('Queue')->QueueLookup(
            Queue => $DefaultQueueName
        );
    }
    # when dispatiching be queue is configured, check for given queue
    elsif ( $Param{DispatchingBy} eq 'Queue' && !$Param{QueueID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need QueueID for dispatching!"
        );
        return;
    }

    my $PostMasterDebug = $Kernel::OM->Get('Config')->Get('PostMaster::MailAccountFetch::Debug');

    # set post master debug if no active debug given
    if (
        $PostMasterDebug
        && !$Param{Debug}
    ) {
        $Param{Debug} = $PostMasterDebug;
    }

    # load backend
    my $GenericModule = "Kernel::System::MailAccount::$Param{Type}";

    # try to load module $GenericModule
    if ( !$Kernel::OM->Get('Main')->Require($GenericModule) ) {
        return;
    }

    # fetch mails
    my $Backend = $GenericModule->new();

    return $Backend->Fetch(%Param);
}

=item MailAccountCheck()

Check inbound mail configuration

    my %Check = $MailAccount->MailAccountCheck(
        ID            => '1',
        Login         => 'mail',
        Password      => 'SomePassword',
        Host          => 'pop3.example.com',
        Type          => 'POP3', # POP3|POP3S|IMAP|IMAPS
        Timeout       => '60',
        Debug         => '0',
    );

=cut

sub MailAccountCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Login Password Host Type Timeout Debug)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # load backend
    my $GenericModule = "Kernel::System::MailAccount::$Param{Type}";

    # try to load module $GenericModule
    if ( !$Kernel::OM->Get('Main')->Require($GenericModule) ) {
        return;
    }

    # check if connect is successful
    my $Backend = $GenericModule->new();
    my %Check   = $Backend->Connect(%Param);

    if ( $Check{Successful} ) {
        return ( Successful => 1 );
    }
    else {
        return (
            Successful => 0,
            Message    => $Check{Message}
        );
    }
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. This program is
licensed under the AGPL-3.0 with code licensed under the GPL-3.0.
For details, see the enclosed files LICENSE (AGPL) and
LICENSE-GPL3 (GPL3) for license information. If you did not receive
this files, see <https://www.gnu.org/licenses/agpl.txt> (APGL) and
<https://www.gnu.org/licenses/gpl-3.0.txt> (GPL3).

=cut
