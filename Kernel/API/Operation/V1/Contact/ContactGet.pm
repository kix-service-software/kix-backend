# --
# Kernel/API/Operation/Contact/ContactGet.pm - API Contact Get operation backend
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

package Kernel::API::Operation::V1::Contact::ContactGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Contact::ContactGet - API Contact Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Contact::ContactGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Contact::ContactGet');

    return $Self;
}

=item Run()

perform ContactGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ContactID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
        Data         => {
            Contact => [
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
            'ContactID' => {
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

    my @ContactList;
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get('CustomerUser');
  
    # start Contact loop
    Contact:    
    foreach my $ContactID ( @{$Param{Data}->{ContactID}} ) {

        # get the Contact data
        my %ContactData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
            User => $ContactID,
        );

        if ( !IsHashRefWithData( \%ContactData ) ) {

            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No Contact data found for ContactID $ContactID.",
            );
        }

        # map UserID to ContactID
        $ContactData{ContactID} = $ContactData{UserID};
        delete $ContactData{UserID};

        # map Source to SourceID
        $ContactData{SourceID} = $ContactData{Source};
        delete $ContactData{Source};

        my $AttributeWhitelist = $Self->{Config}->{AttributeWhitelist};

        # add attributes from Map to whitelist
        foreach my $Field ( @{$ContactData{Config}->{Map}} ) {
            next if !$Field->{Exposed};
            $AttributeWhitelist->{$Field->{Attribute}} = 1;
        }

        # add required attributes to whitelist
        foreach my $Attr ( qw(SourceID ContactID CreateBy CreateTime ChangeBy ChangeTime ValidID StringValue) ) {
            $AttributeWhitelist->{$Attr} = 1;
        } 

        # filter valid attributes
        if ( IsHashRefWithData($AttributeWhitelist) ) {
            foreach my $Attr (sort keys %ContactData) {
                delete $ContactData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
            }
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeBlacklist}) ) {
            foreach my $Attr (sort keys %ContactData) {
                delete $ContactData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
            }
        }
              
        # add
        push(@ContactList, \%ContactData);
    }

    if ( scalar(@ContactList) == 1 ) {
        return $Self->_Success(
            Contact => $ContactList[0],
        );    
    }

    return $Self->_Success(
        Contact => \@ContactList,
    );
}

1;
