# --
# Kernel/API/Operation/FAQ/FAQArticleCreate.pm - API FAQCategory Create operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQArticleCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

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

=item Run()

perform FAQArticleCreate Operation. This will return the created FAQArticleID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQArticle  => {
                Title       => 'Some Text',
                StateID     => 1,
                LanguageID  => 1,
                Number      => '13402',          # (optional)
                Keywords    => 'some keywords',  # (optional)
                Field1      => 'Symptom...',     # (optional)
                Field2      => 'Problem...',     # (optional)
                Field3      => 'Solution...',    # (optional)
                Field4      => 'Field4...',      # (optional)
                Field5      => 'Field5...',      # (optional)
                Field6      => 'Comment...',     # (optional)
                Approved    => 1,                # (optional)
                ValidID     => 1,
                ContentType => 'text/plain',     # or 'text/html'
                Attachments => [
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

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }
use Data::Dumper;
print STDERR "param".Dumper(\%Param);
    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'FAQArticle' => {
                Type     => 'HASH',
                Required => 1
            },
            'FAQArticle::Title' => {
                Required => 1
            },
            'FAQArticle::StateID' => {
                Required => 1
            },
            'FAQArticle::LanguageID' => {
                Required => 1
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # check create permissions
    my $Permission = $Self->CheckCreatePermission(
        FAQArticle => $Param{Data}->{FAQArticle},
        UserID     => $Self->{Authorization}->{UserID},
        UserType   => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to create tickets in given queue!",
        );
    }
    # isolate FAQArticle parameter

    my $FAQArticle = $Self->_Trim(
        Data => $Param{Data}->{FAQArticle},
    );        
use Data::Dumper;
print STDERR "param2".Dumper($FAQArticle);
    # everything is ok, let's create the FAQArticle
    my $FAQArticleID = $Kernel::OM->Get('Kernel::System::FAQ')->FAQAdd(
        Title       => $FAQArticle->{Title},
        CategoryID  => $Param{Data}->{FAQCategoryID},
        StateID     => $FAQArticle->{StateID},
        LanguageID  => $FAQArticle->{LanguageID},
        Number      => $FAQArticle->{Number} || '',
        Keywords    => $FAQArticle->{Keywords} || '',
        Field1      => $FAQArticle->{Field1} || '',
        Field2      => $FAQArticle->{Field2} || '',
        Field3      => $FAQArticle->{Field3} || '',
        Field4      => $FAQArticle->{Field4} || '',
        Field5      => $FAQArticle->{Field5} || '',
        Field6      => $FAQArticle->{Field6} || '',
        Approved    => $FAQArticle->{Approved} || 1,
        ValidID     => $FAQArticle->{ValidID} || 1,
        ContentType => $FAQArticle->{ContentType} || 'text/plain',
        UserID   => $Self->{Authorization}->{UserID},
    );

    if ( !$FAQArticleID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create FAQArticle, please contact the system administrator',
        );
    }

    # set attachments
    if ( IsArrayRefWithData($FAQArticle->{Attachments}) ) {
        foreach my $Attachment ( @{$FAQArticle->{Attachments}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::FAQ::FAQAttachmentCreate',
                Data          => {
                    FAQCategoryID  => $Param{Data}->{FAQCategoryID},
                    FAQArticleID  => $FAQArticleID,
                    Attachment => $Attachment,
                }
            );
            
            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    ${$Result},
                )
            }
        }
    }
    }

    return $Self->_Success(
        Code         => 'Object.Created',
        FAQArticleID    => $FAQArticleID,
    );

}


1;

=end Internal:




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
