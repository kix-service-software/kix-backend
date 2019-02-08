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

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'UserID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }                
    }
}

=item Run()

perform UserGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            UserID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
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

    my @UserList;

    # start loop
    foreach my $UserID ( @{$Param{Data}->{UserID}} ) {

        # get the user data
        my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID        => $UserID,
            NoPreferences => 1
        );

        if ( !IsHashRefWithData( \%UserData ) ) {

            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeWhitelist}) ) {
            foreach my $Attr (sort keys %UserData) {
                delete $UserData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
            }
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeBlacklist}) ) {
            foreach my $Attr (sort keys %UserData) {
                delete $UserData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
            }
        }
                
        # add
        push(@UserList, \%UserData);
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
