# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::FAQ::FAQArticleCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use Kernel::API::Operation::V1::FAQ::FAQArticleAttachmentCreate;

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQArticleCreate - API Operation backend

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

    # get system LanguageIDs
    my $Languages = $Kernel::OM->Get('Kernel::Config')->Get('DefaultUsedLanguages');
    my @LanguageIDs = sort keys %{$Languages};

    return {
        'FAQArticle' => {
            Type     => 'HASH',
            Required => 1
        },
        'FAQArticle::CategoryID' => {
            Required => 1
        },            
        'FAQArticle::Title' => {
            Required => 1
        },
        'FAQArticle::CustomerVisible' => {
            RequiresValueIfUsed => 1,
            OneOf => [
                0,
                1
            ]
        },
        'FAQArticle::Language' => {
            RequiresValueIfUsed => 1,
            OneOf => \@LanguageIDs
        },
        'FAQArticle::Approved' => {
            RequiresValueIfUsed => 1,
            OneOf => [
                0,
                1
            ]
        },
    }
}

=item Run()

perform FAQArticleCreate Operation. This will return the created FAQArticleID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticle  => {
                Title           => 'Some Text',
                CategoryID      => 1,
                ValidID         => 1,
                CustomerVisible => 1,                # optional, 1|0, default 0
                Language        => 'en',             # optional, if not given set to DefaultLanguage with fallback 'en'
                ContentType     => 'text/plain',     # optional, if not given set to 'text/plain'
                Number          => '13402',          # optional
                Keywords        => [                 # optional
                    'some', 'keywords',  
                ]
                Field1      => 'Symptom...',     # optional
                Field2      => 'Problem...',     # optional
                Field3      => 'Solution...',    # optional
                Field4      => 'Field4...',      # optional
                Field5      => 'Field5...',      # optional
                Field6      => 'Comment...',     # optional
                Approved    => 1,                # optional
                Attachments => [                 # optional
                    {
                        Content     => $Content,
                        ContentType => 'text/xml',
                        Filename    => 'somename.xml',
                        Inline      => 1,   (0|1, default 0)
                    },
                    # ...
                ],                    
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            FAQArticleID   => 123,                     # ID of created FAQArticle
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim FAQArticle parameter
    my $FAQArticle = $Self->_Trim(
        Data => $Param{Data}->{FAQArticle}
    );
    
    # everything is ok, let's create the FAQArticle
    my $FAQArticleID = $Kernel::OM->Get('Kernel::System::FAQ')->FAQAdd(
        Title       => $FAQArticle->{Title},
        CategoryID  => $FAQArticle->{CategoryID},
        Visibility  => exists $FAQArticle->{CustomerVisible} && $FAQArticle->{CustomerVisible} ? 'external' : 'internal',
        Language    => $FAQArticle->{Language} || 'en',
        Number      => $FAQArticle->{Number} || '',
        Keywords    => IsArrayRefWithData($FAQArticle->{Keywords}) ? join(' ', @{$FAQArticle->{Keywords}}) : '',
        Field1      => $FAQArticle->{Field1} || '',
        Field2      => $FAQArticle->{Field2} || '',
        Field3      => $FAQArticle->{Field3} || '',
        Field4      => $FAQArticle->{Field4} || '',
        Field5      => $FAQArticle->{Field5} || '',
        Field6      => $FAQArticle->{Field6} || '',
        Approved    => $FAQArticle->{Approved} || 0,
        ValidID     => $FAQArticle->{ValidID} || 1,
        ContentType => $FAQArticle->{ContentType} || 'text/plain',
        UserID      => $Self->{Authorization}->{UserID},
    );

    if ( !$FAQArticleID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create FAQArticle, please contact the system administrator',
        );
    }

    # create new attachment
    if ( IsArrayRefWithData($FAQArticle->{Attachments}) ) {
        foreach my $Attachment ( @{$FAQArticle->{Attachments}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::FAQ::FAQArticleAttachmentCreate',
                Data          => {
                    FAQArticleID => $FAQArticleID,
                    Attachment   => $Attachment,
                }
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    %{$Result},
                )
            }
        }
    }

    return $Self->_Success(
        Code         => 'Object.Created',
        FAQArticleID => $FAQArticleID,
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
