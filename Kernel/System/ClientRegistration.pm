# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ClientRegistration;

use strict;
use warnings;

use CGI;
use LWP::UserAgent;
use Time::HiRes;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

use base qw(Kernel::System::AsynchronousExecutor);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
);

=head1 NAME

Kernel::System::ClientRegistration

=head1 SYNOPSIS

Add client registration functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a ClientRegistration object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ClientRegistrationObject = $Kernel::OM->Get('ClientRegistration');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Config');
    $Self->{LogObject}    = $Kernel::OM->Get('Log');

    $Self->{CacheType} = 'ClientRegistration';

    $Self->{DisableClientNotifications} = $Param{DisableClientNotifications};

    $Self->{NotificationCount} = 0;

    return $Self;
}

=item ClientRegistrationGet()

Get a client registration.

    my %Data = $ClientRegistrationObject->ClientRegistrationGet(
        ClientID      => '...',
        Silent        => 1|0       # optional - default 0
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
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => "SELECT client_id, notification_url, notification_authorization, additional_data FROM client_registration WHERE client_id = ?",
        Bind => [ \$Param{ClientID} ],
    );

    my %Data;

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        %Data = (
            ClientID                  => $Row[0],
            NotificationURL           => $Row[1],
            Authorization             => $Row[2],
        );
        if ( $Row[3] ) {
            # prepare additional data
            my $AdditionalData = $Kernel::OM->Get('JSON')->Decode(
                Data => $Row[3]
            );
            if ( IsHashRefWithData($AdditionalData) ) {
                $Data{Plugins}  = $AdditionalData->{Plugins};
                $Data{Requires} = $AdditionalData->{Requires};
            }
        }
    }

    # no data found...
    if ( !%Data ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Registration for client '$Param{ClientID}' not found!",
            );
        }
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

=item ClientRegistrationAdd()

Adds a new client registration

    my $Result = $ClientRegistrationObject->ClientRegistrationAdd(
        ClientID             => 'CLIENT1',
        NotificationURL      => '...',            # optional
        Authorization        => '...',            # optional
        Translations         => '...',            # optional
        Plugins              => [],               # optional
        Requires             => []                # optional
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

    # prepare additional data
    my $AdditionalDataJSON = $Kernel::OM->Get('JSON')->Encode(
        Data => {
            Plugins  => $Param{Plugins},
            Requires => $Param{Requires}
        }
    );

    # do the db insert...
    my $Result = $Kernel::OM->Get('DB')->Do(
        SQL  => "INSERT INTO client_registration (client_id, notification_url, notification_authorization, additional_data) VALUES (?, ?, ?, ?)",
        Bind => [
            \$Param{ClientID},
            \$Param{NotificationURL},
            \$Param{Authorization},
            \$AdditionalDataJSON,
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
    else {
        $Self->{LogObject}->Log(
            Priority => 'info',
            Message  => "Client \"$Param{ClientID}\" registered.",
        );
    }

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    return $Param{ClientID};
}

=item ClientRegistrationList()

Returns an array with all registered ClientIDs

    my @ClientIDs = $ClientRegistrationObject->ClientRegistrationList(
        Notifiable => 0|1           # optional, get only those client that requested to be notified
    );

=cut

sub ClientRegistrationList {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheTTL = 60 * 60 * 24 * 30;   # 30 days
    my $CacheKey = 'ClientRegistrationList::'.($Param{Notifiable} || '');
    my $CacheResult = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );
    return @{$CacheResult} if (IsArrayRefWithData($CacheResult));

    my $SQL = 'SELECT client_id FROM client_registration';

    if ( $Param{Notifiable} ) {
        $SQL .= ' WHERE notification_url IS NOT NULL'
    }

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => $SQL,
    );

    my @Result;
    while ( my @Data = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        push(@Result, $Data[0]);
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \@Result,
        TTL   => $CacheTTL,
    );

    return @Result;
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
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'DELETE FROM client_registration WHERE client_id = ?',
        Bind => [ \$Param{ClientID} ],
    );

    $Self->{LogObject}->Log(
        Priority => 'info',
        Message  => "Client registration for \"$Param{ClientID}\" deleted.",
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    return 1;
}

=item NotifyClients()

This method has been moved to ClientNotification and this is only a fallback

=cut

sub NotifyClients {
    my ( $Self, %Param ) = @_;

    print STDERR "ATTENTION: call to obsolete ClientRegistration::NotifyClients!\n";

    return $Kernel::OM->Get('ClientNotification')->NotifyClients(%Param);
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