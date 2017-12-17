# --
# Kernel/API/Operation/Contact/ContactCreate.pm - API Contact Create operation backend
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

package Kernel::API::Operation::V1::Contact::ContactCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Contact::V1::ContactCreate - API Contact Create Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform ContactCreate Operation. This will return the created ContactLogin.

    my $Result = $OperationObject->Run(
        Data => {
            SourceID => '...'       # required (ID of backend to write to - backend must be writeable)
            Contact => {
                ...                 # attributes (required and optional) depend on Map config 
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ContactID  => '',                       # ContactID 
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

    # prepare data (first check)
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'SourceID' => {
                Required => 1
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # determine required attributes from Map config
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get($Param{Data}->{SourceID});
    my %RequiredAttributes;
    foreach my $MapItem ( @{$Config->{Map}} ) {
        next if !$MapItem->[4] || $MapItem->[0] eq 'ValidID';

        $RequiredAttributes{'Contact::'.$MapItem->[0]} = {
            Required => 1
        };
    }

    # prepare data (second check with more attributes)
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'Contact' => {
                Type     => 'HASH',
                Required => 1
            },          
            %RequiredAttributes,
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # check if backend (Source) is writeable
    my %SourceList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSourceList(
        ReadOnly => 0
    );    
    if ( !$SourceList{$Param{Data}->{SourceID}} ) {
        return $Self->_Error(
            Code    => 'Forbidden',
            Message => 'Can not create Contact. Backend with given SourceID is not writable or does not exist.',
        );        
    }

    # isolate Contact parameter
    my $Contact = $Param{Data}->{Contact};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$Contact} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $Contact->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $Contact->{$Attribute} =~ s{\s+\z}{};
        }
    }

    # check Userlogin exists
    my %ContactData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $Contact->{UserLogin},
    );
    if ( %ContactData ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Can not create Contact. Another Contact with same login already exists.",
        );
    }

    # check UserEmail exists
    my %ContactList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
        PostMasterSearch => $Contact->{UserEmail},
    );
    if ( %ContactList ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Can not create Contact. Another Contact with same email address already exists.',
        );
    }
    
    # create Contact
    my $ContactID = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserAdd(
        %{$Contact},
        Source  => $Param{Data}->{SourceID},
        UserID  => $Self->{Authorization}->{UserID},
        ValidID => 1,
    );    
    if ( !$ContactID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Contact, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        Code   => 'Object.Created',
        ContactID => $ContactID,
    );    
}
