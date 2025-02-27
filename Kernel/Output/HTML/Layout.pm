# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout;

use strict;
use warnings;

use Storable;
use URI::Escape qw();

# KIX-capeIT
use vars qw(@ISA);
# EO KIX-capeIT

use Kernel::System::Time;
use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Config',
    'Language',
    'Encode',
    'HTMLUtils',
    'JSON',
    'Log',
    'Main',
    # ddoerffel - T2016121190001552 - BusinessSolution code removed    'SystemMaintenance',
    'Time',
    'User',
    'WebRequest',
);

=head1 NAME

Kernel::Output::HTML::Layout - all generic html functions

=head1 SYNOPSIS

All generic html functions. E. g. to get options fields, template processing, ...

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a new object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Output::HTML::Layout' => {
            Lang    => 'de',
        },
    );
    my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

From the web installer, a special Option C<InstallerOnly> is passed
to indicate that a database connection is not yet available.

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Output::HTML::Layout' => {
            InstallerOnly => 1,
        },
    );
    my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # set debug
    $Self->{Debug} = 0;

    # reset block data
    delete $Self->{BlockData};

    # empty action if not defined
    $Self->{Action} = '' if !defined $Self->{Action};

    my $ConfigObject = $Kernel::OM->Get('Config');

    # We'll keep one default TimeObject and one for the user's time zone (if needed)
    $Self->{TimeObject} = $Kernel::OM->Get('Time');

    if ( $ConfigObject->Get('TimeZoneUser') && $Self->{UserTimeZone} ) {
        $Self->{UserTimeObject} = Kernel::System::Time->new( %{$Self} );
    }
    else {
        $Self->{UserTimeObject} = $Self->{TimeObject};
        $Self->{UserTimeZone}   = '';
    }

    # get user language if not already given.
    $Self->{UserLanguage} ||= $ConfigObject->Get('DefaultLanguage') || 'de';

    # create language object
    if ( !$Self->{LanguageObject} ) {
        $Kernel::OM->ObjectParamAdd(
            'Language' => {
                UserTimeZone => $Self->{UserTimeZone},
                UserLanguage => $Self->{UserLanguage},
                Action       => $Self->{Action},
            },
        );
        $Self->{LanguageObject} = $Kernel::OM->Get('Language');
    }

    # set charset if there is no charset given
    $Self->{UserCharset} = 'utf-8';
    $Self->{Charset}     = $Self->{UserCharset};                            # just for compat.
    $Self->{SessionID}   = $Param{SessionID} || '';
    $Self->{SessionName} = $Param{SessionName} || 'SessionID';
    $Self->{CGIHandle}   = $ENV{SCRIPT_NAME} || 'No-$ENV{"SCRIPT_NAME"}';

    # baselink
    $Self->{Baselink} = $Self->{CGIHandle} . '?';
    $Self->{Time}     = $Self->{LanguageObject}->Time(
        Action => 'GET',
        Format => 'DateFormat',
    );
    $Self->{TimeLong} = $Self->{LanguageObject}->Time(
        Action => 'GET',
        Format => 'DateFormatLong',
    );

    # set text direction
    $Self->{TextDirection} = $Self->{LanguageObject}->{TextDirection};

    # check Frontend::Output::FilterContent
    $Self->{FilterContent} = $ConfigObject->Get('Frontend::Output::FilterContent');

    # check Frontend::Output::FilterText
    $Self->{FilterText} = $ConfigObject->Get('Frontend::Output::FilterText');

    # check browser
    $Self->{Browser}        = 'Unknown';
    $Self->{BrowserVersion} = 0;
    $Self->{Platform}       = '';
    $Self->{IsMobile}       = 0;

    $Self->{BrowserJavaScriptSupport} = 1;
    $Self->{BrowserRichText}          = 1;

    my $HttpUserAgent = ( defined $ENV{HTTP_USER_AGENT} ? lc $ENV{HTTP_USER_AGENT} : '' );

    # locate template files
    $Self->{TemplateDir} = $Kernel::OM->Get('Config')->Get('Home') . '/Kernel/Output/HTML/Templates';

    # Check if TemplateDir exists
    if ( !-e $Self->{TemplateDir} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No existing template directory found ('$Self->{TemplateDir}')! Check your Home configuration.",
        );
        die "No existing template directory found ('$Self->{TemplateDir}')! Check your Home configuration.\n";
    }

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    # load sub layout files
    my $Home        = $ENV{KIX_HOME} || $Kernel::OM->Get('Config')->Get('Home');
    my %LayoutFiles = ();

    my @Plugins = $Kernel::OM->Get('Installation')->PluginList(
        InitOrder => 1
    );

    # insert framework as fake plugin
    unshift @Plugins, {
        Plugin    => '',
        Directory => $Home
    };

    # insert Template.pm as default
    my $NewClassName = "Kernel::Output::HTML::Layout::Template";
    if ( !$MainObject->RequireBaseClass($NewClassName) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not load class $NewClassName.",
        );
        die "Could not load class $NewClassName.\n";
    }
    $LayoutFiles{"Template.pm"} = "Template.pm";
    push @ISA, $NewClassName;

    for my $Plugin ( @Plugins ) {
        my $LayoutDir = $Plugin->{Directory}.'/Kernel/Output/HTML';
        if ( -e "$LayoutDir" ) {
            my @Files = $MainObject->DirectoryRead(
                Directory => $LayoutDir,
                Filter    => '*.pm',
            );

            for my $File (@Files) {
                if ( ( $File !~ /Layout.pm$/ ) && !exists( $LayoutFiles{$File} ) ) {

                    $File =~ s{\A.*\/(.+?).pm\z}{$1}xms;
                    my $ClassName = ($Plugin->{Plugin} ? $Plugin->{Plugin}.'::' : '')."Kernel::Output::HTML::Layout::$File";
                    if ( !$MainObject->RequireBaseClass($ClassName) ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'error',
                            Message  => "Could not load class $ClassName.",
                        );
                        die "Could not load class $ClassName.\n";
                    }
                    $LayoutFiles{$File} = $File;
                    push @ISA, $ClassName;
                }
            }
        }
    }

    return $Self;
}

=item Block()

call a block and pass data to it (optional) to generate the block's output.

    $LayoutObject->Block(
        Name => 'Row',
        Data => {
            Time => ...,
        },
    );

=cut

sub Block {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Name!'
        );
        return;
    }
    push @{ $Self->{BlockData} },
        {
        Name => $Param{Name},
        Data => $Param{Data},
        };
}

=item JSONEncode()

Encode perl data structure to JSON string

    my $JSON = $LayoutObject->JSONEncode(
        Data        => $Data,
        NoQuotes    => 0|1, # optional: no double quotes at the start and the end of JSON string
    );

=cut

sub JSONEncode {
    my ( $Self, %Param ) = @_;

    # check for needed data
    return if !defined $Param{Data};

    # get JSON encoded data
    my $JSON = $Kernel::OM->Get('JSON')->Encode(
        Data => $Param{Data},
    ) || '""';

    # remove trailing and trailing double quotes if requested
    if ( $Param{NoQuotes} ) {
        $JSON =~ s{ \A "(.*)" \z }{$1}smx;
    }

    return $JSON;
}

=item Ascii2Html()

convert ascii to html string

    my $HTML = $LayoutObject->Ascii2Html(
        Text            => 'Some <> Test <font color="red">Test</font>',
        Max             => 20,       # max 20 chars folowed by [..]
        VMax            => 15,       # first 15 lines
        NewLine         => 0,        # move \r to \n
        HTMLResultMode  => 0,        # replace " " with &nbsp;
        StripEmptyLines => 0,
        Type            => 'Normal', # JSText or Normal text
        LinkFeature     => 0,        # do some URL detections
    );

also string ref is possible

    my $HTMLStringRef = $LayoutObject->Ascii2Html(
        Text => \$String,
    );

=cut

sub Ascii2Html {
    my ( $Self, %Param ) = @_;

    # check needed param
    return '' if !defined $Param{Text};

    # check text
    my $TextScalar;
    my $Text;
    if ( !ref $Param{Text} ) {
        $TextScalar = 1;
        $Text       = \$Param{Text};
    }
    elsif ( ref $Param{Text} eq 'SCALAR' ) {
        $Text = $Param{Text};
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Invalid ref "' . ref( $Param{Text} ) . '" of Text param!',
        );
        return '';
    }

    # run output filter text
    my @Filters;
    if ( $Param{LinkFeature} && $Self->{FilterText} && ref $Self->{FilterText} eq 'HASH' ) {

        # extract filter list
        my %FilterList = %{ $Self->{FilterText} };

        my $MainObject = $Kernel::OM->Get('Main');

        FILTER:
        for my $Filter ( sort keys %FilterList ) {

            # extract filter config
            my $FilterConfig = $FilterList{$Filter};

            next FILTER if !$FilterConfig;
            next FILTER if ref $FilterConfig ne 'HASH';

            if ( !$MainObject->Require( $FilterConfig->{Module} ) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Could not load FilterText module $FilterConfig->{Module}.",
                );
                die "Could not load FilterText module $FilterConfig->{Module}.\n";
            }

            # create new instance
            my $Object = $FilterConfig->{Module}->new(
                %{$Self},
                LayoutObject => $Self,
            );

            next FILTER if !$Object;

            push(
                @Filters,
                {
                    Object => $Object,
                    Filter => $FilterConfig,
                },
            );
        }

        # pre run
        for my $Filter (@Filters) {

            $Text = $Filter->{Object}->Pre(
                Filter => $Filter->{Filter},
                Data   => $Text,
            );
        }
    }

    # max width
    if ( $Param{Max} && length ${$Text} > $Param{Max} ) {
        ${$Text} = substr( ${$Text}, 0, $Param{Max} - 5 ) . '[...]';
    }

    # newline
    if ( $Param{NewLine} && length( ${$Text} ) < 140_000 ) {
        ${$Text} =~ s/(\n\r|\r\r\n|\r\n)/\n/g;
        ${$Text} =~ s/\r/\n/g;
        ${$Text} =~ s/(.{4,$Param{NewLine}})(?:\s|\z)/$1\n/gm;
        my $ForceNewLine = $Param{NewLine} + 10;
        ${$Text} =~ s/(.{$ForceNewLine})(.+?)/$1\n$2/g;
    }

    # remove tabs
    ${$Text} =~ s/\t/ /g;

    # strip empty lines
    if ( $Param{StripEmptyLines} ) {
        ${$Text} =~ s/^\s*\n//mg;
    }

    # max lines
    if ( $Param{VMax} ) {
        my @TextList = split( "\n", ${$Text} );
        ${$Text} = '';
        my $Counter = 1;
        for (@TextList) {
            if ( $Counter <= $Param{VMax} ) {
                ${$Text} .= $_ . "\n";
            }
            $Counter++;
        }
        if ( $Counter >= $Param{VMax} ) {
            ${$Text} .= "[...]\n";
        }
    }

    # html quoting
    ${$Text} =~ s/&/&amp;/g;
    ${$Text} =~ s/</&lt;/g;
    ${$Text} =~ s/>/&gt;/g;
    ${$Text} =~ s/"/&quot;/g;

    # text -> html format quoting
    if ( $Param{LinkFeature} ) {
        for my $Filter (@Filters) {
            $Text = $Filter->{Object}->Post(
                Filter => $Filter->{Filter},
                Data   => $Text,
            );
        }
    }

    if ( $Param{HTMLResultMode} ) {
        ${$Text} =~ s/\n/<br\/>\n/g;
        ${$Text} =~ s/  /&nbsp;&nbsp;/g;
    }

    if ( $Param{Type} && $Param{Type} eq 'JSText' ) {
        ${$Text} =~ s/'/\\'/g;
    }

    return $Text if ref $Param{Text};
    return ${$Text};
}

=item HTMLLinkQuote()

so some URL link detections in HTML code

    my $HTMLWithLinks = $LayoutObject->HTMLLinkQuote(
        String => $HTMLString,
    );

also string ref is possible

    my $HTMLWithLinksRef = $LayoutObject->HTMLLinkQuote(
        String => \$HTMLString,
    );

=cut

sub HTMLLinkQuote {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('HTMLUtils')->LinkQuote(
        String    => $Param{String},
        TargetAdd => 1,
        Target    => '_blank',
    );
}

=item LinkEncode()

perform URL encoding on query string parameter names or values.

    my $ParamValueEncoded = $LayoutObject->LinkEncode($ParamValue);

Don't encode entire URLs, because this will make them invalid
(?, & and ; will be encoded as well). Only pass one parameter name
or value at a time.

=cut

sub LinkEncode {
    my ( $Self, $Link ) = @_;

    return if !defined $Link;

    return URI::Escape::uri_escape_utf8($Link);
}

=item RichTextDocumentComplete()

1) add html, body, ... tags to be a valid html document
2) replace links of inline content e. g. images to <img src="cid:xxxx" />

    $HTMLBody = $LayoutObject->RichTextDocumentComplete(
        String => $HTMLBody,
    );

=cut

sub RichTextDocumentComplete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(String)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # replace image link with content id for uploaded images
    my $StringRef = $Self->_RichTextReplaceLinkOfInlineContent(
        String => \$Param{String},
    );

    # verify html document
    $Param{String} = $Kernel::OM->Get('HTMLUtils')->DocumentComplete(
        String  => ${$StringRef},
        Charset => $Self->{UserCharset},
    );

    # do correct direction
    if ( $Self->{TextDirection} ) {
        $Param{String} =~ s/<body/<body dir="$Self->{TextDirection}"/i;
    }

    # filter links in response
    $Param{String} = $Self->HTMLLinkQuote( String => $Param{String} );

    return $Param{String};
}

=begin Internal:

=cut

=item _RichTextReplaceLinkOfInlineContent()

replace links of inline content e. g. images

    $HTMLBodyStringRef = $LayoutObject->_RichTextReplaceLinkOfInlineContent(
        String => $HTMLBodyStringRef,
    );

=cut

sub _RichTextReplaceLinkOfInlineContent {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(String)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # replace image link with content id for uploaded images
    ${ $Param{String} } =~ s{
        (<img.+?src=("|'))[^"'>]+?ContentID=(.+?)("|')([^>]*>)
    }
    {
        my ($Start, $CID, $Close, $End) = ($1, $3, $4, $5);
        # Make sure we only get the CID and not extra stuff like session information
        $CID =~ s{^([^;&]+).*}{$1}smx;
        $Start . 'cid:' . $CID . $Close . $End;
    }esgxi;

    return $Param{String};
}

=item _RemoveScriptTags()

This function will remove the surrounding <script> tags of a
piece of JavaScript code, if they are present, and return the result.

    my $CodeContent = $LayoutObject->_RemoveScriptTags(Code => $SomeCode);

=cut

sub _RemoveScriptTags {
    my ( $Self, %Param ) = @_;

    my $Code = $Param{Code} || '';

    if ( $Code =~ m/<script/ ) {

        # cut out dtl block comments of already replaced dtl blocks
        $Code =~ s{
            ^
            <!--
            \/?
            \w+
            -->
            \r?\n
        }{}smxg;

        # cut out opening script tags
        $Code =~ s{
            <script[^>]+>
            (?:\s*<!--)?
            (?:\s*//\s*<!\[CDATA\[)?
        }
        {}smxg;

        # cut out closing script tags
        $Code =~ s{
            (?:-->\s*)?
            (?://\s*\]\]>\s*)?
            </script>
        }{}smxg;

    }
    return $Code;
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
