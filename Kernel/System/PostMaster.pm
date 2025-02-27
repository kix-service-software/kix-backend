# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster;

use strict;
use warnings;

use Kernel::System::EmailParser;
use Kernel::System::PostMaster::DestQueue;
use Kernel::System::PostMaster::NewTicket;
use Kernel::System::PostMaster::FollowUp;
use Kernel::System::PostMaster::Reject;

use Kernel::System::VariableCheck qw(IsHashRefWithData);

our @ObjectDependencies = (
    'Config',
    'DynamicField',
    'Log',
    'Main',
    'Queue',
    'State',
    'Ticket',
    'SystemAddress',
);

=head1 NAME

Kernel::System::PostMaster - postmaster lib

=head1 SYNOPSIS

All postmaster functions. E. g. to process emails.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'PostMaster' => {
            Email        => \@ArrayOfEmailContent,
            Trusted      => 1, # 1|0 ignore X-KIX header if false
        },
    );
    my $PostMasterObject = $Kernel::OM->Get('PostMaster');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    $Self->{Email} = $Param{Email} || die "Got no Email!";

    # for debug 0=off; 1=info; 2=on; 3=with GetHeaderParam;
    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{ParserObject} = Kernel::System::EmailParser->new(
        Email => $Param{Email},
    );

    # create needed objects
    $Self->{DestQueueObject} = Kernel::System::PostMaster::DestQueue->new( %{$Self} );
    $Self->{NewTicketObject} = Kernel::System::PostMaster::NewTicket->new( %{$Self} );
    $Self->{FollowUpObject}  = Kernel::System::PostMaster::FollowUp->new( %{$Self} );
    $Self->{RejectObject}    = Kernel::System::PostMaster::Reject->new( %{$Self} );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # check needed config options
    for my $Option (qw(PostmasterUserID PostmasterX-Header)) {
        $Self->{$Option} = $ConfigObject->Get($Option)
            || die "Found no '$Option' option in configuration!";
    }

    # should I use x-kix headers?
    $Self->{Trusted} = defined $Param{Trusted} ? $Param{Trusted} : 1;

    if ( $Self->{Trusted} ) {

        # get dynamic field objects
        my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');

        # add Dynamic Field headers
        my $DynamicFields = $DynamicFieldObject->DynamicFieldList(
            Valid      => 1,
            ObjectType => [ 'Ticket', 'Article' ],
            ResultType => 'HASH',
        );

        # create a lookup table
        my %HeaderLookup = map { $_ => 1 } @{ $Self->{'PostmasterX-Header'} };

        for my $DynamicField ( values %$DynamicFields ) {
            for my $Header (
                'X-KIX-DynamicField-' . $DynamicField,
                'X-KIX-DynamicField_' . $DynamicField,   # except also underline
                'X-KIX-FollowUp-DynamicField-' . $DynamicField,
                'X-KIX-FollowUp-DynamicField_' . $DynamicField,   # except also underline
                )
            {

                # only add the header if is not alreday in the conifg
                if ( !$HeaderLookup{$Header} ) {
                    push @{ $Self->{'PostmasterX-Header'} }, $Header;
                }
            }
        }
    }

    return $Self;
}

=item Run()

to execute the run process

    $PostMasterObject->Run(
        Queue      => 'Junk',  # optional, specify target queue for new tickets
        QueueID    => 1,       # optional, specify target queue for new tickets
        FileIngest => 0,       # optional, defaults to 0, only used for mail ingest from console
    );

return params

    0 = error (also false)
    1 = new ticket created
    2 = follow up / open/reopen
    3 = follow up / close -> new ticket
    4 = follow up / close -> reject
    5 = ignored (because of X-KIX-Ignore header)

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $ConfigObject        = $Kernel::OM->Get('Config');
    my $QueueObject         = $Kernel::OM->Get('Queue');
    my $StateObject         = $Kernel::OM->Get('State');
    my $SystemAddressObject = $Kernel::OM->Get('SystemAddress');
    my $TicketObject        = $Kernel::OM->Get('Ticket');

    my @Return;

    # ConfigObject section / get params
    my $GetParam = $Self->GetEmailParams();

    $GetParam->{From} = $GetParam->{From} || $GetParam->{'MAIL FROM'} || $GetParam->{'X-KIX-From'};

    if (!$GetParam->{From}) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Headers 'From', 'MAIL FROM' or 'X-KIX-From' are missing. At least one of them must be set to ingest a mail. ",
        );
        return;
    }

    # get tickets containing this message
    my @SkipTicketIDs = qw{};
    if( $GetParam->{'Message-ID'} ) {
        @SkipTicketIDs = $TicketObject->ArticleGetTicketIDsOfMessageID(
            MessageID => $GetParam->{'Message-ID'},
        );
    }
    my %SkipTicketIDHash = ();
    for my $TicketID ( @SkipTicketIDs ) {
        $SkipTicketIDHash{$TicketID} = 1;
    }

    # check if follow up
    my %FollowUps = $Self->CheckFollowUp( GetParam => $GetParam );

    # run all PreFilterModules (modify email params)
    if ( ref $ConfigObject->Get('PostMaster::PreFilterModule') eq 'HASH' ) {

        my %Jobs = %{ $ConfigObject->Get('PostMaster::PreFilterModule') };

        # get main objects
        my $MainObject = $Kernel::OM->Get('Main');

        JOB:
        for my $Job ( sort keys %Jobs ) {
            next JOB if (
                ref( $Jobs{ $Job } ) ne 'HASH'
                || !$Jobs{$Job}->{Module}
            );

            return if !$MainObject->Require( $Jobs{$Job}->{Module} );

            my $FilterObject = $Jobs{$Job}->{Module}->new(
                %{$Self},
            );

            if ( !$FilterObject ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "new() of PreFilterModule $Jobs{$Job}->{Module} not successfully!",
                );
                next JOB;
            }

            # modify params
            if( scalar( keys %FollowUps ) ) {
                for my $TN (keys %FollowUps) {
                    my $TicketID = $FollowUps{$TN};

                    my $Run = $FilterObject->Run(
                        GetParam  => $GetParam,
                        JobConfig => $Jobs{$Job},
                        TicketID  => $TicketID,
                    );
                    if ( !$Run ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message => "Execute Run() of PreFilterModule "
                                . "$Jobs{$Job}->{Module} with TID $TicketID "
                                . "not successfully!",
                        );
                    }
                }
            }
            else {
                my $Run = $FilterObject->Run(
                    GetParam  => $GetParam,
                    JobConfig => $Jobs{$Job},
                    TicketID  => undef,
                );
                if ( !$Run ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message => "Execute Run() of PreFilterModule "
                            . "$Jobs{$Job}->{Module} not successfully!",
                    );
                }
            }
        }
    }

    # should I ignore the incoming mail?
    if ( $GetParam->{'X-KIX-Ignore'} && $GetParam->{'X-KIX-Ignore'} =~ /(yes|true)/i ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'info',
            Message =>
                "Ignored Email (From: $GetParam->{'From'}, Message-ID: $GetParam->{'Message-ID'}) "
                . "because the X-KIX-Ignore is set (X-KIX-Ignore: $GetParam->{'X-KIX-Ignore'})."
        );
        return ([5]);
    }

    # ----------------------
    # ticket section
    # ----------------------

    # check if follow up (again, with new GetParam)
    %FollowUps = $Self->CheckFollowUp( GetParam => $GetParam );

    if (
        $Param{Queue}
        && !$Param{QueueID}
    ) {
        # queue lookup if queue name is given
        $Param{QueueID} = $QueueObject->QueueLookup(
            Queue => $Param{Queue},
        );
    }

    if (
        $ConfigObject->Get('PostMaster::StrictFollowUp')
        && !$GetParam->{'X-KIX-StrictFollowUpIgnore'}
    ) {
        # get recipients
        my $Recipient = '';
        for my $Key (qw(Resent-To Envelope-To To Cc Bcc Delivered-To X-Original-To)) {
            next if !$GetParam->{$Key};
            if ($Recipient) {
                $Recipient .= ', ';
            }
            $Recipient .= $GetParam->{$Key};
        }

        # get addresses
        my @EmailAddresses = $Self->{ParserObject}->SplitAddressLine(
            Line => $Recipient
        );

        # filter email addresses avoiding repeated and save in a hash
        my %EmailsHash = ();
        for my $EmailAddress (@EmailAddresses) {
            my $MailAddress = $Self->{ParserObject}->GetEmailAddress(
                Email => $EmailAddress
            );
            next if ( !$MailAddress );

            $MailAddress =~ s/("|')//g;

            $EmailsHash{$MailAddress} = '1';
        }

        # check addresses
        EMAIL:
        for my $Address ( sort( keys( %EmailsHash ) ) ) {
            next EMAIL if !$Address;

            # lookup if address is known system address
            my $SystemAddressID = $SystemAddressObject->SystemAddressLookup(
                Name => $Address,
            );

            # get queues for possible follow up
            my %Queues;
            if ( $SystemAddressID ) {
                # get all queues that have this address as sender
                %Queues = $QueueObject->GetQueuesForEmailAddress(
                    AddressID => $SystemAddressID
                );
            }

            # determine queue for new ticket
            my $QueueID;
            if ( $SystemAddressID ) {
                $QueueID = $SystemAddressObject->SystemAddressQueueID(
                    Address => $Address,
                );
            }
            # not a system address, or system address has no queue => use provided queue
            if (
                !$QueueID
                && $Param{QueueID}
            ) {
                $QueueID = $Param{QueueID};
            }
             # no provided queue, or queue by system address. fallback to default queue
            elsif ( !$QueueID ) {
                my $QueueName = $ConfigObject->Get('PostmasterDefaultQueue');
                $QueueID = $QueueObject->QueueLookup(
                    Queue => $QueueName
                ) || 1;
            }

            # ensure that queue for new ticket is part of possible followup queues
            if (
                $QueueID
                && !$Queues{ $QueueID }
            ) {
                # lookup queue name
                my $QueueName = $QueueObject->QueueLookup(
                    QueueID => $QueueID
                );

                if ( $QueueName ) {
                    $Queues{$QueueID} = $QueueName;
                }
            }

            # check if the message should be added as FollowUp
            my $FollowUpAdded = 0;
            for my $Tn ( keys( %FollowUps ) ) {
                my @Result = $Self->_HandlePossibleFollowUp(
                    GetParam      => $GetParam,
                    TicketNumber  => $Tn,
                    TicketID      => $FollowUps{$Tn},
                    Queues        => \%Queues,
                    QueueID       => $QueueID,
                    SkipTicketIDs => \%SkipTicketIDHash
                );
                if ( @Result ) {
                    $FollowUpAdded = 1;
                    push (@Return, \@Result);
                }
            }
            # create new ticket if no FollowUp added
            if ( !$FollowUpAdded && $SystemAddressID ) {

                # check if trusted returns a new queue id
                my $TQueueID = $Self->{DestQueueObject}->GetTrustedQueueID(
                    Params => $GetParam,
                );
                if ($TQueueID) {
                    $QueueID = $TQueueID;
                }

                # create new ticket
                if ($QueueID) {
                    my @Result = $Self->{NewTicketObject}->Run(
                        InmailUserID  => $Self->{PostmasterUserID},
                        GetParam      => $GetParam,
                        QueueID       => $QueueID,
                        SkipTicketIDs => \%SkipTicketIDHash,
                        FileIngest    => $Param{FileIngest} || 0,
                    );

                    if ( @Result ) {
                        push (@Return, \@Result);
                    }
                }
            }
        }

        # create ticket in PostmasterDefaultQueue no new ticket created, no follow up added
        if ( !scalar(@Return) ) {

            # get queue if of From: and To:
            if ( !$Param{QueueID} ) {
                $Param{QueueID} = $Self->{DestQueueObject}->GetQueueID( Params => $GetParam );
            }

            # check if trusted returns a new queue id
            my $TQueueID = $Self->{DestQueueObject}->GetTrustedQueueID(
                Params => $GetParam,
            );
            if ($TQueueID) {
                $Param{QueueID} = $TQueueID;
            }
            my @Result = $Self->{NewTicketObject}->Run(
                InmailUserID     => $Self->{PostmasterUserID},
                GetParam         => $GetParam,
                QueueID          => $Param{QueueID},
                SkipTicketIDs    => \%SkipTicketIDHash,
            );

            if ( @Result ) {
                push (@Return, \@Result);
            }
        }
    } else {
        my %Queues = $QueueObject->QueueList( Valid => 1 );

        # check if the message should be added as FollowUp
        for my $Tn ( keys( %FollowUps ) ) {
            my @Result = $Self->_HandlePossibleFollowUp(
                GetParam      => $GetParam,
                TicketNumber  => $Tn,
                TicketID      => $FollowUps{$Tn},
                Queues        => \%Queues,
                QueueID       => $Param{QueueID},
                SkipTicketIDs => \%SkipTicketIDHash
            );
            if ( @Result ) {
                push (@Return, \@Result);
            }
        }

        # create ticket in PostmasterDefaultQueue no new ticket created, no follow up added
        if ( !scalar(@Return) ) {

            # get queue if of From: and To:
            if ( !$Param{QueueID} ) {
                $Param{QueueID} = $Self->{DestQueueObject}->GetQueueID( Params => $GetParam );
            }

            # check if trusted returns a new queue id
            my $TQueueID = $Self->{DestQueueObject}->GetTrustedQueueID(
                Params => $GetParam,
            );
            if ($TQueueID) {
                $Param{QueueID} = $TQueueID;
            }

            # create new ticket
            if ($Param{QueueID}) {
                my @Result = $Self->{NewTicketObject}->Run(
                    InmailUserID     => $Self->{PostmasterUserID},
                    GetParam         => $GetParam,
                    QueueID          => $Param{QueueID},
                    SkipTicketIDs    => \%SkipTicketIDHash,
                );

                if ( @Result ) {
                    push (@Return, \@Result);
                }
            }
        }
    }

    # run all PostFilterModules (modify email params)
    if ( ref $ConfigObject->Get('PostMaster::PostFilterModule') eq 'HASH' ) {

        my %Jobs = %{ $ConfigObject->Get('PostMaster::PostFilterModule') };

        # get main objects
        my $MainObject = $Kernel::OM->Get('Main');

        JOB:
        for my $Job ( sort keys %Jobs ) {

            return if !$MainObject->Require( $Jobs{$Job}->{Module} );

            my $FilterObject = $Jobs{$Job}->{Module}->new(
                %{$Self},
            );

            if ( !$FilterObject ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "new() of PostFilterModule $Jobs{$Job}->{Module} not successfully!",
                );
                next JOB;
            }

            for my $ReturnVal (@Return) {
                next if !$ReturnVal || ref($ReturnVal) ne 'ARRAY' || scalar( @{$ReturnVal} ) != 2;
                my $TicketID = $ReturnVal->[1];

                # modify params
                my $Run = $FilterObject->Run(
                    TicketID  => $TicketID,
                    GetParam  => $GetParam,
                    JobConfig => $Jobs{$Job},
                );

                if ( !$Run ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message =>
                            "Execute Run() of PostFilterModule $Jobs{$Job}->{Module} not successfully!",
                    );
                }
            }
        }
    }

    return @Return;
}

=item CheckFollowUp()

to detect the ticket number in processing email

    my ($TicketNumber, $TicketID) = $PostMasterObject->CheckFollowUp(
        Subject => 'Re: [Ticket:#123456] Some Subject',
    );

=cut

sub CheckFollowUp {
    my ( $Self, %Param ) = @_;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # get config objects
    my $ConfigObject = $Kernel::OM->Get('Config');

    # build Result hash with TicketNumber => TicketID pairs
    my %Result = ();

    # Load CheckFollowUp Modules
    my $Jobs = $ConfigObject->Get('PostMaster::CheckFollowUpModule');

    if ( IsHashRefWithData($Jobs) ) {
        my $MainObject = $Kernel::OM->Get('Main');
        JOB:
        for my $Job ( sort keys %$Jobs ) {
            my $Module = $Jobs->{$Job};

            return if !$MainObject->Require( $Jobs->{$Job}->{Module} );

            my $CheckObject = $Jobs->{$Job}->{Module}->new(
                %{$Self},
            );

            if ( !$CheckObject ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "new() of CheckFollowUp $Jobs->{$Job}->{Module} not successfully!",
                );
                next JOB;
            }
            my $Match = 0;
            my @TnArray = $CheckObject->Run(%Param);
            if (@TnArray) {
                TN:
                for my $TicketNumber (@TnArray) {
                    # check if it's a valid ticket number
                    my $TicketID = $TicketObject->TicketCheckNumber( Tn => $TicketNumber );
                    next TN if ( !$TicketID );

                    # remember match
                    $Match = 1;

                    # add ticket to the Result if still not there
                    if ( !$Result{ $TicketNumber } ) {
                        $Result{ $TicketNumber } = $TicketID;
                    }
                    if ($Jobs->{$Job}->{OnlyFirstMatch}) {
                        last TN;
                    }
                }
            }
            if (
                $Match
                && $Jobs->{$Job}->{StopAfterMatch}
            ) {
                return %Result;
            }
        }
    }

    return %Result;
}

=item GetEmailParams()

to get all configured PostmasterX-Header email headers

    my %Header = $PostMasterObject->GetEmailParams();

=cut

sub GetEmailParams {
    my ( $Self, %Param ) = @_;

    my %GetParam;

    # parse section
    HEADER:
    for my $Param ( @{ $Self->{'PostmasterX-Header'} } ) {

        # do not scan x-kix headers if mailbox is not marked as trusted
        next HEADER if ( !$Self->{Trusted} && $Param =~ /^x-kix/i );
        if ( $Self->{Debug} > 2 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "$Param: " . $Self->{ParserObject}->GetParam( WHAT => $Param ),
            );
        }
        $GetParam{$Param} = $Self->{ParserObject}->GetParam( WHAT => $Param );
    }

    my $Received = $Self->{ParserObject}->GetParam( WHAT => 'Received' );
    if ( $Received =~ /.*for\s*<([^>]+)>.*/i ) {
        $GetParam{'Bcc'} = $Self->{ParserObject}->GetEmailAddress(
            Email => $1,
        );
    }

    # set compat. headers
    if ( $GetParam{'Message-Id'} ) {
        $GetParam{'Message-ID'} = $GetParam{'Message-Id'};
    }
    if ( $GetParam{'Reply-To'} ) {
        $GetParam{'ReplyTo'} = $GetParam{'Reply-To'};
    }
    if ( !$GetParam{'X-Sender'} ) {

        # get sender email
        my @EmailAddresses = $Self->{ParserObject}->SplitAddressLine(
            Line => $GetParam{From},
        );
        for my $Email (@EmailAddresses) {
            $GetParam{'X-Sender'} = $Self->{ParserObject}->GetEmailAddress(
                Email => $Email,
            );
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # check sender type - if not given use external (check for follow up is done in FollowUp module!)
    for my $Key (qw(X-KIX-SenderType)) {
        if ( !$GetParam{$Key} ) {
            $GetParam{$Key} = 'external';
        }

        # check if X-KIX-SenderType exists, if not, set external
        if ( !$TicketObject->ArticleSenderTypeLookup( SenderType => $GetParam{$Key} ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't find sender type '$GetParam{$Key}' in db, take 'external'",
            );
            $GetParam{$Key} = 'external';
        }
    }

    # set article type if not given
    for my $Key (qw(X-KIX-Channel X-KIX-FollowUp-Channel)) {
        if ( !$GetParam{$Key} ) {
            $GetParam{$Key} = 'email';
        }

        # check if X-KIX-Channel exists, if not, set 'email'
        if ( !$Kernel::OM->Get('Channel')->ChannelLookup( Name => $GetParam{$Key} ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't find channel '$GetParam{$Key}' in db, take 'email' and set 'visible for customer'",
            );
            $GetParam{$Key} = 'email';
        }
    }

    # Checks whether there is a decryption problem, if so, then the article content is changed.
    if ( $Self->{ParserObject}->GetParam( WHAT => 'DecryptErr' ) ) {
        # get body
        $GetParam{Body} = 'Could not decrypt message';

        # get content type
        $GetParam{'Content-Type'} = 'text/plain';
        $GetParam{Charset} = 'utf-8';
    }
    else {
        # get body
        $GetParam{Body} = $Self->{ParserObject}->GetMessageBody();

        # get attachments
        my @Attachments = $Self->{ParserObject}->GetAttachments();
        $GetParam{Attachment} = \@Attachments;

        # get content type
        $GetParam{'Content-Type'} = $Self->{ParserObject}->GetReturnContentType();
        $GetParam{Charset} = $Self->{ParserObject}->GetReturnCharset();
    }

    return \%GetParam;
}

sub _HandlePossibleFollowUp {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $ConfigObject = $Kernel::OM->Get('Config');
    my $QueueObject  = $Kernel::OM->Get('Queue');
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # check if it's a follow up ...
    if ( ref $ConfigObject->Get('PostMaster::PreCreateFilterModule') eq 'HASH' ) {

        my %Jobs = %{ $ConfigObject->Get('PostMaster::PreCreateFilterModule') };

        my $MainObject = $Kernel::OM->Get('Main');

        JOB:
        for my $Job ( sort keys %Jobs ) {

            return if !$MainObject->Require( $Jobs{$Job}->{Module} );

            my $FilterObject = $Jobs{$Job}->{Module}->new(
                %{$Self},
            );

            if ( !$FilterObject ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "new() of PreCreateFilterModule $Jobs{$Job}->{Module} not successfully!",
                );
                next JOB;
            }

            # modify params
            my $Run = $FilterObject->Run(
                GetParam  => $Param{GetParam},
                JobConfig => $Jobs{$Job},
                TicketID  => $Param{TicketID},
            );
            if ( !$Run ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Execute Run() of PreCreateFilterModule $Jobs{$Job}->{Module} not successfully!",
                );
            }
        }
    }

    # check if it's a follow up ...
    if ( $Param{TicketNumber} && $Param{TicketID} ) {

        # get ticket data
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
        );

        if ( !$Param{Queues}->{ $Ticket{QueueID} } ) {
            return;
        }

        # skip followup if ticket already has message
        if (
            $Param{SkipTicketIDs}
            && ref( $Param{SkipTicketIDs} ) eq 'HASH'
            && $Param{SkipTicketIDs}->{ $Param{TicketID} }
        ) {
            my $MessageID = $Param{GetParam}->{'Message-ID'};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Follow up for [$Param{TicketNumber}], but message id already exists ($MessageID). Followup is skipped."
            );
            return (6, $Param{TicketID});
        }

        # check if it is possible to do the follow up
        # get follow up option (possible or not)
        my $FollowUpPossible = $QueueObject->GetFollowUpOption(
            QueueID => $Ticket{QueueID},
        );

        # get lock option (should be the ticket locked - if closed - after the follow up)
        my $Lock = $QueueObject->GetFollowUpLockOption(
            QueueID => $Ticket{QueueID},
        );

        # get state details
        my %State = $Kernel::OM->Get('State')->StateGet(
            ID => $Ticket{StateID},
        );

        # create a new ticket
        if ( $FollowUpPossible =~ /new ticket/i && $State{TypeName} =~ /^(removed|close)/i ) {

            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Follow up for [$Param{TicketNumber}] but follow up not possible ($Ticket{State})."
                    . " Create new ticket."
            );

            # send mail && create new article
            # get queue if of From: and To:
            if ( !$Param{QueueID} ) {
                $Param{QueueID} = $Self->{DestQueueObject}->GetQueueID(
                    Params => $Param{GetParam},
                );
            }

            # check if trusted returns a new queue id
            my $TQueueID = $Self->{DestQueueObject}->GetTrustedQueueID(
                Params => $Param{GetParam},
            );
            if ($TQueueID) {
                $Param{QueueID} = $TQueueID;
            }

            # Clean out the old TicketNumber from the subject (see bug#9108).
            # This avoids false ticket number detection on customer replies.
            if ( $Param{GetParam}->{Subject} ) {
                $Param{GetParam}->{Subject} = $TicketObject->TicketSubjectClean(
                    TicketNumber => $Param{TicketNumber},
                    Subject      => $Param{GetParam}->{Subject},
                );
            }

            my @Result = $Self->{NewTicketObject}->Run(
                InmailUserID     => $Self->{PostmasterUserID},
                GetParam         => $Param{GetParam},
                QueueID          => $Param{QueueID},
                Comment          => "Because the old ticket [$Param{TicketNumber}] is '$State{Name}'",
                LinkToTicketID   => $Param{TicketID},
            );

            if ( @Result ) {
                return ( 3, $Result[1] );
            }

        }

        # reject follow up
        elsif ( $FollowUpPossible =~ /reject/i && $State{TypeName} =~ /^(removed|close)/i ) {

            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Follow up for [$Param{TicketNumber}] but follow up not possible. Follow up rejected."
            );

            # send reject mail && and add article to ticket
            my $Run = $Self->{RejectObject}->Run(
                TicketID         => $Param{TicketID},
                InmailUserID     => $Self->{PostmasterUserID},
                GetParam         => $Param{GetParam},
                Lock             => $Lock,
                Tn               => $Param{TicketNumber},
                Comment          => 'Follow up rejected.',
            );

            if ( !$Run ) {
                return;
            }

            return ( 4, $Param{TicketID} );
        } else  {

            my $Run = $Self->{FollowUpObject}->Run(
                TicketID         => $Param{TicketID},
                InmailUserID     => $Self->{PostmasterUserID},
                GetParam         => $Param{GetParam},
                Lock             => $Lock,
                Tn               => $Param{TicketNumber},
            );

            if ( !$Run ) {
                return;
            }

            # remember created followup
            $Param{SkipTicketIDs}->{ $Param{TicketID} } = 1;

            return ( 2, $Param{TicketID} );
        }
    }

    return;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
