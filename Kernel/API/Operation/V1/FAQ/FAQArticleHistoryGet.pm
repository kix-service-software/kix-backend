# --
# Kernel/API/Operation/V1/FAQ/FAQArticleGet.pm - API FAQ Get operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQArticleHistoryGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleHistoryGet - API FAQArticleHistory Get Operation backend

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::FAQArticle::FAQArticleHistoryGet');

    return $Self;
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

    # init webservice
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
        Data       => $Param{Data},
        Parameters => {
            'FAQArticleID' => {
                Required => 1
            },      
            'FAQHistoryID' => {
                Type     => 'ARRAY',
                DataType => 'NUMERIC',
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

    my @FAQArticleHistoryData;

    # start HistoryID loop
    HISTORY:    
    foreach my $HistoryID ( @{$Param{Data}->{FAQHistoryID}} ) {

        # get the FAQHistory data
        my %History = $Kernel::OM->Get('Kernel::System::FAQ')->FAQHistoryGet(
            ID     => $HistoryID,
            UserID => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%History ) ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No data found for FAQHistoryID $HistoryID.",
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