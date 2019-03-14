# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ClientRegistration;

use strict;
use warnings;

use LWP::UserAgent;
use Time::HiRes qw(gettimeofday);

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CacheInternal',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::ClientRegistration

=head1 SYNOPSIS

Add address book functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a ClientRegistration object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ClientRegistrationObject = $Kernel::OM->Get('Kernel::System::ClientRegistration');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{DBObject}     = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');

    $Self->{CacheType} = 'ClientRegistration';
    
    return $Self;
}

=item ClientRegistrationGet()

Get a client registration.

    my %Data = $ClientRegistrationObject->ClientRegistrationGet(
        ClientID      => '...',
    );

=cut

sub ClientRegistrationGet {
    my ( $Self, %Param ) = @_;
    
    my %Result;

    # check required params...
    if ( !$Param{ClientID} ) {
        $Self->{LogObject}->Log( 
            Priority => 'error', 
            Message  => 'Need ClientID!' 
        );
        return;
    }
   
    # check cache
    my $CacheKey = 'ClientRegistrationGet::' . $Param{ClientID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;
    
    return if !$Self->{DBObject}->Prepare( 
        SQL   => "SELECT client_id, notification_url, notification_interval, notification_authorization, last_notification_timestamp FROM client_registration WHERE client_id = ?",
        Bind => [ \$Param{ClientID} ],
    );

    my %Data;
    
    # fetch the result
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        %Data = (
            ClientID             => $Row[0],
            NotificationURL      => $Row[1],
            NotificationInterval => $Row[2],
            Authorization       => $Row[3],
            LastNotificationTimestamp => $Row[4],
        );
    }
    
    # no data found...
    if ( !%Data ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Registration for client '$Param{ClientID}' not found!",
        );
        return;
    }
    
    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    ); 
       
    return %Data;   

}

=item ClientRegistrationAdd()

Adds a new client registration

    my $Result = $ClientRegistrationObject->ClientRegistrationAdd(
        ClientID             => 'CLIENT1',
        NotificationURL      => '...',            # optional
        NotificationInterval => 123,              # optional, in seconds
        Authorization       => '...',             # optional
        Translations         => '...',            # optional
    );

=cut

sub ClientRegistrationAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ClientID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # init the last notification timestamp to define a base to start from
    my $Now = ($Param{NotificationURL} && $Param{NotificationInterval}) ? gettimeofday() : undef;

    # do the db insert...
    my $Result = $Self->{DBObject}->Do(
        SQL  => "INSERT INTO client_registration (client_id, notification_url, notification_interval, notification_authorization, last_notification_timestamp) VALUES (?, ?, ?, ?, ?)",
        Bind => [
            \$Param{ClientID},
            \$Param{NotificationURL},
            \$Param{NotificationInterval},
            \$Param{Authorization},
            \$Now,
        ],
    );

    # handle the insert result...
    if ( !$Result ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "DB insert failed!",
        );

        return;
    }

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType});

    # schedule notification task if requested by client
    if ( $Param{NotificationURL} && $Param{NotificationInterval} ) {
        my $Result = $Self->ScheduleNotificationTask(
            ClientID => $Param{ClientID},
        );
        return if !$Result;
    }

    return $Param{ClientID};
}

=item ClientRegistrationList()

Returns a ArrayRef with all registered ClientIDs

    my $ClientIDs = $ClientRegistrationObject->ClientRegistrationList(
        Notifiable => 0|1           # optional, get only those client that requested to be notified
    );

=cut

sub ClientRegistrationList {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheTTL = 60 * 60 * 24 * 30;   # 30 days
    my $CacheKey = 'ClientRegistrationList::'.($Param{Notifiable} || '');
    my $CacheResult = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );
    return $CacheResult if (IsArrayRefWithData($CacheResult));
  
    my $SQL = 'SELECT client_id FROM client_registration';

    if ( $Param{Notifiable} ) {
        $SQL .= ' WHERE notification_url IS NOT NULL and notification_interval IS NOT NULL'
    }

    return if !$Self->{DBObject}->Prepare( 
        SQL => $SQL,
    );

    my @Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push(@Result, $Data[0]);
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type           => $Self->{CacheType},
        Key            => $CacheKey,
        Value          => \@Result,
        TTL            => $CacheTTL,
    );

    return \@Result;
}

=item ClientRegistrationDelete()

Delete a client registration.

    my $Result = $ClientRegistrationObject->ClientRegistrationDelete(
        ClientID      => '...',
    );

=cut

sub ClientRegistrationDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ClientID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => 'DELETE FROM client_registration WHERE client_id = ?',
        Bind => [ \$Param{ClientID} ],
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    return 1;
}

=item NotifyClients()

Pushes a notification event to inform the clients

    my $Result = $ClientRegistrationObject->NotifyClients();

=cut

sub NotifyClients {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Event Object ObjectID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Timestamp = gettimeofday();

    # do the db insert...
    my $Result = $Self->{DBObject}->Do(
        SQL  => "INSERT INTO client_notification (timestamp, event, object, object_id) VALUES (?, ?, ?, ?)",
        Bind => [
            \$Timestamp,
            \$Param{Event},
            \$Param{Object},
            \$Param{ObjectID},
        ],
    );

    # handle the insert result...
    if ( !$Result ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "DB insert failed!",
        );

        return;
    }    

    return 1;    
}

=item NotificationCleanup()

Cleans up old client notifications

    my $Result = $ClientRegistrationObject->NotificationCleanup(
        MaxAge => 123       # required, delete all entries older than minutes
    );

=cut

sub NotificationCleanup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(MaxAge)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Threshold = $Param{MaxAge} * 60;

    # do the db delete...
    my $Result = $Self->{DBObject}->Do(
        SQL  => "DELETE FROM client_notification WHERE timestamp < timestamp - ?",
        Bind => [
            \$Threshold
        ],
    );

    # handle the delete result...
    if ( !$Result ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "DB delete failed!",
        );

        return;
    }    

    return 1;    
}

=item NotificationSend()

send notifications to client

    my $Result = $ClientRegistrationObject->NotificationSend(
        ClientID => 'CLIENT1',
    );

=cut

sub NotificationSend {
    my ( $Self, %Param ) = @_;

    # get registration for client
    my %ClientRegistration = $Self->ClientRegistrationGet(
        ClientID => $Param{ClientID}
    );
    
    # save current timestamp as new start point
    my $Timestamp = gettimeofday();

    return if !$Self->{DBObject}->Prepare( 
        SQL   => "SELECT timestamp, event, object, object_id FROM client_notification WHERE timestamp > ?",
        Bind  => [
            \$ClientRegistration{LastNotificationTimestamp}
        ]
    );

    my @EventList;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        my %Event;

        $Event{Timestamp} = $Row[0];
        $Event{Event}     = $Row[1];
        $Event{Object}    = $Row[2];
        $Event{ObjectID}  = $Row[3];

        push(@EventList, \%Event);
    }

    # only communication with client if we have something to tell
    if ( @EventList ) {
        my %Stats;
        foreach my $Event ( @EventList ) {
            $Stats{lc($Event->{Event})}++;        
        }
        my @StatsParts;
        foreach my $Event ( sort keys %Stats ) {
            push(@StatsParts, "$Stats{$Event} $Event".'s');
        }

        $Self->{LogObject}->Log( 
            Priority => 'info', 
            Message  => "Sending ". @EventList . " notifications to client \"$Param{ClientID}\" (" . (join(', ', @StatsParts)) . ').' 
        );

        my $UserAgent = LWP::UserAgent->new();

        # set user agent
        $UserAgent->agent(
            $Kernel::OM->Get('Kernel::Config')->Get('Product') . ' ' . $Kernel::OM->Get('Kernel::Config')->Get('Version')
        );
    
        # set timeout
        $UserAgent->timeout( $Kernel::OM->Get('Kernel::System::WebUserAgent')->{Timeout} );

        # disable SSL host verification
        if ( $Kernel::OM->Get('Kernel::Config')->Get('WebUserAgent::DisableSSLVerification') ) {
            $UserAgent->ssl_opts(
                verify_hostname => 0,
            );
        }

        # set proxy
        if ( $Kernel::OM->Get('Kernel::System::WebUserAgent')->{Proxy} ) {
            $UserAgent->proxy( [ 'http', 'https', 'ftp' ], $Kernel::OM->Get('Kernel::System::WebUserAgent')->{Proxy} );
        }

        my $Request = HTTP::Request->new('POST', $ClientRegistration{NotificationURL});
        $Request->header('Content-Type' => 'application/json'); 
        if ( $ClientRegistration{Authorization} ) {
            $Request->header('Authorization' => $ClientRegistration{Authorization});
        }
        my $JSON = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
            Data => \@EventList,
        );
        $Request->content($JSON);
        my $Response = $UserAgent->request($Request);

        if ( !$Response->is_success ) {
            # something went wrong
            return;
        }

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'info',
            Message  => "Client \"$Param{ClientID}\" responded ".$Response->status_line.".",
        );
    }

    # update client registration
    my $Result = $Self->{DBObject}->Do(
        SQL  => "UPDATE client_registration SET last_notification_timestamp = ? WHERE client_id = ?",
        Bind => [
            \$Timestamp,
            \$Param{ClientID},
        ],
    );

    # schedule new task if the scheduler executed this method
    if ( $Param{IsScheduler} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'info',
            Message  => "Rescheduling notification task for client \"$Param{ClientID}\".",
        );
        my $Result = $Self->ScheduleNotificationTask(
            ClientID => $Param{ClientID},
        );
    }

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    return 1;    
}

=item ScheduleNotificationTask()

Schedule a client notification task.

    my $Result = $ClientRegistrationObject->ScheduleNotificationTask(
        ClientID => 'CLIENT1',
    );

=cut

sub ScheduleNotificationTask {
    my ($Self, %Param) = @_;

    # check needed stuff
    for (qw(ClientID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %ClientRegistration = $Self->ClientRegistrationGet(
        ClientID => $Param{ClientID}
    );

    # Calculate execution time in future.
    my $ExecutionTime = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2TimeStamp(
        SystemTime => $Kernel::OM->Get('Kernel::System::Time')->SystemTime() + $ClientRegistration{NotificationInterval},
    );

    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'info',
        Message  => "Scheduling periodic notification task for client \"$Param{ClientID}\" with an interval of $ClientRegistration{NotificationInterval} seconds.",
    );

    # Create a new future task.
    my $TaskID = $Kernel::OM->Get('Kernel::System::Daemon::SchedulerDB')->FutureTaskAdd(
        ExecutionTime => $ExecutionTime,
        Type          => 'AsynchronousExecutor',
        Name          => 'client notification for '.$Param{ClientID},
        Attempts      => 1,
        Data          => {
            Object   => 'Kernel::System::ClientRegistration',
            Function => 'NotificationSend',
            Params   => {
                ClientID    => $Param{ClientID},
                IsScheduler => 1
            },
        }
    );

    if ( !$TaskID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not schedule a task for periodic notification of client \"$Param{ClientID}\".",
        );
        return;
    }

    $Kernel::OM->Get('Kernel::System::Log')->Log(
        Priority => 'info',
        Message  => "Notification task for client \"$Param{ClientID}\" scheduled.",
    );

    return 1;
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
