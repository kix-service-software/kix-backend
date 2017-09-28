# --
# Kernel/API/Operation/V1/ArticleType/ArticleTypeGet.pm - API ArticleType Get operation backend
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

package Kernel::API::Operation::V1::ArticleType::ArticleTypeGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ArticleType::ArticleTypeGet - API ArticleType Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::ArticleType::ArticleTypeGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ArticleType::ArticleTypeGet');

    return $Self;
}

=item Run()

perform ArticleTypeGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ArticleTypeID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            ArticleType => [
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
            Code    => 'Webservice.InArticleTypeConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'ArticleTypeID' => {
                Type     => 'ARRAY',
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

    my @ArticleTypeList;

    # start state loop
    State:    
    foreach my $ArticleTypeID ( @{$Param{Data}->{ArticleTypeID}} ) {

        # get the ArticleType data
        my $ArticleTypeName = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleTypeLookup(
            ArticleTypeID => $ArticleTypeID,
        );

        if ( !$ArticleTypeName ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No data found for ArticleTypeID $ArticleTypeID.",
            );
        }
       
        my %ArticleType;
        
        $ArticleType{ID} = $ArticleTypeID;
        $ArticleType{Name} = $ArticleTypeName;

        
        # add
        push(@ArticleTypeList, \%ArticleType);
    }

    if ( scalar(@ArticleTypeList) == 1 ) {
        return $Self->_Success(
            ArticleType => $ArticleTypeList[0],
        );    
    }

    # return result
    return $Self->_Success(
        ArticleType => \@ArticleTypeList,
    );
}

1;
