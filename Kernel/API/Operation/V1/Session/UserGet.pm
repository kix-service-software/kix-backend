# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Session::UserGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

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
    %UserData = $Kernel::OM->Get('User')->GetUserData(
        UserID        => $Self->{Authorization}->{UserID},
        NoPreferences => 1
    );

    if ( !IsHashRefWithData(\%UserData) ) {

        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # filter valid attributes
    if ( IsHashRefWithData($Self->{Config}->{AttributeWhitelist}) ) {
        foreach my $Attr ( sort keys %UserData ) {
            delete $UserData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
        }
    }

    # filter valid attributes
    if ( IsHashRefWithData($Self->{Config}->{AttributeBlacklist}) ) {
        foreach my $Attr ( sort keys %UserData ) {
            delete $UserData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
        }
    }

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

        my $TicketFilter;
        if ( $Param{Data}->{'Tickets.StateType'} ) {
            $TicketFilter = {
                Field    => 'StateType',
                Operator => 'IN',
                Value    => [split(/,/, $Param{Data}->{'Tickets.StateType'})],
            };
        }
        elsif ( $Param{Data}->{'Tickets.StateID'} ) {
            $TicketFilter = {
                Field    => 'StateID',
                Operator => 'IN',
                Value    => [split(/,/, $Param{Data}->{'Tickets.StateID'})],
            };
        }

        # get tickets owned by user
        my $Tickets = $Self->_GetOwnedTickets(TicketFilter => $TicketFilter);
        $UserData{Tickets}->{Owned} = $Tickets->{All};
        $UserData{Tickets}->{OwnedAndUnseen} = $Tickets->{Unseen};

        # get tickets owned by user and locked
        $Tickets = $Self->_GetOwnedAndLockedTickets(TicketFilter => $TicketFilter);
        $UserData{Tickets}->{OwnedAndLocked} = $Tickets->{All};
        $UserData{Tickets}->{OwnedAndLockedAndUnseen} = $Tickets->{Unseen};

        # get tickets watched by user
        $Tickets = $Self->_GetWatchedTickets();
        $UserData{Tickets}->{Watched} = $Tickets->{All};
        $UserData{Tickets}->{WatchedAndUnseen} = $Tickets->{Unseen};

        # force integer TicketIDs in response
        foreach my $Type ( sort keys %{$UserData{Tickets}} ) {
            my @TicketIDs = map { 0 + $_ } @{$UserData{Tickets}->{$Type}};
            $UserData{Tickets}->{$Type} = \@TicketIDs;
        }

        # inform API caching about a new dependency
        $Self->AddCacheDependency(Type => 'Ticket');
        $Self->AddCacheDependency(Type => 'Watcher');
        $Self->AddCacheDependency(Type => 'Contact');
    }

    # include roleids if requested
    if ( $Param{Data}->{include}->{RoleIDs} ) {

        # get roles list
        my @RoleList = $Kernel::OM->Get('Role')->UserRoleList(
            UserID => $Self->{Authorization}->{UserID},
        );
        my @RoleIDs;
        foreach my $RoleID ( sort @RoleList ) {
            push(@RoleIDs, 0 + $RoleID); # enforce nummeric ID
        }
        $UserData{RoleIDs} = \@RoleIDs;
    }

    #FIXME: workaoround KIX2018-3308
    $Self->AddCacheDependency(Type => 'Contact');
    my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
        UserID        => $Self->{Authorization}->{UserID},
        DynamicFields => $Param{Data}->{include}->{DynamicFields},
    );
    $UserData{UserFirstname} = %ContactData ? $ContactData{Firstname} : undef;
    $UserData{UserLastname} = %ContactData ? $ContactData{Lastname} : undef;
    $UserData{UserFullname} = %ContactData ? $ContactData{Fullname} : undef;
    $UserData{UserEmail} = %ContactData ? $ContactData{Email} : undef;
    ###########################################################

    if ( $Param{Data}->{include}->{DynamicFields} ) {
        my @DynamicFields;

        # inform API caching about a new dependency
        $Self->AddCacheDependency(Type => 'DynamicField');

        # remove all dynamic fields from contact hash and set them into an array.
        ATTRIBUTE:
        for my $Attribute ( sort keys %ContactData ) {

            if ( $Attribute =~ m{\A DynamicField_(.*) \z}msx ) {
                if ( $ContactData{$Attribute} ) {
                    my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
                        Name => $1,
                    );
                    if ( IsHashRefWithData($DynamicFieldConfig) ) {

                        # ignore DFs which are not visible for the customer, if the user session is a Customer session
                        next ATTRIBUTE if $Self->{Authorization}->{UserType} eq 'Customer' && !$DynamicFieldConfig->{CustomerVisible};

                        my $PreparedValue = $Self->_GetPrepareDynamicFieldValue(
                            Config          => $DynamicFieldConfig,
                            Value           => $ContactData{$Attribute},
                            NoDisplayValues => [ split(',', $Param{Data}->{NoDynamicFieldDisplayValues}||'') ]
                        );

                        if (IsHashRefWithData($PreparedValue)) {
                            push(@DynamicFields, $PreparedValue);
                        }
                    }
                    delete $ContactData{$Attribute};
                }
                next ATTRIBUTE;
            }
        }

        # add dynamic fields array into 'DynamicFields' hash key if any
        if (@DynamicFields) {
            $ContactData{DynamicFields} = \@DynamicFields;
        }
        else {
            $ContactData{DynamicFields} = [];
        }
    }

    $UserData{Contact} = ( %ContactData ) ? \%ContactData : undef;


    return $Self->_Success(
        User => \%UserData,
    );
}

sub _GetOwnedTickets {
    my ( $Self, %Param ) = @_;
    my %Tickets;

    my @Filter = (
        {
            Field    => 'OwnerID',
            Operator => 'EQ',
            Value    => $Self->{Authorization}->{UserID},
        }
    );

    if ( IsHashRefWithData($Param{TicketFilter}) ) {
        push(@Filter, $Param{TicketFilter});
    }

    # execute ticket search
    my @TicketIDs = $Kernel::OM->Get('Ticket')->TicketSearch(
        Search => {
            AND => \@Filter
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );
    $Tickets{All} = \@TicketIDs;

    @Filter = (
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
        }
    );

    if ( IsHashRefWithData($Param{TicketFilter}) ) {
        push(@Filter, $Param{TicketFilter});
    }

    # execute ticket search
    my @SeenTicketIDs = $Kernel::OM->Get('Ticket')->TicketSearch(
        Search => {
            AND => \@Filter
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );

    # extract all unseen tickets
    my @UnseenTicketIDs;
    foreach my $TicketID ( @TicketIDs ) {
        next if grep(/^$TicketID$/, @SeenTicketIDs);
        push(@UnseenTicketIDs, $TicketID);
    }
    $Tickets{Unseen} = \@UnseenTicketIDs;

    return \%Tickets;
}

sub _GetOwnedAndLockedTickets {
    my ( $Self, %Param ) = @_;
    my %Tickets;

    my @Filter = (
        {
            Field    => 'OwnerID',
            Operator => 'EQ',
            Value    => $Self->{Authorization}->{UserID},
        },
        {
            Field    => 'LockID',
            Operator => 'EQ',
            Value    => 2,
        }
    );

    if ( IsHashRefWithData($Param{TicketFilter}) ) {
        push(@Filter, $Param{TicketFilter});
    }

    # execute ticket search
    my @TicketIDs = $Kernel::OM->Get('Ticket')->TicketSearch(
        Search => {
            AND => \@Filter
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );
    $Tickets{All} = \@TicketIDs;

    @Filter = (
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
        }
    );

    if ( IsHashRefWithData($Param{TicketFilter}) ) {
        push(@Filter, $Param{TicketFilter});
    }

    # execute ticket search
    my @SeenTicketIDs = $Kernel::OM->Get('Ticket')->TicketSearch(
        Search => {
            AND => \@Filter
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );

    # extract all unseen tickets
    my @UnseenTicketIDs;
    foreach my $TicketID ( @TicketIDs ) {
        next if grep(/^$TicketID$/, @SeenTicketIDs);
        push(@UnseenTicketIDs, $TicketID);
    }
    $Tickets{Unseen} = \@UnseenTicketIDs;

    return \%Tickets;
}

sub _GetWatchedTickets {
    my ( $Self, %Param ) = @_;
    my %Tickets;

    my @Filter = (
        {
            Field    => 'WatcherUserID',
            Operator => 'EQ',
            Value    => $Self->{Authorization}->{UserID},
        }
    );

    if ( IsHashRefWithData($Param{TicketFilter}) ) {
        push(@Filter, $Param{TicketFilter});
    }

    # execute ticket search
    my @TicketIDs = $Kernel::OM->Get('Ticket')->TicketSearch(
        Search => {
            AND => \@Filter
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );
    $Tickets{All} = \@TicketIDs;

    @Filter = (
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
        }
    );

    if ( IsHashRefWithData($Param{TicketFilter}) ) {
        push(@Filter, $Param{TicketFilter});
    }

    # execute ticket search
    my @SeenTicketIDs = $Kernel::OM->Get('Ticket')->TicketSearch(
        Search => {
            AND => \@Filter
        },
        UserID => $Self->{Authorization}->{UserID},
        Result => 'ARRAY',
    );

    # extract all unseen tickets
    my @UnseenTicketIDs;
    foreach my $TicketID ( @TicketIDs ) {
        next if grep(/^$TicketID$/, @SeenTicketIDs);
        push(@UnseenTicketIDs, $TicketID);
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
