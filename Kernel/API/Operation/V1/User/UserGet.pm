# --
# Kernel/GenericInterface/Operation/User/UserGet.pm - GenericInterface User Get operation backend
# based upon Kernel/GenericInterface/Operation/Ticket/TicketGet.pm
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

package Kernel::GenericInterface::Operation::User::UserGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::GenericInterface::Operation::Common
    Kernel::GenericInterface::Operation::User::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::GenericInterface::Operation::User::UserGet - GenericInterface User Get Operation backend

=head1 SYNOPSIS

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

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('GenericInterface::Operation::UserGet');

    return $Self;
}

=item Run()

perform UserGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            UserLogin         => 'some agent login',                            # UserLogin or CustomerUserLogin or SessionID is
                                                                                #   required
            CustomerUserLogin => 'some customer login',
            SessionID         => 123,

            Password          => 'some password',                                       # if UserLogin or customerUserLogin is sent then
                                                                                #   Password is required
            UserID            => '32,33',                                       # required, could be coma separated IDs or an Array
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
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
        ErrorCode    => 'UserGet.AuthFail',
        ErrorMessage => "UserGet: Authorization failing!",
    ) if !$UserID;

    # check needed stuff
    for my $Needed (qw(UserID)) {
        if ( !$Param{Data}->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'UserGet.MissingParameter',
                ErrorMessage => "UserGet: $Needed parameter is missing!",
            );
        }
    }
    my $ErrorMessage = '';

    # all needed variables
    my @UserIDs;
    if ( IsStringWithData( $Param{Data}->{UserID} ) ) {
        @UserIDs = split( /,/, $Param{Data}->{UserID} );
    }
    elsif ( IsArrayRefWithData( $Param{Data}->{UserID} ) ) {
        @UserIDs = @{ $Param{Data}->{UserID} };
    }
    else {
        return $Self->ReturnError(
            ErrorCode    => 'UserGet.WrongStructure',
            ErrorMessage => "UserGet: Structure for UserID is not correct!",
        );
    }

    my $ReturnData        = {
        Success => 1,
    };
    my @Item;

    # start user loop
    USER:
    for my $UserID (@UserIDs) {

        # get the user entry
        my %UserEntry = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID      => $UserID,
        );

        if ( !IsHashRefWithData( \%UserEntry ) ) {

            $ErrorMessage = 'Could not get user data'
                . ' in Kernel::GenericInterface::Operation::User::UserGet::Run()';

            return $Self->ReturnError(
                ErrorCode    => 'UserGet.NotValidUserID',
                ErrorMessage => "UserGet: $ErrorMessage",
            );
        }

        # filter valid attributes
        foreach my $Attr (sort keys %UserEntry) {
            delete $UserEntry{$Attr} if !$Self->{Config}->{ExportedAttributes}->{$Attr};
        }
        
        # add
        push(@Item, \%UserEntry);
    }

    if ( !scalar(@Item) ) {
        $ErrorMessage = 'Could not get user data'
            . ' in Kernel::GenericInterface::Operation::User::UserGet::Run()';

        return $Self->ReturnError(
            ErrorCode    => 'UserGet.NotUserData',
            ErrorMessage => "UserGet: $ErrorMessage",
        );

    }

    # set user data into return structure
    $ReturnData->{Data}->{User} = \@Item;

    # return result
    return $ReturnData;
}

1;
