# --
# Kernel/API/Operation/User/UserGet.pm - API User Get operation backend
# based upon Kernel/API/Operation/Ticket/TicketGet.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::User::UserGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::User::UserGet - API User Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::User::UserGet->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::User::UserGet');

    return $Self;
}

=item Run()

perform UserGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            Authorization => {
                ...
            },
            UserID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            User => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'UserID' => {
                Type     => 'ARRAY',
                Required => 1
            }                
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    my $Message = '';

    my @UserList;

    # start user loop
    USER:    
    foreach my $UserID ( @{$Param{Data}->{UserID}} ) {

        # get the user data
        my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID => $UserID,
        );

        if ( !IsHashRefWithData( \%UserData ) ) {

            $Message = 'Could not get user data'
                . ' in Kernel::API::Operation::V1::User::UserGet::Run()';

            return $Self->_Error(
                Code    => 'UserGet.InvalidUserID',
                Message => "UserGet: $Message",
            );
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeWhitelist}) ) {
            foreach my $Attr (sort keys %UserData) {
                delete $UserData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
            }
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeBacklist}) ) {
            foreach my $Attr (sort keys %UserData) {
                delete $UserData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
            }
        }
                
        # add
        push(@UserList, \%UserData);
    }

    if ( !scalar(@UserList) ) {
        $Message = 'Could not get user data'
            . ' in Kernel::API::Operation::V1::User::UserGet::Run()';

        return $Self->_Error(
            Code    => 'UserGet.NoUserData',
            Message => "UserGet: $Message",
        );

    }

    if ( scalar(@UserList) == 1 ) {
        return $Self->_Success(
            User => $UserList[0],
        );    
    }

    return $Self->_Success(
        User => \@UserList,
    );
}

1;
