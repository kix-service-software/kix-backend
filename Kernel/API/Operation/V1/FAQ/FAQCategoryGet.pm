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
        'FAQCategoryID' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform FAQCategoryGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            FAQCategoryID => 1,                      # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            FAQCategory => [
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

    my @FAQCategoryData;

    # start loop
    foreach my $FAQCategoryID ( @{$Param{Data}->{FAQCategoryID}} ) {

        # get the FAQCategory data
        my %FAQCategory = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryGet(
            CategoryID => $FAQCategoryID,
            UserID     => $Self->{Authorization}->{UserID},
        );

        if ( !IsHashRefWithData( \%FAQCategory ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # undef ParentID if not set
        if ( $FAQCategory{ParentID} == 0 ) {
            $FAQCategory{ParentID} = undef;
        }

        # include GroupIDs
        $FAQCategory{GroupIDs} = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryGroupGet(
            CategoryID => $FAQCategoryID,
            UserID     => $Self->{Authorization}->{UserID},
        );

        # include SubCategories if requested
        if ( $Param{Data}->{include}->{SubCategories} ) {
            $FAQCategory{SubCategories} = $Kernel::OM->Get('Kernel::System::FAQ')->CategorySubCategoryIDList(
                ParentID => $FAQCategoryID,
                UserID   => $Self->{Authorization}->{UserID},
            );

            # force numeric IDs
            my $Index = 0;
            foreach my $Value ( @{$FAQCategory{SubCategories}} ) {
                $FAQCategory{SubCategories}->[$Index++] = 0 + $Value;
            }
        }

        # include Articles if requested
        if ( $Param{Data}->{include}->{Articles} ) {
            my @ArticleIDs = $Kernel::OM->Get('Kernel::System::FAQ')->FAQSearch(
                CategoryIDs => [ $FAQCategoryID ],
                UserID       => $Self->{Authorization}->{UserID},
            );

            $FAQCategory{Articles} = \@ArticleIDs;
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
