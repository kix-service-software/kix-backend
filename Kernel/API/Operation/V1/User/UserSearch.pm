# --
# Kernel/GenericInterface/Operation/User/UserSearch.pm - GenericInterface User Search operation backend
# based upon Kernel/GenericInterface/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::User::UserSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::User::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::User::UserSearch - GenericInterface User Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform UserSearch Operation. This will return a User ID list.

    my $Result = $OperationObject->Run(
        Data => {
            SessionID    => 123,                                          # required
            ChangedAfter => '2006-01-09 00:00:01',                        # (optional)            
            OrderBy      => 'Down|Up',                                    # (optional) Default: Up                       
            Limit        => 122,                                          # (optional) Default: 500
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data         => {
            TicketID => [ 1, 2, 3, 4 ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->ReturnError(
            ErrorCode    => 'Webservice.InvalidConfiguration',
            ErrorMessage => $Result->{ErrorMessage},
        );
    }

    my ( $UserID, $UserType ) = $Self->Auth(
        %Param,
    );

    return $Self->ReturnError(
        ErrorCode    => 'UserSearch.AuthFail',
        ErrorMessage => "UserSearch: Authorization failing!",
    ) if !$UserID;

    # all needed variables
    $Self->{ChangedAfter} = $Param{Data}->{ChangedAfter}
        || undef;
    $Self->{Limit} = $Param{Data}->{Limit}
        || 500;
    $Self->{OrderBy} = $Param{Data}->{OrderBy}
        || 'Up';

    # perform user search
    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Type => 'Short',
    );

    if (IsHashRefWithData(\%UserList)) {
        my @UserIDs = sort keys %UserList;
        
        if ($Self->{ChangedAfter}) {
            my $ChangedAfterUnixtime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                String => $Self->{ChangedAfter},
            );
            
            # filter list
            my @FilteredUserIDs;
            foreach my $UserID (@UserIDs) {
                my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
                    UserID => $UserID,
                ); 
                next if !IsHashRefWithData(\%UserData);
                
                # filter change time
                my $ChangeTimeUnix = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                    String => $UserData{ChangeTime},
                );
                next if $ChangeTimeUnix < $ChangedAfterUnixtime;
                
                # limit list
                last if scalar(@FilteredUserIDs) > $Self->{Limit};
                
                push(@FilteredUserIDs, $UserID);                                
            }
            
            @UserIDs = @FilteredUserIDs; 
        }
        else {
            # limit list
            @UserIDs = splice(@UserIDs, 0, $Self->{Limit}); 
        }

        # do we have to sort downwards ?
        @UserIDs = reverse @UserIDs if ($Self->{OrderBy} eq 'Down');        

        if (IsArrayRefWithData(\@UserIDs)) {
            return {
                Success => 1,
                Data    => {
                    UserID => \@UserIDs,
                },
            };
        }
    }

    # return result
    return {
        Success => 1,
        Data    => {},
    };
}

1;
