# --
# Kernel/API/Operation/V1/FAQ/FAQCategoryGet.pm - API FAQ Get operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQCategoryGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQCategoryGet - API FAQCategory Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::FAQ::FAQCategoryGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::FAQCategory::FAQCategoryGet');

    return $Self;
}

=item Run()

perform FAQCategoryGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            CategoryID => 1,
        },
    );

    $Result = {
        CategoryID => 2,
        ParentID   => 0,
        Name       => 'My Category',
        Comment    => 'This is my first category.',
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
            'FAQCategoryID' => {
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

    my @FAQCategoryData;

    # start faq loop
    FAQCategory:    
    foreach my $FAQCategoryID ( @{$Param{Data}->{FAQCategoryID}} ) {

        # get the FAQCategory data
        my %FAQCategory = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryGet(
            CategoryID     => $FAQCategoryID,
            UserID   => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%FAQCategory ) ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No data found for FAQCategoryID $FAQCategoryID.",
            );
        }
        
        # add
        push(@FAQCategoryData, \%FAQCategory);
    }

    if ( scalar(@FAQCategoryData) == 1 ) {
        return $Self->_Success(
            FAQCategory => $FAQCategoryData[0],
        );    
    }

    # return result
    return $Self->_Success(
        FAQCategory => \@FAQCategoryData,
    );
}

1;
