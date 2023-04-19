# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::MailAccount::MailAccountCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::MailAccount::MailAccountCreate - API MailAccount Create Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

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

    my %BackendList = $Kernel::OM->Get('MailAccount')->MailAccountBackendList();
    my @Types = sort keys %BackendList;

    my %ProfileList = $Kernel::OM->Get('OAuth2')->ProfileList(
        Valid  => 1,
    );
    my @Profiles = sort keys %ProfileList;

    return {
        'MailAccount' => {
            Type     => 'HASH',
            Required => 1
        },
        'MailAccount::Login' => {
            Required => 1
        },
        'MailAccount::Password' => {
            RequiresValueIfUsed => 1
        },
        'MailAccount::OAuth2_ProfileID' => {
            RequiresValueIfUsed => 1,
            OneOf               => \@Profiles,
        },
        'MailAccount::Host' => {
            Required => 1
        },
        'MailAccount::Type' => {
            Required => 1,
            OneOf    => \@Types,
        },
        'MailAccount::DispatchingBy' => {
            Required => 1,
            OneOf    => [
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
    }
}

=item Run()

perform MailAccountCreate Operation. This will return the created MailAccountID.

    my $Result = $OperationObject->Run(
        Data => {
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
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            MailAccountID  => '',                         # ID of the created MailAccount
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim MailAccount parameter
    my $MailAccount = $Self->_Trim(
        Data => $Param{Data}->{MailAccount}
    );

    if ( $MailAccount->{DispatchingBy} eq 'Queue' && !$MailAccount->{QueueID} ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "A QueueID is required if DispatchingBy is set to 'Queue'",
        );
    }

    # check for oauth2 type and profile
    if (
        $MailAccount->{Type}
        && $MailAccount->{Type} =~ m/_OAuth2$/xmsi
    ) {
        if ( !$MailAccount->{OAuth2_ProfileID} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "A Profile is required if Type is kind of 'OAuth2'",
            );
        }
    }
    # check for password
    else {
        if ( !$MailAccount->{Password} ) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => "A Password is required if Type is not kind of 'OAuth2'",
            );
        }
    }

    # create MailAccount
    my $MailAccountID = $Kernel::OM->Get('MailAccount')->MailAccountAdd(
        Login            => $MailAccount->{Login},
        Password         => $MailAccount->{Password},
        OAuth2_ProfileID => $MailAccount->{OAuth2_ProfileID},
        Host             => $MailAccount->{Host},
        Type             => $MailAccount->{Type},
        IMAPFolder       => $MailAccount->{IMAPFolder} || '',
        ValidID          => $MailAccount->{ValidID} || 1,
        Trusted          => $MailAccount->{Trusted} || 0,
        DispatchingBy    => $MailAccount->{DispatchingBy},
        QueueID          => $MailAccount->{QueueID} || '',
        Comment          => $MailAccount->{Comment} || '',
        UserID           => $Self->{Authorization}->{UserID},
    );

    if ( !$MailAccountID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create MailAccount, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        MailAccountID => $MailAccountID,
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
