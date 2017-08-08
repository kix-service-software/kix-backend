# --
# Kernel/GenericInterface/Operation/Customer/CustomerGet.pm - GenericInterface Customer Get operation backend
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

package Kernel::API::Operation::V1::Customer::CustomerGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
    Kernel::API::Operation::V1::Customer::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Customer::CustomerGet - GenericInterface Customer Get Operation backend

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::CustomerGet');

    return $Self;
}

=item Run()

perform CustomerGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            CustomerLogin         => 'some agent login',                            # CustomerLogin or CustomerCustomerLogin or SessionID is
                                                                                #   required
            CustomerCustomerLogin => 'some customer login',
            SessionID         => 123,

            Password          => 'some password',                                       # if CustomerLogin or customerCustomerLogin is sent then
                                                                                #   Password is required
            CustomerID            => '32,33',                                       # required, could be coma separated IDs or an Array
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        ErrorMessage => '',                               # In case of an error
        Data         => {
            Customer => [
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

    my ( $CustomerID, $CustomerType ) = $Self->Auth(
        %Param,
    );

    return $Self->ReturnError(
        ErrorCode    => 'CustomerGet.AuthFail',
        ErrorMessage => "CustomerGet: Authorization failing!",
    ) if !$CustomerID;

    # check needed stuff
    for my $Needed (qw(CustomerID)) {
        if ( !$Param{Data}->{$Needed} ) {
            return $Self->ReturnError(
                ErrorCode    => 'CustomerGet.MissingParameter',
                ErrorMessage => "CustomerGet: $Needed parameter is missing!",
            );
        }
    }
    my $ErrorMessage = '';

    # all needed variables
    my @CustomerIDs;
    if ( IsStringWithData( $Param{Data}->{CustomerID} ) ) {
        @CustomerIDs = split( /,/, $Param{Data}->{CustomerID} );
    }
    elsif ( IsArrayRefWithData( $Param{Data}->{CustomerID} ) ) {
        @CustomerIDs = @{ $Param{Data}->{CustomerID} };
    }
    else {
        return $Self->ReturnError(
            ErrorCode    => 'CustomerGet.WrongStructure',
            ErrorMessage => "CustomerGet: Structure for CustomerID is not correct!",
        );
    }

    my $ReturnData        = {
        Success => 1,
    };
    my @Item;

    # start company loop
    COMPANY:
    for my $CustomerID (@CustomerIDs) {

        # get the user entry
        my %CompanyEntry = $Kernel::OM->Get('Kernel::System::Customer')->CustomerGet(
            CustomerID => $CustomerID,
        );

        if ( !IsHashRefWithData( \%CompanyEntry ) ) {

            $ErrorMessage = 'Could not get user data'
                . ' in Kernel::API::Operation::V1::Customer::CustomerGet::Run()';

            return $Self->ReturnError(
                ErrorCode    => 'CustomerGet.NotValidCustomerID',
                ErrorMessage => "CustomerGet: $ErrorMessage",
            );
        }

        # filter valid attributes
        foreach my $Attr (sort keys %CompanyEntry) {
            delete $CompanyEntry{$Attr} if !$Self->{Config}->{ExportedAttributes}->{$Attr};
        }

        # add
        push(@Item, \%CompanyEntry);
    }

    if ( !scalar(@Item) ) {
        $ErrorMessage = 'Could not get user data'
            . ' in Kernel::API::Operation::V1::Customer::CustomerGet::Run()';

        return $Self->ReturnError(
            ErrorCode    => 'CustomerGet.NotCustomerData',
            ErrorMessage => "CustomerGet: $ErrorMessage",
        );

    }

    # set user data into return structure
    $ReturnData->{Data}->{Customer} = \@Item;

    # return result
    return $ReturnData;
}

1;
