# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::TemplateGenerator;

use strict;
use warnings;

use URI::Escape;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Contact',
    'DynamicField',
    'DynamicField::Backend',
    'Encode',
    'HTMLUtils',
    'Log',
    'Queue',
    'Salutation',
    'Signature',
    'StandardTemplate',
    'SystemAddress',
    'Ticket',
    'User',
    'Output::HTML::Layout',
    'JSON',

);

=head1 NAME

Kernel::System::TemplateGenerator - signature lib

=head1 SYNOPSIS

All signature functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{RichText} = $Kernel::OM->Get('Config')->Get('Frontend::RichText');

    # KIX4OTRS-capeIT
    $Self->{UserLanguage} = $Param{UserLanguage};
    # EO KIX4OTRS-capeIT

    return $Self;
}

=item Sender()

generate sender address (FROM string) for emails

    my $Sender = $TemplateGeneratorObject->Sender(
        QueueID    => 123,
        UserID     => 123,
    );

returns:

    John Doe at Super Support <service@example.com>

and it returns the quoted real name if necessary

    "John Doe, Support" <service@example.tld>

=cut

sub Sender {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw( UserID QueueID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get sender attributes
    my %Address = $Kernel::OM->Get('Queue')->GetSystemAddress(
        QueueID => $Param{QueueID},
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # check config for agent real name
    my $UseAgentRealName = $ConfigObject->Get('Ticket::DefineEmailFrom');
    if ( $UseAgentRealName && $UseAgentRealName =~ /^(AgentName|AgentNameSystemAddressName)$/ ) {

        # get data from current agent
        if ($Param{UserID}) {
            my %ContactData = $Self->{ContactObject}->ContactGet(
                UserID => $Param{UserID},
            );

            # set real name with user name
            if ($UseAgentRealName eq 'AgentName') {

                # check for user data
                if ($ContactData{Lastname} && $ContactData{Firstname}) {

                    # rewrite RealName
                    $Address{RealName} = "$ContactData{Firstname} $ContactData{Lastname}";
                }
            }

            # set real name with user name
            if ($UseAgentRealName eq 'AgentNameSystemAddressName') {

                # check for user data
                if ($ContactData{Lastname} && $ContactData{Firstname}) {

                    # rewrite RealName
                    my $Separator = ' ' . $ConfigObject->Get('Ticket::DefineEmailFromSeparator')
                        || '';
                    $Address{RealName} = $ContactData{Firstname} . ' ' . $ContactData{Lastname}
                        . $Separator . ' ' . $Address{RealName};
                }
            }
        }
    }

    # prepare realname quote
    if ( $Address{RealName} =~ /([.]|,|@|\(|\)|:)/ && $Address{RealName} !~ /^("|')/ ) {
        $Address{RealName} =~ s/"//g;    # remove any quotes that are already present
        $Address{RealName} = '"' . $Address{RealName} . '"';
    }
    my $Sender = "$Address{RealName} <$Address{Email}>";

    return $Sender;
}

=item Template()

generate template

    my $Template = $TemplateGeneratorObject->Template(
        TemplateID => 123
        TicketID   => 123,                  # Optional
        Data       => $ArticleHashRef,      # Optional
        UserID     => 123,
    );

Returns:

    $Template =>  'Some text';

=cut

sub Template {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TemplateID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Template = $Kernel::OM->Get('StandardTemplate')->StandardTemplateGet(
        ID => $Param{TemplateID},
    );

    # do text/plain to text/html convert
    if (
        $Self->{RichText}
        && $Template{ContentType} =~ /text\/plain/i
        && $Template{Template}
        )
    {
        $Template{ContentType} = 'text/html';
        $Template{Template}    = $Kernel::OM->Get('HTMLUtils')->ToHTML(
            String => $Template{Template},
        );
    }

    # do text/html to text/plain convert
    if (
        !$Self->{RichText}
        && $Template{ContentType} =~ /text\/html/i
        && $Template{Template}
        )
    {
        $Template{ContentType} = 'text/plain';
        $Template{Template}    = $Kernel::OM->Get('HTMLUtils')->ToAscii(
            String => $Template{Template},
        );
    }

    # get user language
    my $Language;
    if ( defined $Param{TicketID} ) {

        # get ticket data
        my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID => $Param{TicketID},
        );

        # get recipient
        my %User = $Kernel::OM->Get('Contact')->ContactGet(
            ID => $Ticket{ContactID},
        );
        $Language = $User{UserLanguage};
    }

    # if customer language is not defined, set default language
    $Language //= $Kernel::OM->Get('Config')->Get('DefaultLanguage') || 'en';

    # replace place holder stuff
    my @ListOfUnSupportedTag = qw/KIX_AGENT_SUBJECT KIX_AGENT_BODY KIX_CUSTOMER_BODY KIX_CUSTOMER_SUBJECT/;

    my $TemplateText = $Self->_RemoveUnSupportedTag(
        Text => $Template{Template} || '',
        ListOfUnSupportedTag => \@ListOfUnSupportedTag,
    );

    # replace place holder stuff
    $TemplateText = $Self->_Replace(
        RichText => $Self->{RichText},
        Text     => $TemplateText || '',
        TicketID => $Param{TicketID} || '',
        Data     => $Param{Data} || {},
        UserID   => $Param{UserID},
        Language => $Language,
    );

    return $TemplateText;
}

=item Attributes()

generate attributes

    my %Attributes = $TemplateGeneratorObject->Attributes(
        TicketID   => 123,
        ArticleID  => 123,
        ResponseID => 123
        UserID     => 123,
        Action     => 'Forward', # Possible values are Reply and Forward, Reply is default.
    );

returns
    StandardResponse
    Salutation
    Signature

=cut

sub Attributes {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID Data UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # get queue
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # prepare subject ...
    $Param{Data}->{Subject} = $TicketObject->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => $Param{Data}->{Subject} || '',
        Action       => $Param{Action} || '',
    );

    # get sender address
    $Param{Data}->{From} = $Self->Sender(
        QueueID => $Ticket{QueueID},
        UserID  => $Param{UserID},
    );

    return %{ $Param{Data} };
}

=item NotificationEvent()

replace all KIX placeholders in the notification body and subject

    my %NotificationEvent = $TemplateGeneratorObject->NotificationEvent(
        TicketID              => 123,
        Recipient             => $UserDataHashRef,          # Agent or Customer data get result
        Notification          => $NotificationDataHashRef,
        CustomerMessageParams => $ArticleHashRef,           # optional
        UserID                => 123,
    );

=cut

sub NotificationEvent {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Notification Recipient UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( !IsHashRefWithData( $Param{Notification} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Notification is invalid!",
        );
        return;
    }

    my %Notification = %{ $Param{Notification} };

    # exchanging original reference prevent it to grow up
    if ( ref $Param{CustomerMessageParams} && ref $Param{CustomerMessageParams} eq 'HASH' ) {
        my %LocalCustomerMessageParams = %{ $Param{CustomerMessageParams} };
        $Param{CustomerMessageParams} = \%LocalCustomerMessageParams;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # get ticket
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # get last article from customer
    my %Article = $TicketObject->ArticleLastCustomerArticle(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # get last article from agent
    my @ArticleBoxAgent = $TicketObject->ArticleGet(
        TicketID      => $Param{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    my %ArticleAgent;

    ARTICLE:
    for my $Article ( reverse @ArticleBoxAgent ) {

        next ARTICLE if $Article->{SenderType} ne 'agent';

        %ArticleAgent = %{$Article};

        last ARTICLE;
    }

    # get  HTMLUtils object
    my $HTMLUtilsObject = $Kernel::OM->Get('HTMLUtils');

    # set the accounted time as part of the articles information
    ARTICLE:
    for my $ArticleData ( \%Article, \%ArticleAgent ) {

        next ARTICLE if !$ArticleData->{ArticleID};

        # get accounted time
        my $AccountedTime = $TicketObject->ArticleAccountedTimeGet(
            ArticleID => $ArticleData->{ArticleID},
        );

        $ArticleData->{TimeUnit} = $AccountedTime;
    }

    # get system default language
    my $DefaultLanguage = $Kernel::OM->Get('Config')->Get('DefaultLanguage') || 'en';

    my $UserLanguage = $Param{Recipient}->{UserLanguage};
    if ( IsHashRefWithData($Param{Recipient}->{Preferences}) && $Param{Recipient}->{Preferences}->{UserLanguage} ) {
        $UserLanguage = $Param{Recipient}->{Preferences}->{UserLanguage};
    }

    my $Languages = [ $UserLanguage, $DefaultLanguage, 'en' ];

    my $Language;
    LANGUAGE:
    for my $Item ( @{$Languages} ) {
        next LANGUAGE if !$Item;
        next LANGUAGE if !$Notification{Message}->{$Item};

        # set language
        $Language = $Item;
        last LANGUAGE;
    }

    # if no language, then take the first one available
    if ( !$Language ) {
        my @NotificationLanguages = sort keys %{ $Notification{Message} };
        $Language = $NotificationLanguages[0];
    }

    # copy the correct language message attributes to a flat structure
    for my $Attribute (qw(Subject Body ContentType)) {
        $Notification{$Attribute} = $Notification{Message}->{$Language}->{$Attribute};
    }

    for my $Key (qw(From To Cc Subject Body ContentType Channel)) {
        if ( !$Param{CustomerMessageParams}->{$Key} ) {
            $Param{CustomerMessageParams}->{$Key} = $Article{$Key} || '';
        }
        chomp $Param{CustomerMessageParams}->{$Key};
    }

    # format body (only if longer the 86 chars)
    if ( $Param{CustomerMessageParams}->{Body} ) {
        if ( length $Param{CustomerMessageParams}->{Body} > 86 ) {
            my @Lines = split /\n/, $Param{CustomerMessageParams}->{Body};
            LINE:
            for my $Line (@Lines) {
                my $LineWrapped = $Line =~ s/(^>.+|.{4,86})(?:\s|\z)/$1\n/gm;

                next LINE if $LineWrapped;

                # if the regex does not match then we need
                # to add the missing new line of the split
                # else we will lose e.g. empty lines of the body.
                # (bug#10679)
                $Line .= "\n";
            }
            $Param{CustomerMessageParams}->{Body} = join '', @Lines;
        }
    }

    # KIX4OTRS-capeIT
    # get customer article data for replacing
    # (KIX_COMMENT and KIX_CUSTOMER_BODY and KIX_CUSTOMER_EMAIL could be the same)
    $Param{CustomerMessageParams}->{CustomerBody} = $Article{Body} || '';
    if (
        $Param{CustomerMessageParams}->{CustomerBody}
        && length $Param{CustomerMessageParams}->{CustomerBody} > 86
        )
    {
        $Param{CustomerMessageParams}->{CustomerBody} =~ s/(^>.+|.{4,86})(?:\s|\z)/$1\n/gm;
    }

    # EO KIX4OTRS-capeIT

    # fill up required attributes
    for my $Text (qw(Subject Body)) {
        if ( !$Param{CustomerMessageParams}->{$Text} ) {
            $Param{CustomerMessageParams}->{$Text} = "No $Text";
        }
    }

    my $Start = '<';
    my $End   = '>';
    if ( $Notification{ContentType} =~ m{text\/html} ) {
        $Start = '&lt;';
        $End   = '&gt;';
    }

    # replace <KIX_CUSTOMER_DATA_*> tags early from CustomerMessageParams, the rests will be replaced
    # by ticket customer user
    KEY:
    for my $Key ( sort keys %{ $Param{CustomerMessageParams} || {} } ) {

        next KEY if !$Param{CustomerMessageParams}->{$Key};

        $Notification{Body} =~ s/${Start}KIX_CUSTOMER_DATA_$Key${End}/$Param{CustomerMessageParams}->{$Key}/gi;
        $Notification{Subject} =~ s/<KIX_CUSTOMER_DATA_$Key>/$Param{CustomerMessageParams}->{$Key}{$_}/gi;
    }

    # get notify texts
    for my $Text (qw(Subject Body)) {
        if ( !$Notification{$Text} ) {
            $Notification{$Text} = "No Notification $Text for $Param{Type} found!";
        }
    }

    # replace place holder stuff
    $Notification{Body} = $Self->_Replace(
        RichText  => $Notification{ContentType} =~ /text\/html/i ? 1 : 0, # no richtext if not html
        Text      => $Notification{Body},
        Recipient => $Param{Recipient},
        Data      => $Param{CustomerMessageParams},
        DataAgent => \%ArticleAgent,
        TicketID  => $Param{TicketID},
        UserID    => $Param{UserID},
        Language  => $Language,

        # KIX4OTRS-capeIT
        ArticleID => $Param{ArticleID} || '',

        # EO KIX4OTRS-capeIT
    );
    $Notification{Subject} = $Self->_Replace(
        RichText  => 0,
        Text      => $Notification{Subject},
        Recipient => $Param{Recipient},
        Data      => $Param{CustomerMessageParams},
        DataAgent => \%ArticleAgent,
        TicketID  => $Param{TicketID},
        UserID    => $Param{UserID},
        Language  => $Language,

        # KIX4OTRS-capeIT
        ArticleID => $Param{ArticleID} || '',

        # EO KIX4OTRS-capeIT
    );

    my $Re  = $Kernel::OM->Get('Config')->Get('Ticket::SubjectRe') || '(RE|AW)';
    my $Fwd = $Kernel::OM->Get('Config')->Get('Ticket::SubjectFwd') || '(FW|FWD)';
    my $AsReply   = $Notification{Subject} =~ m/^$Re:/i;
    my $AsForward = $Notification{Subject} =~ m/^$Fwd:/i;
    $Notification{Subject} = $TicketObject->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => $Notification{Subject} || '',
        Action       => $AsForward ? 'Forward' : undef,
        Type         => (!$AsReply && !$AsForward) ? 'New' : undef
    );

    # add URLs and verify to be full HTML document
    if ( $Self->{RichText} ) {

        $Notification{Body} = $Kernel::OM->Get('HTMLUtils')->LinkQuote(
            String => $Notification{Body},
        );
    }

    return %Notification;
}

# KIX4OTRS-capeIT

=item ReplacePlaceHolder()
    just a wrapper for external access to sub _Replace

    my $ReplacedString = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        Text      => 'title of ticket: <KIX_TICKET_Title>',     # the relevant string to replace
        UserID    => 1,
        Data      => {},                                        # optional - some additional data some placeholder modules look into
        RichText  => 0,                                         # optional - if html qouting is needed
        Translate => 0,                                         # optional - if not given 1 is used
        TicketID  => 1,                                         # optional - used to replace ticket placeholders, else Data should be used - depricated
        ObjectID  => 1,                                         # optional - used to replace object specific placeholders, else Data should be used
        ObjectType => 'Ticket'                                  # optional - needed if ObjectID is given
        ReplaceNotFound => ''                                   # optional - string which is used if placeholder could not resolved - default is '-'
    );

=cut

sub ReplacePlaceHolder {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    $Param{Translate} //= 1;

    if ( $Param{Translate} && (!defined $Param{Language} || !$Param{Language}) ) {
        $Param{Language}
            = $Self->{UserLanguage}
            || $Kernel::OM->Get('Config')->Get('DefaultLanguage')
            || 'en';
    }

    return $Self->_Replace(
        %Param,
    );
}

# EO KIX4OTRS-capeIT

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    $Param{ReplaceNotFound} //= '-';
    $Param{RichText} //= 0;
    $Param{Data} //= {};

    # check for mailto links
    # since the subject and body of those mailto links are
    # uri escaped we have to uri unescape them, replace
    # possible placeholders and then re-uri escape them
    $Param{Text} =~ s{
        (href="mailto:[^\?]+\?)([^"]+")
    }{
        my $MailToHref        = $1;
        my $MailToHrefContent = $2;

        $MailToHrefContent =~ s{
            ((?:subject|body)=)(.+?)("|&)
        }
        {
            my $SubjectOrBodyPrefix  = $1;
            my $SubjectOrBodyContent = $2;
            my $SubjectOrBodySuffix  = $3;

            my $SubjectOrBodyContentUnescaped = URI::Escape::uri_unescape $SubjectOrBodyContent;

            my $SubjectOrBodyContentReplaced = $Self->_Replace(
                %Param,
                Text     => $SubjectOrBodyContentUnescaped,
                RichText => 0,
            );

            my $SubjectOrBodyContentEscaped = URI::Escape::uri_escape_utf8 $SubjectOrBodyContentReplaced;

            $SubjectOrBodyPrefix . $SubjectOrBodyContentEscaped . $SubjectOrBodySuffix;
        }egx;

        $MailToHref . $MailToHrefContent;
    }egx;

    # return if no placeholders included
    return $Param{Text} if $Param{Text} !~ m/(<|&lt;)KIX_.+/g;

    # TODO: move ticket specific handling
    $Param{TicketID} ||= $Param{ObjectType} && $Param{ObjectType} eq 'Ticket' && $Param{ObjectID} ? $Param{ObjectID} : undef;
    $Param{TicketID} ||= IsHashRefWithData($Param{Data}) ? $Param{Data}->{TicketID} : undef;
    my %Ticket;
    if ( $Param{TicketID} ) {
        %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );
        $Param{ObjectType} = 'Ticket';
        $Param{ObjectID}   = $Param{TicketID};
    }

    # translate ticket values if needed
    if ( $Param{Language} ) {

        my $LanguageObject = Kernel::Language->new(
            UserLanguage => $Param{Language},
        );

        # Translate the different values.
        for my $Field (qw(Type State StateType Lock Priority)) {
            $Ticket{$Field} = $LanguageObject->Translate( $Ticket{$Field} );
        }

        # Transform the date values from the ticket data (but not the dynamic field values).
        ATTRIBUTE:
        for my $Attribute ( sort keys %Ticket ) {
            next ATTRIBUTE if $Attribute =~ m{ \A DynamicField_ }xms;
            next ATTRIBUTE if !$Ticket{$Attribute};

            if ( $Ticket{$Attribute} =~ m{\A(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d):(\d\d)\z}xi ) {
                $Ticket{$Attribute} = $LanguageObject->FormatTimeString(
                    $Ticket{$Attribute},
                    'DateFormat',
                    'NoSeconds',
                );
            }
        }
    }

    # html quoting of content
    if ( $Param{RichText} ) {

        ATTRIBUTE:
        for my $Attribute ( sort keys %Ticket ) {
            next ATTRIBUTE if $Attribute =~ m{ \A DynamicField_ }xms;
            next ATTRIBUTE if !$Ticket{$Attribute};
            $Ticket{$Attribute} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
                String => $Ticket{$Attribute},
            );
        }
    }

    # get and execute placeholder modules
    my $PlaceholderModules = $Kernel::OM->Get('Config')->Get('Placeholder::Module');
    if (IsHashRefWithData($PlaceholderModules)) {
        for my $Module (sort keys %{$PlaceholderModules}) {
            next if !IsHashRefWithData($PlaceholderModules->{$Module}) || !$PlaceholderModules->{$Module}->{Module};

            if ( !$Kernel::OM->Get('Main')->Require($PlaceholderModules->{$Module}->{Module}) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Placeholder module $PlaceholderModules->{$Module}->{Module} not found!"
                );
                next;
            }
            my $BackendObject = $PlaceholderModules->{$Module}->{Module}->new( %{$Self} );

            # if the backend constructor failed, it returns an error hash, skip
            next if ( ref $BackendObject ne $PlaceholderModules->{$Module}->{Module} );

            $Param{Text} = $BackendObject->ReplacePlaceholder(
                %Param,
                Ticket => \%Ticket
            );
        }
    }

    return $Param{Text};
}

=head2 _RemoveUnSupportedTag()

cleanup all not supported tags

    my $Text = $TemplateGeneratorObject->_RemoveUnSupportedTag(
        Text => $SomeTextWithTags,
        ListOfUnSupportedTag => \@ListOfUnSupportedTag,
    );

=cut

sub _RemoveUnSupportedTag {

    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Item (qw(Text ListOfUnSupportedTag)) {
        if ( !defined $Param{$Item} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Item!"
            );
            return;
        }
    }

    my $Start = '<';
    my $End   = '>';
    if ( $Self->{RichText} ) {
        $Start = '&lt;';
        $End   = '&gt;';
        $Param{Text} =~ s/(\n|\r)//g;
    }

    # cleanup all not supported tags
    my $NotSupportedTag = $Start . "(?:" . join( "|", @{ $Param{ListOfUnSupportedTag} } ) . ")" . $End;
    $Param{Text} =~ s/$NotSupportedTag/-/gi;

    return $Param{Text};

}

1;

=end Internal:


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
