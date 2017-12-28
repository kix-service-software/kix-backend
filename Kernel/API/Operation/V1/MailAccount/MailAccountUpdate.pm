# --
# Kernel/API/Operation/MailAccount/MailAccountUpdate.pm - API MailAccount Update operation backend
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

package Kernel::API::Operation::V1::MailAccount::MailAccountUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::MailAccount::MailAccountUpdate - API MailAccount Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::MailAccountUpdate');

    return $Self;
}

=item Run()

perform MailAccountUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            MailAccountID => 123,
            MailAccount  => {
                Login         => 'mail',
                Password      => 'SomePassword',
                Host          => 'pop3.example.com',
                Type          => 'POP3',
                IMAPFolder    => 'Some Folder',     # optional, only valid for IMAP-type accounts
                ValidID       => 1,
                Trusted       => 0,
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
            MailAccountID  => 123,              # ID of the updated MailAccount 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # init webMailAccount
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data         => $Param{Data},
        Parameters   => {
            'MailAccountID' => {
                Required => 1
            },
            'MailAccount' => {
                Type => 'HASH',
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

    # isolate MailAccount parameter
    my $MailAccount = $Param{Data}->{MailAccount};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$MailAccount} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $MailAccount->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $MailAccount->{$Attribute} =~ s{\s+\z}{};
        }
    }   

    # check if MailAccount exists 
    my %MailAccountData = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountGet(
        ID => $Param{Data}->{MailAccountID},
        UserID      => $Self->{Authorization}->{UserID},        
    );
 
    if ( !%MailAccountData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update MailAccount. No MailAccount with ID '$Param{Data}->{MailAccountID}' found.",
        );
    }

    # update MailAccount
    my $Success = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountUpdate(
        ID       => $Param{Data}->{MailAccountID} || $MailAccountData{MailAccountID},
        Login         => $MailAccount->{Login} || $MailAccountData{Login},
        Password      => $MailAccount->{Password} || $MailAccountData{Password},
        Host          => $MailAccount->{Host} || $MailAccountData{Host},
        Type          => $MailAccount->{Type} || $MailAccountData{Type},
        IMAPFolder    => $MailAccount->{IMAPFolder} || $MailAccountData{IMAPFolder},
        ValidID       => $MailAccount->{ValidID} || $MailAccountData{ValidID},
        Trusted       => $MailAccount->{Trusted} || $MailAccountData{Trusted},
        DispatchingBy => $MailAccount->{DispatchingBy} || $MailAccountData{DispatchingBy},
        QueueID       => $MailAccount->{QueueID} || $MailAccountData{QueueID},
        Comment       => $MailAccount->{Comment} || $MailAccountData{Comment},        
        UserID        => $Self->{Authorization}->{UserID},                      
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update MailAccount, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        MailAccountID => $Param{Data}->{MailAccountID},
    );    
}

1;
