# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleHistoryGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::FAQ::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleHistoryGet - API FAQArticleHistory Get Operation backend

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
        'FAQHistoryID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }
    }
}

=item Run()

perform FAQArticleHistoryGet Operation.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticleID => 1,
            FAQHistoryID => 1,
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            FAQHistory => [
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

    my @FAQArticleHistoryData;

    # start loop
    foreach my $HistoryID ( @{$Param{Data}->{FAQHistoryID}} ) {

        # get the FAQHistory data
        my %History = $Kernel::OM->Get('FAQ')->FAQHistoryGet(
            ID     => $HistoryID,
            UserID => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%History ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # rename ItemID in ArticleID
        $History{ArticleID} = $History{ItemID};
        delete $History{ItemID};

        # add
        push(@FAQArticleHistoryData, \%History);
    }

    if ( scalar(@FAQArticleHistoryData) == 1 ) {
        return $Self->_Success(
            FAQHistory => $FAQArticleHistoryData[0],
        );
    }

    # return result
    return $Self->_Success(
        FAQHistory => \@FAQArticleHistoryData,
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
