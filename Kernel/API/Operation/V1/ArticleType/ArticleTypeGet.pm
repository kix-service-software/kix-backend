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
        'ArticleTypeID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }                
    }
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

    my @ArticleTypeList;

    # start loop
    foreach my $ArticleTypeID ( @{$Param{Data}->{ArticleTypeID}} ) {

        # get the ArticleType data
        my $ArticleTypeName = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleTypeLookup(
            ArticleTypeID => $ArticleTypeID,
        );

        if ( !$ArticleTypeName ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
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
