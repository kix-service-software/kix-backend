# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Session::UserGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Session::UserGet - API User Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Session::UserGet->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Session::UserGet');

    return $Self;
}

=item Run()

perform UserGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            User => {
                ...
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get the user data
    my %UserData;
    if ( $Self->{Authorization}->{UserType} eq 'Agent' ) {
        %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID        => $Self->{Authorization}->{UserID},
            NoPreferences => 1
        );
    }
    elsif ( $Self->{Authorization}->{UserType} eq 'Customer' ) {
        %UserData = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
            ID            => $Self->{Authorization}->{UserID},
            NoPreferences => 1
        );
    }

    if ( !IsHashRefWithData( \%UserData ) ) {

        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # filter valid attributes
    if ( IsHashRefWithData( $Self->{Config}->{AttributeWhitelist} ) ) {
        foreach my $Attr ( sort keys %UserData ) {
            delete $UserData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
        }
    }

    # filter valid attributes
    if ( IsHashRefWithData( $Self->{Config}->{AttributeBlacklist} ) ) {
        foreach my $Attr ( sort keys %UserData ) {
            delete $UserData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
        }
    }

    if ( $Self->{Authorization}->{UserType} eq 'Agent' ) {

        # include preferences if requested - we can't do that with our generic sub-resource include function, because we don't have a UserID in our request
        if ( $Param{Data}->{include}->{Preferences} ) {

            # get already prepared preferences data from UserPreferenceSearch operation
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::Session::UserPreferenceSearch',
                Data          => {}
            );
            if ( IsHashRefWithData($Result) && $Result->{Success} ) {
                $UserData{Preferences} = $Result->{Data}->{UserPreference};
            }
        }

        # include tickets if requested
        if ( $Param{Data}->{include}->{Tickets} ) {
            my @TicketIDs;

            # get tickets owned by user
            my $Tickets = $Self->_GetOwnedTickets();
            $UserData{Tickets}->{Owned}          = $Tickets->{All};
            $UserData{Tickets}->{OwnedAndUnseen} = $Tickets->{Unseen};

            # get tickets owned by user and locked
            $Tickets                                      = $Self->_GetOwnedAndLockedTickets();
            $UserData{Tickets}->{OwnedAndLocked}          = $Tickets->{All};
            $UserData{Tickets}->{OwnedAndLockedAndUnseen} = $Tickets->{Unseen};

            # get tickets watched by user
            $Tickets                               = $Self->_GetWatchedTickets();
            $UserData{Tickets}->{Watched}          = $Tickets->{All};
            $UserData{Tickets}->{WatchedAndUnseen} = $Tickets->{Unseen};

            # inform API caching about a new dependency
            $Self->AddCacheDependency( Type => 'Ticket' );
        }

        # include roleids if requested
        if ( $Param{Data}->{include}->{RoleIDs} ) {

            # get roles list
            my @RoleList = $Kernel::OM->Get('Kernel::System::User')->RoleList(
                UserID => $Self->{Authorization}->{UserID},
            );
            my @RoleIDs;
            foreach my $RoleID ( sort @RoleList ) {
                push( @RoleIDs, 0 + $RoleID );    # enforce nummeric ID
            }
            $UserData{RoleIDs} = \@RoleIDs;
        }
    }

    return $Self->_Success(
        User => \%UserData,
    );
}

sub _GetOwnedTickets {
    my ( $Self, %Param ) = @_;
    my %Tickets;

    # execute ticket search
    my @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
        Search => {
            AND => [
                {
                    Field    => 'OwnerID',
                    Operator => 'EQ',
                    Value    => $Self->{Authorization}->{UserID},
                },
                ]
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );
    $Tickets{All} = \@TicketIDs;

    # execute ticket search
    my @SeenTicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
        Search => {
            AND => [
                {
                    Field    => 'OwnerID',
                    Operator => 'EQ',
                    Value    => $Self->{Authorization}->{UserID},
                },
                {
                    Field    => 'TicketFlag',
                    Operator => 'EQ',
                    Value    => [
                        {
                            Flag   => 'Seen',
                            Value  => '1',
                            UserID => $Self->{Authorization}->{UserID},
                        }
                        ]
                },
                ]
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );

    # extract all unseen tickets
    my @UnseenTicketIDs;
    foreach my $TicketID (@TicketIDs) {
        next if grep( /^$TicketID$/, @SeenTicketIDs );
        push( @UnseenTicketIDs, $TicketID );
    }
    $Tickets{Unseen} = \@UnseenTicketIDs;

    return \%Tickets;
}

sub _GetOwnedAndLockedTickets {
    my ( $Self, %Param ) = @_;
    my %Tickets;

    # execute ticket search
    my @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
        Search => {
            AND => [
                {
                    Field    => 'OwnerID',
                    Operator => 'EQ',
                    Value    => $Self->{Authorization}->{UserID},
                },
                {
                    Field    => 'LockID',
                    Operator => 'EQ',
                    Value    => 2,
                },
                ]
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );
    $Tickets{All} = \@TicketIDs;

    # execute ticket search
    my @SeenTicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
        Search => {
            AND => [
                {
                    Field    => 'OwnerID',
                    Operator => 'EQ',
                    Value    => $Self->{Authorization}->{UserID},
                },
                {
                    Field    => 'LockID',
                    Operator => 'EQ',
                    Value    => 2,
                },
                {
                    Field    => 'TicketFlag',
                    Operator => 'EQ',
                    Value    => [
                        {
                            Flag   => 'Seen',
                            Value  => '1',
                            UserID => $Self->{Authorization}->{UserID},
                        }
                        ]
                },
                ]
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );

    # extract all unseen tickets
    my @UnseenTicketIDs;
    foreach my $TicketID (@TicketIDs) {
        next if grep( /^$TicketID$/, @SeenTicketIDs );
        push( @UnseenTicketIDs, $TicketID );
    }
    $Tickets{Unseen} = \@UnseenTicketIDs;

    return \%Tickets;
}

sub _GetWatchedTickets {
    my ( $Self, %Param ) = @_;
    my %Tickets;

    # execute ticket search
    my @TicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
        Search => {
            AND => [
                {
                    Field    => 'WatcherUserID',
                    Operator => 'EQ',
                    Value    => $Self->{Authorization}->{UserID},
                },
                ]
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );
    $Tickets{All} = \@TicketIDs;

    # execute ticket search
    my @SeenTicketIDs = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSearch(
        Search => {
            AND => [
                {
                    Field    => 'WatcherUserID',
                    Operator => 'EQ',
                    Value    => $Self->{Authorization}->{UserID},
                },
                {
                    Field    => 'TicketFlag',
                    Operator => 'EQ',
                    Value    => [
                        {
                            Flag   => 'Seen',
                            Value  => '1',
                            UserID => $Self->{Authorization}->{UserID},
                        }
                        ]
                },
                ]
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );

    # extract all unseen tickets
    my @UnseenTicketIDs;
    foreach my $TicketID (@TicketIDs) {
        next if grep( /^$TicketID$/, @SeenTicketIDs );
        push( @UnseenTicketIDs, $TicketID );
    }
    $Tickets{Unseen} = \@UnseenTicketIDs;

    return \%Tickets;
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
