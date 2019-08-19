# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleGet - API FAQArticle Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::FAQ::FAQArticleGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::FAQArticle::FAQArticleGet');

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

    return {
        'FAQArticleID' => {
            Type     => 'ARRAY',
            Required => 1
        }                
    }
}

=item Run()

perform FAQArticleGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticleID => 1,
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            FAQArticle => [
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

    my @FAQArticleData;

    # start loop
    foreach my $FAQArticleID ( @{$Param{Data}->{FAQArticleID}} ) {

        # get the FAQArticle data
        my %FAQArticle = $Kernel::OM->Get('Kernel::System::FAQ')->FAQGet(
            ItemID     => $FAQArticleID,
            ItemFields => 1,
            UserID     => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%FAQArticle ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # map ItemID to ID
        $FAQArticle{ID} = $FAQArticle{ItemID};
        delete $FAQArticle{ItemID};

        # convert Keywords to array
        my @Keywords = split(/\s+/, $FAQArticle{Keywords});
        $FAQArticle{Keywords} = \@Keywords;

        if ( $Param{Data}->{include}->{Attachments} ) {
            # get attachment index (without attachments)
            my @AtmIndex = $Kernel::OM->Get('Kernel::System::FAQ')->AttachmentIndex(
                ItemID => $FAQArticleID,
                UserID => $Self->{Authorization}->{UserID},
            );

            my @Attachments;
            foreach my $Attachment ( sort {$a->{FileID} <=> $b->{FileID}} @AtmIndex ) {
                push(@Attachments, $Attachment->{FileID});
            }

            # set Attachments data
            $FAQArticle{Attachments} = \@Attachments;
        }

        if ( $Param{Data}->{include}->{History} ) {
            # get history list (only IDs)
            my $HistoryIDs = $Kernel::OM->Get('Kernel::System::FAQ')->FAQHistoryList(
                ItemID => $FAQArticleID,
                UserID => $Self->{Authorization}->{UserID},
            );

            # set History data
            $FAQArticle{History} = $HistoryIDs;
        }

        if ( $Param{Data}->{include}->{Votes} ) {
            # get Vote list (only IDs)
            my $VoteIDs = $Kernel::OM->Get('Kernel::System::FAQ')->VoteSearch(
                ItemID => $FAQArticleID,
                UserID => $Self->{Authorization}->{UserID},
            );

            # set Vote data
            $FAQArticle{Votes} = $VoteIDs;
        }

        # add
        push(@FAQArticleData, \%FAQArticle);
    }

    if ( scalar(@FAQArticleData) == 1 ) {
        return $Self->_Success(
            FAQArticle => $FAQArticleData[0],
        );    
    }

    # return result
    return $Self->_Success(
        FAQArticle => \@FAQArticleData,
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
