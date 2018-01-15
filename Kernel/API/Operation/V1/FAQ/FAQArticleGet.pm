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

=item Run()

perform FAQArticleGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ArticleID => 1,
        },
    );

    $Result = {
        ArticleID => 2,
        ParentID   => 0,
        Name       => 'My Article',
        Comment    => 'This is my first Article.',
        ValidID    => 1,
    );

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
                Type     => 'ARRAY',
                Required => 1
            }                
        }
    );
use Data::Dumper;
print STDERR "param".Dumper(\%Param);
    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    my @FAQArticleData;

    # start faq loop
    FAQArticle:    
    foreach my $FAQArticleID ( @{$Param{Data}->{FAQArticleID}} ) {
print STDERR "param2".Dumper($FAQArticleID);
        # get the FAQArticle data
        my %FAQArticle = $Kernel::OM->Get('Kernel::System::FAQ')->FAQGet(
            ItemID     => $FAQArticleID,
            ItemFields => 1,
            UserID     => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%FAQArticle ) ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No data found for FAQArticleID $FAQArticleID.",
            );
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
