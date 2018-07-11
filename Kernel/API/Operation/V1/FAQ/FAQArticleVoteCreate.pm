# --
# Kernel/API/Operation/FAQ/FAQArticleCreate.pm - API FAQCategory Create operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQArticleVoteCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleVoteCreate - API Operation backend

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::FAQArticleCreate');

    return $Self;
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
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # isolate and trim FAQVote parameter
    my $FAQVote = $Self->_Trim(
        Data => $Param{Data}->{FAQVote}
    );
    
    # everything is ok, let's create the Vote
    my $VoteID = $Kernel::OM->Get('Kernel::System::FAQ')->VoteAdd(
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