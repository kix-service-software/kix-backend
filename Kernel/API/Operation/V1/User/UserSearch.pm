# --
# Kernel/API/Operation/User/UserSearch.pm - API User Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::User::UserSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::User::UserGet;
use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::User::UserSearch - API User Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

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
            Authorization => {
                ...
            },
            ChangedAfter => '2006-01-09 00:00:01',                        # (optional)            
            Order        => 'Down|Up',                                    # (optional) Default: Up                       
            Limit        => 122,                                          # (optional) Default: 500
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data         => {
            UserID => [ 1, 2, 3, 4 ],
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

    # parse and prepare parameters
    $Result = $Self->ParseParameters(
        Data       => $Param{Data},
        Parameters => {
            'Limit' => {
                Default => 500,
            },
            'Order' => {
                Default => 'Up'    
            }
        }
    );

    # perform user search
    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Type => 'Short',
    );

    if (IsHashRefWithData(\%UserList)) {

        if ($Param{Data}->{ChangedAfter}) {
            $Param{Data}->{ChangedAfterUnixtime} = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                String => $Param{Data}->{ChangedAfter},
            );
        }

        # get already prepared user data from UserGet operation
        my $UserGetResult = $Self->ExecOperation(
            Operation => 'V1::User::UserGet',
            Data      => {
                UserID => join(',', sort keys %UserList),
            }
        );
        if ( !IsHashRefWithData($UserGetResult) || !$UserGetResult->{Success} ) {
            return $UserGetResult;
        }

        # filter list
        my @ResultList;
        foreach my $User ( @{$UserGetResult->{Data}->{User}} ) {
            if ( $Param{Data}->{ChangedAfter} ) {
                # filter change time
                my $ChangeTimeUnix = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                    String => $User->{ChangeTime},
                );
                next if $ChangeTimeUnix < $Param{Data}->{ChangedAfterUnixtime};
            }
            
            # limit list
            last if scalar(@ResultList) > $Param{Data}->{Limit};
            
            push(@ResultList, $User);                                
        }  

        if ( IsArrayRefWithData(\@ResultList) ) {
            return {
                Success => 1,
                Data    => {
                    Users => \@ResultList,
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
