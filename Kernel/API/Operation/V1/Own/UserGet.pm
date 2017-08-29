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

package Kernel::API::Operation::V1::Own::UserGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Own::UserGet - API User Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Own::UserGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Own::UserGet');

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
        Data => $Param{Data},
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    my $Message = '';

    # get the user data
    my %UserData;
    if ( $Param{Data}->{Authorization}->{UserType} eq 'Agent' ) {
        %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID => $Param{Data}->{Authorization}->{UserID},
        );
    }
    elsif ( $Param{Data}->{Authorization}->{UserType} eq 'Customer' ) {
        %UserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $Param{Data}->{Authorization}->{UserID},
        );        
    }
    else {
        $Message = 'Unknown UserType $Param{Data}->{Authorization}->{UserType} '
            . ' in Kernel::API::Operation::V1::Own::UserGet::Run()';

        return $Self->_Error(
            Code    => 'UserGet.InvalidUserType',
            Message => "UserGet: $Message",
        );        
    }

    if ( !IsHashRefWithData( \%UserData ) ) {

        $Message = 'Could not get user data'
            . ' in Kernel::API::Operation::V1::Own::UserGet::Run()';

        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "UserGet: $Message",
        );
    }

    # filter valid attributes
    if ($Self->{Config}->{AttributeWhitelist}) {
        foreach my $Attr (sort keys %UserData) {
            delete $UserData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
        }
    }

    # filter valid attributes
    if ($Self->{Config}->{AttributeBacklist}) {
        foreach my $Attr (sort keys %UserData) {
            delete $UserData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
        }
    }

    return $Self->_Success(
        User => \%UserData,
    );    
}

1;
