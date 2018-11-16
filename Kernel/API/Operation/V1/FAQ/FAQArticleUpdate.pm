# --
# Kernel/API/Operation/FAQ/FAQArticleUpdate.pm - API FAQArticle Update operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQArticleUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleUpdate - API FAQArticle Create Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::FAQArticleUpdate');

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
            Required => 1
        },      
    }
}

=item Run()

perform FAQArticleUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticleID => 123,
            FAQArticle  => {
                CategoryID  => 1,
                StateID     => 1,
                LanguageID  => 1,
                Approved    => 1,
                Keywords    => [                 # optional
                    'some', 'keywords',  
                ],
                ValidID     => 1,
                ContentType => 'text/plan',     # or 'text/html'
                Title       => 'Some Text',
                Field1      => 'Problem...',
                Field2      => 'Solution...',
                UserID      => 1,
                ApprovalOff => 1,               # optional, (if set to 1 approval is ignored. This is
                                                #   important when called from FAQInlineAttachmentURLUpdate)
            },
        },
    );

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            FAQArticleID  => 123,              # ID of the updated FAQArticle 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # check rw permissions
    my $Permission = $Kernel::OM->Get('Kernel::System::FAQ')->CheckCategoryUserPermission(
        CategoryID => $Param{Data}->{FAQCategoryID},
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( $Permission ne 'rw' ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to update FAQ article in given category!",
        );
    }

    # isolate and trim FAQArticle parameter
    my $FAQArticle = $Self->_Trim(
        Data => $Param{Data}->{FAQArticle}
    );

    # check if FAQArticle exists 
    my %FAQArticleData = $Kernel::OM->Get('Kernel::System::FAQ')->FAQGet(
        ItemID     => $Param{Data}->{FAQArticleID},
        ItemFields => 1,
        UserID     => $Self->{Authorization}->{UserID},
    );
 
    if ( !%FAQArticleData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update FAQ article. No FAQ article with ID '$Param{Data}->{FAQArticleID}' found.",
        );
    }

    # update FAQArticle
    my $Success = $Kernel::OM->Get('Kernel::System::FAQ')->FAQUpdate(
        ItemID => $Param{Data}->{FAQArticleID} || $FAQArticleData{FAQArticleID},
        StateID     => $FAQArticle->{StateID} || $FAQArticleData{StateID},
        CategoryID  => $FAQArticle->{FAQCategoryID} || $FAQArticleData{CategoryID},
        LanguageID  => $FAQArticle->{LanguageID} || $FAQArticleData{LanguageID},
        Keywords    => IsArrayRefWithData($FAQArticle->{Keywords}) ? join(' ', @{$FAQArticle->{Keywords}}) : $FAQArticleData{Keywords},
        Approved    => $FAQArticle->{Approved} || $FAQArticleData{Approved},
        ContentType => $FAQArticle->{ContentType} || $FAQArticleData{ContentType},
        Title       => $FAQArticle->{Title} || $FAQArticleData{Title},,
        Field1      => $FAQArticle->{Field1} || $FAQArticleData{Field1},
        Field2      => $FAQArticle->{Field2} || $FAQArticleData{Field2},
        ApprovalOff => $FAQArticle->{ApprovalOff} || $FAQArticleData{ApprovalOff} || 1, 
        ValidID     => $FAQArticle->{ValidID} || $FAQArticleData{ValidID},
        UserID      => $Self->{Authorization}->{UserID}
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Could not update FAQ article, please contact the system administrator',
        );
    }

    # return result    
    return $Self->_Success(
        FAQArticleID => $Param{Data}->{FAQArticleID},
    );    
}

1;
