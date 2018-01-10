# --
# Kernel/API/Operation/SearchProfile/SearchProfileUpdate.pm - API SearchProfile Update operation backend
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

package Kernel::API::Operation::V1::SearchProfile::SearchProfileUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SearchProfile::SearchProfileUpdate - API SearchProfile Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SearchProfileUpdate');

    return $Self;
}

=item Run()

perform SearchProfileUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            SearchProfileID => 123,
            SearchProfile  => {
                Login         => 'mail',            # optional
                Password      => 'SomePassword',    # optional
                Host          => 'pop3.example.com',# optional
                Type          => 'POP3',            # optional
                IMAPFolder    => 'Some Folder',     # optional, only valid for IMAP-type accounts
                ValidID       => 1,                 # optional
                Trusted       => 0,                 # optional
                DispatchingBy => 'Queue',           # Queue|From
                Comment       => '...',             # optional
                QueueID       => 12,
            },
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            SearchProfileID  => 123,              # ID of the updated SearchProfile 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # init webSearchProfile
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    my %BackendList = $Kernel::OM->Get('Kernel::System::SearchProfile')->SearchProfileBackendList();

    # prepare data
    $Result = $Self->PrepareData(
        Data         => $Param{Data},
        Parameters   => {
            'SearchProfileID' => {
                Required => 1
            },
            'SearchProfile' => {
                Type => 'HASH',
                Required => 1
            },   
            'SearchProfile::Type' => {
                RequiresValueIfUsed => 1,
                OneOf => sort keys %BackendList,
            },
           'SearchProfile::DispatchingBy' => {
                RequiresValueIfUsed => 1,
                OneOf => [
                    'Queue',
                    'From'
                ]
            },            
           'SearchProfile::Trusted' => {
                RequiresValueIfUsed => 1,
                OneOf => [
                    0,
                    1
                ]
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

    # isolate and trim SearchProfile parameter
    my $SearchProfile = $Self->_Trim(
        Data => $Param{Data}->{SearchProfile}
    );
    
    # check if SearchProfile exists 
    my %SearchProfileData = $Kernel::OM->Get('Kernel::System::SearchProfile')->SearchProfileGet(
        ID     => $Param{Data}->{SearchProfileID},
        UserID => $Self->{Authorization}->{UserID},
    );
 
    if ( !%SearchProfileData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update SearchProfile. No SearchProfile with ID '$Param{Data}->{SearchProfileID}' found.",
        );
    }

    if ( $SearchProfile->{DispatchingBy} eq 'Queue' && !$SearchProfile->{QueueID} ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "A QueueID is required if DispatchingBy is set to 'Queue'",
        );        
    }

    # update SearchProfile
    my $Success = $Kernel::OM->Get('Kernel::System::SearchProfile')->SearchProfileUpdate(
        ID            => $Param{Data}->{SearchProfileID},
        Login         => $SearchProfile->{Login} || $SearchProfileData{Login},
        Password      => $SearchProfile->{Password} || $SearchProfileData{Password},
        Host          => $SearchProfile->{Host} || $SearchProfileData{Host},
        Type          => $SearchProfile->{Type} || $SearchProfileData{Type},
        IMAPFolder    => $SearchProfile->{IMAPFolder} || $SearchProfileData{IMAPFolder},
        ValidID       => $SearchProfile->{ValidID} || $SearchProfileData{ValidID},
        Trusted       => $SearchProfile->{Trusted} || $SearchProfileData{Trusted},
        DispatchingBy => $SearchProfile->{DispatchingBy} || $SearchProfileData{DispatchingBy},
        QueueID       => $SearchProfile->{QueueID} || $SearchProfileData{QueueID},
        Comment       => $SearchProfile->{Comment} || $SearchProfileData{Comment},        
        UserID        => $Self->{Authorization}->{UserID},                      
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update SearchProfile, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        SearchProfileID => $Param{Data}->{SearchProfileID},
    );    
}

1;
