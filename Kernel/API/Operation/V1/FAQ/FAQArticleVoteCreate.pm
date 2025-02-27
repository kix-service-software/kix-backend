# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleVoteCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleVoteCreate - API Operation backend

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

    return {
        'FAQArticleID' => {
            Required => 1
        },
        'FAQVote' => {
            Type     => 'HASH',
            Required => 1
        },
        'FAQVote::CreatedBy' => {
            RequiresValueIfUsed => 1,
        },
        'FAQVote::IPAddress' => {
            Required => 1,
            Format   => '\d+\.\d+\.\d+\.\d+',
        },
        'FAQVote::Interface' => {
            Required => 1,
            OneOf    => [
                'agent',
                'customer',
                'public'
            ]
        },
        'FAQVote::Rating' => {
            Required => 1,
            Format   => '^([1-5]{1})$',
        },
    }
}

=item Run()

perform FAQArticleVoteCreate Operation. This will return the created VoteID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticleID    => 123,
            FAQVote  => {
                IPAddress => 'xxx.xxx.xxx.xxx',
                Interface => 'agent',               # possible values: 'agent', 'customer' and 'public'
                Rating    => 1,                     # integer between 1 and 5
                CreatedBy => '...',                 # optional
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            FAQVoteID   => 123,                     # ID of created Vote
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim FAQVote parameter
    my $FAQVote = $Self->_Trim(
        Data => $Param{Data}->{FAQVote}
    );

    # everything is ok, let's create the Vote
    my $VoteID = $Kernel::OM->Get('FAQ')->VoteAdd(
        ItemID      => $Param{Data}->{FAQArticleID},
        IP          => $FAQVote->{IPAddress},
        Interface   => $FAQVote->{Interface},
        Rate        => $FAQVote->{Rating},
        CreatedBy   => $FAQVote->{CreatedBy} || 'unknown',
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$VoteID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create FAQArticle vote, please contact the system administrator',
        );
    }

    return $Self->_Success(
        Code   => 'Object.Created',
        FAQVoteID => $VoteID,
    );

}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
