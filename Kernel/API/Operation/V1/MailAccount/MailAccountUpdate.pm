# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
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

    my %BackendList = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountBackendList();

    return {
        'MailAccountID' => {
            Required => 1
        },
        'MailAccount' => {
            Type     => 'HASH',
            Required => 1
        },
        'MailAccount::Type' => {
            RequiresValueIfUsed => 1,
            OneOf               => sort keys %BackendList,
        },
        'MailAccount::DispatchingBy' => {
            RequiresValueIfUsed => 1,
            OneOf               => [
                'Queue',
                'From'
            ]
        },
        'MailAccount::Trusted' => {
            RequiresValueIfUsed => 1,
            OneOf               => [
                0,
                1
            ]
        },
        'MailAccount::ExecFetch' => {
            RequiresValueIfUsed => 1,
            OneOf               => [
                1
            ]
        },
    }
}

=item Run()

perform MailAccountUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            MailAccountID => 123,
            MailAccount  => {
                Login         => 'mail',            # optional
                Password      => 'SomePassword',    # optional
                Host          => 'pop3.example.com',# optional
                Type          => 'POP3',            # optional
                IMAPFolder    => 'Some Folder',     # optional, only valid for IMAP-type accounts
                ValidID       => 1,                 # optional
                Trusted       => 0,                 # optional
                DispatchingBy => 'Queue',           # Queue|From
                QueueID       => 12,                # optional, requuired if DispatchingBy is "Queue"
                Comment       => '...',             # optional
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

    # isolate and trim MailAccount parameter
    my $MailAccount = $Self->_Trim(
        Data => $Param{Data}->{MailAccount}
    );

    # check if MailAccount exists
    my %MailAccountData = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountGet(
        ID     => $Param{Data}->{MailAccountID},
        UserID => $Self->{Authorization}->{UserID},
    );

    if ( !%MailAccountData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    if ( $MailAccount->{DispatchingBy} eq 'Queue' && !$MailAccount->{QueueID} ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "A QueueID is required if DispatchingBy is set to 'Queue'",
        );
    }

    # update MailAccount
    my $Success = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountUpdate(
        ID            => $Param{Data}->{MailAccountID},
        Login         => $MailAccount->{Login} || $MailAccountData{Login},
        Password      => $MailAccount->{Password} || $MailAccountData{Password},
        Host          => $MailAccount->{Host} || $MailAccountData{Host},
        Type          => $MailAccount->{Type} || $MailAccountData{Type},
        IMAPFolder    => $MailAccount->{IMAPFolder} || $MailAccountData{IMAPFolder},
        ValidID       => $MailAccount->{ValidID} || $MailAccountData{ValidID},
        DispatchingBy => $MailAccount->{DispatchingBy} || $MailAccountData{DispatchingBy},
        QueueID       => $MailAccount->{QueueID} || $MailAccountData{QueueID},
        Trusted       => exists $MailAccount->{Trusted} ? $MailAccount->{Trusted} : $MailAccountData{Trusted},
        Comment       => exists $MailAccount->{Comment} ? $MailAccount->{Comment} : $MailAccountData{Comment},
        UserID        => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    if ( $MailAccount->{ExecFetch} ) {
        my $Success = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountFetch(
            %MailAccountData,
            UserID => 1,
        );

        if ( !$Success ) {
            my $LogMessage = $Kernel::OM->Get('Kernel::System::Log')->GetLogEntry(
                Type => 'error', 
                What => 'Message',
            );
            return $Self->_Error(
                Code    => 'Object.ExecFailed',
                Message => "An error occured during fetch (error: $LogMessage).",
            );
        }
    }

    # return result
    return $Self->_Success(
        MailAccountID => $Param{Data}->{MailAccountID},
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
