# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleCreate - API Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ArticleCreate');

    return $Self;
}

=item Run()

perform ArticleCreate Operation. This will return the created ArticleID.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID => 123                                                    # required
            Article  => {                                                      # required
                Subject                         => 'some subject',             # required
                Body                            => 'some body'                 # required
                ContentType                     => 'some content type',        # ContentType or MimeType and Charset is requieed
                MimeType                        => 'some mime type',           
                Charset                         => 'some charset',           

                ArticleTypeID                   => 123,                        # optional
                ArticleType                     => 'some article type name',   # optional
                SenderTypeID                    => 123,                        # optional
                SenderType                      => 'some sender type name',    # optional
                AutoResponseType                => 'some auto response type',  # optional
                From                            => 'some from string',         # optional
                HistoryType                     => 'some history type',        # optional
                HistoryComment                  => 'Some  history comment',    # optional
                TimeUnit                        => 123,                        # optional
                NoAgentNotify                   => 1,                          # optional
                ForceNotificationToUserID       => [1, 2, 3]                   # optional
                ExcludeNotificationToUserID     => [1, 2, 3]                   # optional
                ExcludeMuteNotificationToUserID => [1, 2, 3]                   # optional
                Attachments => [
                    {
                        Content     => 'content'                               # base64 encoded
                        ContentType => 'some content type'
                        Filename    => 'some fine name'
                    },
                    # ...
                ],                    
                DynamicFields => [                                                     # optional
                    {
                        Name   => 'some name',                                          
                        Value  => $Value,                                              # value type depends on the dynamic field
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
            ArticleID   => 123,                     # ID of created article
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

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'TicketID' => {
                Required => 1
            },
            'Article' => {
                Type     => 'HASH',
                Required => 1
            },
            'Article::Subject' => {
                Required => 1
            },
            'Article::Body' => {
                Required => 1
            },
            'Article::ContentType' => {
                RequiredIfNot => [ 'Article::MimeType', 'Article::Charset' ],
            },
            'Article::MimeType' => {
                RequiredIfNot => [ 'Article::ContentType' ],
                RequiredIf    => [ 'Article::Charset' ],
            },
            'Article::Charset' => {
                RequiredIfNot => [ 'Article::ContentType' ],
                RequiredIf    => [ 'Article::MimeType' ],
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

   my $PermissionUserID = $Self->{Authorization}->{UserID};
    if ( $Self->{Authorization}->{UserType} eq 'Customer' ) {
        $PermissionUserID = $Kernel::OM->Get('Kernel::Config')->Get('CustomerPanelUserID')
    }

    # check write permission
    my $Permission = $Self->CheckWritePermission(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to create article for ticket $Param{Data}->{TicketID}!",
        );
    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{Data}->{TicketID},
    );

    if ( !%Ticket ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Ticket $Param{Data}->{TicketID} not found!",
        );
    }

    # isolate Article parameter
    my $Article = $Param{Data}->{Article};

    # add UserType to Validate ArticleType
    $Article->{UserType} = $Self->{Authorization}->{UserType};

    # set defaults from operation config
    if ( !$Article->{AutoResponseType} ) {
        $Article->{AutoResponseType} = $Self->{Config}->{AutoResponseType} || '';
    }
    if ( !$Article->{ArticleTypeID} && !$Article->{ArticleType} ) {
        $Article->{ArticleType} = $Self->{Config}->{ArticleType} || '';
    }
    if ( !$Article->{SenderTypeID} && !$Article->{SenderType} ) {
        $Article->{SenderType} = lc($Self->{Authorization}->{UserType});
    }
    if ( !$Article->{HistoryType} ) {
        $Article->{HistoryType} = $Self->{Config}->{HistoryType} || '';
    }
    if ( !$Article->{HistoryComment} ) {
        $Article->{HistoryComment} = $Self->{Config}->{HistoryComment} || '';
    }

    # check Article attribute values
    my $ArticleCheck = $Self->_CheckArticle( 
        Article => $Article 
    );

    if ( !$ArticleCheck->{Success} ) {
        return $Self->_Error(
            %{$ArticleCheck},
        );
    }

    # everything is ok, let's create the article
    return $Self->_ArticleCreate(
        Ticket   => \%Ticket,
        Article  => $Article,
        UserID   => $PermissionUserID,
    );
}

=begin Internal:

=item _ArticleCreate()

creates a ticket with its article and sets dynamic fields and attachments if specified.

    my $Response = $OperationObject->_ArticleCreate(
        Ticket       => $Ticket,                  
        Article      => $Article,                 
        UserID       => 123,
    );

    returns:

    $Response = {
        Success => 1,                               # if everything is OK
        Data => {
            ArticleID  => 123,
        }
    }

    $Response = {
        Success => 0,                         # if unexpected error
        Code    => '...',  
        Message => '...'
    }

=cut

sub _ArticleCreate {
    my ( $Self, %Param ) = @_;

    my $Ticket           = $Param{Ticket};
    my $Article          = $Param{Article};

    # get customer information
    # with information will be used to create the ticket if customer is not defined in the
    # database, customer ticket information need to be empty strings
    my %CustomerUserData = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerUserDataGet(
        User => $Ticket->{CustomerUser},
    );

    my $CustomerID = $CustomerUserData{UserCustomerID} || '';

    # use user defined CustomerID if defined
    if ( defined $Ticket->{CustomerID} && $Ticket->{CustomerID} ne '' ) {
        $CustomerID = $Ticket->{CustomerID};
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    my $OwnerID;
    if ( $Ticket->{Owner} && !$Ticket->{OwnerID} ) {
        my %OwnerData = $UserObject->GetUserData(
            User => $Ticket->{Owner},
        );
        $OwnerID = $OwnerData{UserID};
    }
    elsif ( defined $Ticket->{OwnerID} ) {
        $OwnerID = $Ticket->{OwnerID};
    }

    my $ResponsibleID;
    if ( $Ticket->{Responsible} && !$Ticket->{ResponsibleID} ) {
        my %ResponsibleData = $UserObject->GetUserData(
            User => $Ticket->{Responsible},
        );
        $ResponsibleID = $ResponsibleData{UserID};
    }
    elsif ( defined $Ticket->{ResponsibleID} ) {
        $ResponsibleID = $Ticket->{ResponsibleID};
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    if ( !defined $Article->{NoAgentNotify} ) {

        # check if new owner is given (then send no agent notify)
        $Article->{NoAgentNotify} = 0;
        if ($OwnerID) {
            $Article->{NoAgentNotify} = 1;
        }
    }

    # set Article From
    my $From;
    if ( $Article->{From} ) {
        $From = $Article->{From};
    }
    # use data from customer user (if customer user is in database)
    elsif ( IsHashRefWithData( \%CustomerUserData ) ) {
        $From = '"' . $CustomerUserData{UserFirstname} . ' ' . $CustomerUserData{UserLastname} . '"'
            . ' <' . $CustomerUserData{UserEmail} . '>';
    }
    # otherwise use customer user as sent from the request (it should be an email)
    else {
        $From = $Ticket->{CustomerUser};
    }

    # set Article To
    my $To;
    if ( $Ticket->{Queue} ) {
        $To = $Ticket->{Queue};
    }
    else {
        $To = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
            QueueID => $Ticket->{QueueID},
        );
    }

    # create article
    my $ArticleID = $TicketObject->ArticleCreate(
        NoAgentNotify  => $Article->{NoAgentNotify}  || 0,
        TicketID       => $Ticket->{TicketID},
        ArticleTypeID  => $Article->{ArticleTypeID}  || '',
        ArticleType    => $Article->{ArticleType}    || '',
        SenderTypeID   => $Article->{SenderTypeID}   || '',
        SenderType     => $Article->{SenderType}     || '',
        From           => $From,
        To             => $To,
        Subject        => $Article->{Subject},
        Body           => $Article->{Body},
        MimeType       => $Article->{MimeType}       || '',
        Charset        => $Article->{Charset}        || '',
        ContentType    => $Article->{ContentType}    || '',
        UserID         => $Param{UserID},
        HistoryType    => $Article->{HistoryType},
        HistoryComment => $Article->{HistoryComment} || '%%',
        AutoResponseType => $Article->{AutoResponseType},
        OrigHeader       => {
            From    => $From,
            To      => $To,
            Subject => $Article->{Subject},
            Body    => $Article->{Body},

        },
    );

    if ( !$ArticleID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create article, please contact the system administrator',
        );
    }

    # time accounting
    if ( $Article->{TimeUnit} ) {
        $TicketObject->TicketAccountTime(
            TicketID  => $Ticket->{TicketID},
            ArticleID => $ArticleID,
            TimeUnit  => $Article->{TimeUnit},
            UserID    => $Param{UserID},
        );
    }

    # set dynamic fields
    if ( IsArrayRefWithData($Article->{DynamicFields}) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{$Article->{DynamicFields}} ) {

            my $IsArticleDynamicField = $Self->ValidateDynamicFieldObjectType(
                %{$DynamicField},
                Article => 1,
            );
            next DYNAMICFIELD if !$IsArticleDynamicField;

            my $Result = $Self->SetDynamicFieldValue(
                %{$DynamicField},
                TicketID  => $Ticket->{TicketID},
                ArticleID => $ArticleID,
                UserID    => $Param{UserID},
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    Code    => 'Operation.InternalError',
                    Message => "Dynamic Field $DynamicField->{Name} could not be set, please contact the system administrator",
                );
            }
        }
    }

    # set attachments
    if ( IsArrayRefWithData($Article->{Attachments}) ) {

        foreach my $Attachment ( @{$Article->{Attachments}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::Ticket::ArticleAttachmentCreate',
                Data          => {
                    TicketID   => $Ticket->{TicketID},
                    ArticleID  => $ArticleID,
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

    return $Self->_Success(
        Code         => 'Object.Created',
        ArticleID    => $ArticleID,
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
