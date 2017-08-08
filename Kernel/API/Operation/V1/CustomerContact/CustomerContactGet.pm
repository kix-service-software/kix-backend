# --
# Kernel/GenericInterface/Operation/CustomerContact/CustomerContactGet.pm - GenericInterface CustomerContact Get operation backend
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

package Kernel::API::Operation::V1::CustomerContact::CustomerContactGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
    Kernel::API::Operation::V1::CustomerContact::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CustomerContact::CustomerContactGet - GenericInterface CustomerContact Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::CustomerContactGet');

    return $Self;
}

=item Run()

perform CustomerContactGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            CustomerContactLogin         => 'some agent login',                            # CustomerContactLogin or CustomerCustomerContactLogin or SessionID is
                                                                                #   required
            CustomerCustomerContactLogin => 'some customer login',
            SessionID         => 123,

            Password          => 'some password',                                       # if CustomerContactLogin or customerCustomerContactLogin is sent then
                                                                                #   Password is required
            CustomerContactID            => '32,33',                                       # required, could be coma separated IDs or an Array
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data         => {
            CustomerContact => [
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

    my ( $CustomerContactID, $CustomerContactType ) = $Self->Auth(
        %Param,
    );

    return $Self->ReturnError(
        ErrorCode    => 'CustomerContactGet.AuthFail',
        ErrorMessage => "CustomerContactGet: Authorization failing!",
    ) if !$CustomerContactID;

    # check needed stuff
    for my $Needed (qw(CustomerContactID)) {
        if ( !$Param{Data}->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'CustomerContactGet.MissingParameter',
                ErrorMessage => "CustomerContactGet: $Needed parameter is missing!",
            );
        }
    }
    my $ErrorMessage = '';

    # all needed variables
    my @CustomerContactIDs;
    if ( IsStringWithData( $Param{Data}->{CustomerContactID} ) ) {
        @CustomerContactIDs = split( /,/, $Param{Data}->{CustomerContactID} );
    }
    elsif ( IsArrayRefWithData( $Param{Data}->{CustomerContactID} ) ) {
        @CustomerContactIDs = @{ $Param{Data}->{CustomerContactID} };
    }
    else {
        return $Self->ReturnError(
            ErrorCode    => 'CustomerContactGet.WrongStructure',
            ErrorMessage => "CustomerContactGet: Structure for CustomerContactID is not correct!",
        );
    }

    my $ReturnData        = {
        Success => 1,
    };
    my @Item;

    # start user loop
    USER:
    for my $CustomerContactID (@CustomerContactIDs) {

        # get the user entry
        my %UserEntry = $Kernel::OM->Get('Kernel::System::CustomerContact')->CustomerContactDataGet(
            User => $CustomerContactID,
        );

        if ( !IsHashRefWithData( \%UserEntry ) ) {

            $ErrorMessage = 'Could not get user data'
                . ' in Kernel::API::Operation::V1::CustomerContact::CustomerContactGet::Run()';

            return $Self->ReturnError(
                ErrorCode    => 'CustomerContactGet.NotValidCustomerContactID',
                ErrorMessage => "CustomerContactGet: $ErrorMessage",
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
            . ' in Kernel::API::Operation::V1::CustomerContact::CustomerContactGet::Run()';

        return $Self->ReturnError(
            ErrorCode    => 'CustomerContactGet.NotCustomerContactData',
            ErrorMessage => "CustomerContactGet: $ErrorMessage",
        );

    }

    # set user data into return structure
    $ReturnData->{Data}->{CustomerContact} = \@Item;

    # return result
    return $ReturnData;
}

1;
