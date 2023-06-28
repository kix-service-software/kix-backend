# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
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
    'Chat',
    'Encode',
    'HTMLUtils',
    'JSON',
    'Log',
    'Main',
    # ddoerffel - T2016121190001552 - BusinessSolution code removed    'SystemMaintenance',
    'Time',
    'User',
    'VideoChat',
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

    # check Frontend::Output::FilterElementPost
    $Self->{FilterElementPost} = {};

    my %FilterElementPost = %{ $ConfigObject->Get('Frontend::Output::FilterElementPost') // {} };

    FILTER:
    for my $Filter ( sort keys %FilterElementPost ) {

        # extract filter config
        my $FilterConfig = $FilterElementPost{$Filter};

        next FILTER if !$FilterConfig || ref $FilterConfig ne 'HASH';

        # extract template list
        my %TemplateList = %{ $FilterConfig->{Templates} || {} };

        if ( !%TemplateList || $TemplateList{ALL} ) {

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => <<EOF,
$FilterConfig->{Module} will be ignored because it wants to operate on all templates or does not specify a template list.
EOF
            );

            next FILTER;
        }

        $Self->{FilterElementPost}->{$Filter} = $FilterElementPost{$Filter};
    }

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
        $Self->FatalDie(
            Message =>
                "No existing template directory found ('$Self->{TemplateDir}')! Check your Home configuration."
        );
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
        $Self->FatalDie(
            Message => "Could not load class $NewClassName.",
        );
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
                        $Self->FatalDie(
                            Message => "Could not load class $ClassName!",
                        );
                    }
                    $LayoutFiles{$File} = $File;
                    push @ISA, $ClassName;
                }
            }
        }
    }

    return $Self;
}

sub SetEnv {
    my ( $Self, %Param ) = @_;

    for (qw(Key Value)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            $Self->FatalError();
        }
    }
    $Self->{EnvNewRef}->{ $Param{Key} } = $Param{Value};
    return 1;
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

sub FatalError {
    my ( $Self, %Param ) = @_;

    # Prevent endless recursion in case of problems with Template engine.
    return if ( $Self->{InFatalError}++ );

    if ( $Param{Message} ) {
        $Kernel::OM->Get('Log')->Log(
            Caller   => 1,
            Priority => 'error',
            Message  => $Param{Message},
        );
    }
    my $Output = $Self->Header(
        Area  => 'Frontend',
        Title => 'Fatal Error'
    );
    $Output .= $Self->Error(%Param);
    $Output .= $Self->Footer();
    $Self->Print( Output => \$Output );
    exit;
}

sub FatalDie {
    my ( $Self, %Param ) = @_;

    if ( $Param{Message} ) {
        $Kernel::OM->Get('Log')->Log(
            Caller   => 1,
            Priority => 'error',
            Message  => $Param{Message},
        );
    }

    # get backend error messages
    for (qw(Message Traceback)) {
        my $Backend = 'Backend' . $_;
        $Param{$Backend} = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'Error',
            What => $_
        ) || '';
        $Param{$Backend} = $Self->Ascii2Html(
            Text           => $Param{$Backend},
            HTMLResultMode => 1,
        );
    }
    if ( !$Param{Message} ) {
        $Param{Message} = $Param{BackendMessage};
    }
    die $Param{Message};
}

sub ErrorScreen {
    my ( $Self, %Param ) = @_;

    my $Output = $Self->Header( Title => 'Error' );
    $Output .= $Self->Error(%Param);
    $Output .= $Self->Footer();
    return $Output;
}

sub Error {
    my ( $Self, %Param ) = @_;

    # get backend error messages
    for (qw(Message Traceback)) {
        my $Backend = 'Backend' . $_;
        $Param{$Backend} = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'Error',
            What => $_
        ) || '';
    }
    if ( !$Param{BackendMessage} && !$Param{BackendTraceback} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => $Param{Message} || '?',
        );
        for (qw(Message Traceback)) {
            my $Backend = 'Backend' . $_;
            $Param{$Backend} = $Kernel::OM->Get('Log')->GetLogEntry(
                Type => 'Error',
                What => $_
            ) || '';
        }
    }

    if ( !$Param{Message} ) {
        $Param{Message} = $Param{BackendMessage};

        # ddoerffel - T2016121190001552 - BusinessSolution code removed
    }

    if ( $Param{BackendTraceback} ) {
        $Self->Block(
            Name => 'ShowBackendTraceback',
            Data => \%Param,
        );
    }

    # create & return output
    return $Self->Output(
        TemplateFile => 'Error',
        Data         => \%Param
    );
}

sub Warning {
    my ( $Self, %Param ) = @_;

    # get backend error messages
    $Param{BackendMessage} = $Kernel::OM->Get('Log')->GetLogEntry(
        Type => 'Notice',
        What => 'Message',
        )
        || $Kernel::OM->Get('Log')->GetLogEntry(
        Type => 'Error',
        What => 'Message',
        ) || '';

    if ( !$Param{Message} ) {
        $Param{Message} = $Param{BackendMessage};
    }

    # create & return output
    return $Self->Output(
        TemplateFile => 'Warning',
        Data         => \%Param
    );
}

=item Notify()

create notify lines

    infos, the text will be translated

    my $Output = $LayoutObject->Notify(
        Priority => 'Warning',
        Info => 'Some Info Message',
    );

    data with link, the text will be translated

    my $Output = $LayoutObject->Notify(
        Priority  => 'Warning',
        Data      => 'Template content',
        Link      => 'http://example.com/',
        LinkClass => 'some_CSS_class',              # optional
    );

    errors, the text will be translated

    my $Output = $LayoutObject->Notify(
        Priority => 'Error',
        Info => 'Some Error Message',
    );

    errors from log backend, if no error extists, a '' will be returned

    my $Output = $LayoutObject->Notify(
        Priority => 'Error',
    );

=cut

sub Notify {
    my ( $Self, %Param ) = @_;

    # create & return output
    if ( !$Param{Info} && !$Param{Data} ) {
        $Param{BackendMessage} = $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'Notice',
            What => 'Message',
            )
            || $Kernel::OM->Get('Log')->GetLogEntry(
            Type => 'Error',
            What => 'Message',
            ) || '';

        $Param{Info} = $Param{BackendMessage};

        # return if we have nothing to show
        return '' if !$Param{Info};
    }

    my $BoxClass = 'Notice';

    if ( $Param{Info} ) {
        $Param{Info} =~ s/\n//g;
    }
    if ( $Param{Priority} && $Param{Priority} eq 'Error' ) {
        $BoxClass = 'Error';
    }
    elsif ( $Param{Priority} && $Param{Priority} eq 'Success' ) {
        $BoxClass = 'Success';
    }
    elsif ( $Param{Priority} && $Param{Priority} eq 'Info' ) {
        $BoxClass = 'Info';
    }

    if ( $Param{Link} ) {
        $Self->Block(
            Name => 'LinkStart',
            Data => {
                LinkStart => $Param{Link},
                LinkClass => $Param{LinkClass} || '',
            },
        );
    }
    if ( $Param{Data} ) {
        $Self->Block(
            Name => 'Data',
            Data => \%Param,
        );
    }
    else {
        $Self->Block(
            Name => 'Text',
            Data => \%Param,
        );
    }
    if ( $Param{Link} ) {
        $Self->Block(
            Name => 'LinkStop',
            Data => {
                LinkStop => '</a>',
            },
        );
    }
    return $Self->Output(
        TemplateFile => 'Notify',
        Data         => {
            %Param,
            BoxClass => $BoxClass,
        },
    );
}

=item Header()

generates the HTML for the page begin in the Agent interface.

    my $Output = $LayoutObject->Header(
        Type              => 'Small',                # (optional) '' (Default, full header) or 'Small' (blank header)
        ShowToolbarItems  => 0,                      # (optional) default 1 (0|1)
        ShowPrefLink      => 0,                      # (optional) default 1 (0|1)
        ShowLogoutButton  => 0,                      # (optional) default 1 (0|1)
    );

=cut

sub Header {
    my ( $Self, %Param ) = @_;

    my $Type = $Param{Type} || '';

    # check params
    if ( !defined $Param{ShowToolbarItems} ) {
        $Param{ShowToolbarItems} = 1;
    }

    if ( !defined $Param{ShowPrefLink} ) {
        $Param{ShowPrefLink} = 1;
    }

    my $ConfigObject = $Kernel::OM->Get('Config');

    # do not show preferences link if the preferences module is disabled
    my $Modules = $ConfigObject->Get('Frontend::Module');
    if ( !$Modules->{AgentPreferences} ) {
        $Param{ShowPrefLink} = 0;
    }

    if ( !defined $Param{ShowLogoutButton} ) {
        $Param{ShowLogoutButton} = 1;
    }

    # set rtl if needed
    if ( $Self->{TextDirection} && $Self->{TextDirection} eq 'rtl' ) {
        $Param{BodyClass} = 'RTL';
    }
    elsif ( $ConfigObject->Get('Frontend::DebugMode') ) {
        $Self->Block(
            Name => 'DebugRTLButton',
        );
    }

    # Generate the minified CSS and JavaScript files and the tags referencing them (see LayoutLoader)
    $Self->LoaderCreateAgentCSSCalls();

    my %AgentLogo;

    # check if we need to display a custom logo for the selected skin
    my $AgentLogoCustom = $ConfigObject->Get('AgentLogoCustom');
    if (
        $Self->{SkinSelected}
        && $AgentLogoCustom
        && IsHashRefWithData($AgentLogoCustom)
        && $AgentLogoCustom->{ $Self->{SkinSelected} }
        )
    {
        %AgentLogo = %{ $AgentLogoCustom->{ $Self->{SkinSelected} } };
    }

    # Otherwise show default header logo, if configured
    elsif ( defined $ConfigObject->Get('AgentLogo') ) {
        %AgentLogo = %{ $ConfigObject->Get('AgentLogo') };
    }

    if ( %AgentLogo && keys %AgentLogo ) {

        my %Data;
        for my $CSSStatement ( sort keys %AgentLogo ) {
            if ( $CSSStatement eq 'URL' ) {
                my $WebPath = '';
                if ( $AgentLogo{$CSSStatement} !~ /(http|ftp|https):\//i ) {
                    $WebPath = $ConfigObject->Get('Frontend::WebPath');
                }
                $Data{'URL'} = 'url(' . $WebPath . $AgentLogo{$CSSStatement} . ')';
            }
            else {
                $Data{$CSSStatement} = $AgentLogo{$CSSStatement};
            }
        }

        $Self->Block(
            Name => 'HeaderLogoCSS',
            Data => \%Data,
        );
    }

    # add cookies if exists
    my $Output = '';
    if ( $Self->{SetCookies} && $ConfigObject->Get('SessionUseCookie') ) {
        for ( sort keys %{ $Self->{SetCookies} } ) {
            $Output .= "Set-Cookie: $Self->{SetCookies}->{$_}\n";
        }
    }

    my $File = $Param{Filename} || $Self->{Action} || 'unknown';

    # set file name for "save page as"
    $Param{ContentDisposition} = "filename=\"$File.html\"";

    # area and title
    if ( !$Param{Area} ) {
        $Param{Area} = (
            defined $Self->{Action}
            ? $ConfigObject->Get('Frontend::Module')->{ $Self->{Action} }->{NavBarName}
            : ''
        );
    }
    if ( !$Param{Title} ) {
        $Param{Title} = $ConfigObject->Get('Frontend::Module')->{ $Self->{Action} }->{Title}
            || '';
    }
    for my $Word (qw(Value Title Area)) {
        if ( $Param{$Word} ) {
            $Param{TitleArea} .= $Self->{LanguageObject}->Translate( $Param{$Word} ) . ' - ';
        }
    }

    if ( $Self->{Action} eq 'AgentTicketZoom') {
        my $TicketObject = $Kernel::OM->Get('Ticket');
        my %Ticket       = $TicketObject->TicketGet(
            TicketID => $Self->{TicketID},
        );
        my $Access = $TicketObject->TicketPermission(
            Type     => 'ro',
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID}
        );

        if ($Access) {
            $Param{TitleArea} = $Ticket{Title};
        }
    }

    my $MainObject = $Kernel::OM->Get('Main');

    # run header meta modules
    my $HeaderMetaModule = $ConfigObject->Get('Frontend::HeaderMetaModule');
    if ( ref $HeaderMetaModule eq 'HASH' ) {
        my %Jobs = %{$HeaderMetaModule};

        MODULE:
        for my $Job ( sort keys %Jobs ) {

            # load and run module
            next MODULE if !$MainObject->Require( $Jobs{$Job}->{Module} );
            my $Object = $Jobs{$Job}->{Module}->new(
                %{$Self},
                LayoutObject => $Self,
            );
            next MODULE if !$Object;
            $Object->Run( %Param, Config => $Jobs{$Job} );
        }
    }

    # create & return output
    $Output .= $Self->Output(
        TemplateFile => "Header$Type",
        Data         => \%Param
    );

    # remove the version tag from the header if configured
    $Self->_DisableBannerCheck( OutputRef => \$Output );

    return $Output;
}

sub Footer {
    my ( $Self, %Param ) = @_;

    my $Type          = $Param{Type}           || '';
    my $HasDatepicker = $Self->{HasDatepicker} || 0;

    # Generate the minified CSS and JavaScript files and the tags referencing them (see LayoutLoader)
    $Self->LoaderCreateAgentJSCalls();

    # get datepicker data, if needed in module
    if ($HasDatepicker) {
        my $VacationDays     = $Self->DatepickerGetVacationDays();
        my $VacationDaysJSON = $Self->JSONEncode(
            Data => $VacationDays,
        );

        my $TextDirection = $Self->{LanguageObject}->{TextDirection} || '';

        $Self->Block(
            Name => 'DatepickerData',
            Data => {
                VacationDays  => $VacationDaysJSON,
                IsRTLLanguage => ( $TextDirection eq 'rtl' ) ? 1 : 0,
            },
        );
    }

    my $ConfigObject = $Kernel::OM->Get('Config');

    # NewTicketInNewWindow
    if ( $ConfigObject->Get('NewTicketInNewWindow::Enabled') ) {
        $Self->Block(
            Name => 'NewTicketInNewWindow',
        );
    }

    # AutoComplete-Config
    my $AutocompleteConfig = $ConfigObject->Get('AutoComplete::Agent');

    for my $ConfigElement ( sort keys %{$AutocompleteConfig} ) {
        $AutocompleteConfig->{$ConfigElement}->{ButtonText}
            = $Self->{LanguageObject}->Translate( $AutocompleteConfig->{$ConfigElement}->{ButtonText} );
    }

    my $AutocompleteConfigJSON = $Self->JSONEncode(
        Data => $AutocompleteConfig,
    );

    $Self->Block(
        Name => 'AutoCompleteConfig',
        Data => {
            AutocompleteConfig => $AutocompleteConfigJSON,
        },
    );

    # Search frontend (JavaScript)
    my $SearchFrontendConfig = $ConfigObject->Get('Frontend::Search::JavaScript');

    # get target javascript function
    my $JSCall = '';

    if ( $SearchFrontendConfig && $Self->{Action} ) {
        for my $Group ( sort keys %{$SearchFrontendConfig} ) {
            REGEXP:
            for my $RegExp ( sort keys %{ $SearchFrontendConfig->{$Group} } ) {
                if ( $Self->{Action} =~ /$RegExp/ ) {
                    $JSCall = $SearchFrontendConfig->{$Group}->{$RegExp};
                    last REGEXP;
                }
            }
        }
    }

    $Self->Block(
        Name => 'SearchFrontendConfig',
        Data => {
            SearchFrontendConfig => $JSCall,
        },
    );

    # Banner
    # ddoerffel - T2016121190001552 - BusinessSolution code removed
    if ( !$ConfigObject->Get('Secure::DisableBanner') ) {
        $Self->Block(
            Name => 'Banner',
        );
    }

    # Check if video chat is enabled.
    if ( $Kernel::OM->Get('Main')->Require( 'VideoChat', Silent => 1 ) ) {
        $Param{VideoChatEnabled} = $Kernel::OM->Get('VideoChat')->IsEnabled()
            || $Kernel::OM->Get('WebRequest')->GetParam( Param => 'UnitTestMode' ) // 0;
    }

    # create & return output
    return $Self->Output(
        TemplateFile => "Footer$Type",
        Data         => \%Param
    );
}

sub Print {
    my ( $Self, %Param ) = @_;

    # run output content filters
    if ( $Self->{FilterContent} && ref $Self->{FilterContent} eq 'HASH' ) {

        # extract filter list
        my %FilterList = %{ $Self->{FilterContent} };

        my $MainObject = $Kernel::OM->Get('Main');

        FILTER:
        for my $Filter ( sort keys %FilterList ) {

            # extract filter config
            my $FilterConfig = $FilterList{$Filter};

            next FILTER if !$FilterConfig;
            next FILTER if ref $FilterConfig ne 'HASH';

            # extract template list
            my $TemplateList = $FilterConfig->{Templates};

            # check template list
            if ( !$TemplateList || ref $TemplateList ne 'HASH' || !%{$TemplateList} ) {

                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Please add a template list to output filter $FilterConfig->{Module} "
                        . "to improve performance. Use ALL if OutputFilter should modify all "
                        . "templates of the system (deprecated).",
                );
            }

            # check template list
            if ( $Param{TemplateFile} && ref $TemplateList eq 'HASH' && !$TemplateList->{ALL} ) {
                next FILTER if !$TemplateList->{ $Param{TemplateFile} };
            }

            next FILTER if !$MainObject->Require( $FilterConfig->{Module} );

            # create new instance
            my $Object = $FilterConfig->{Module}->new(
                %{$Self},
                LayoutObject => $Self,
            );

            next FILTER if !$Object;

            # run output filter
            $Object->Run(
                %{$FilterConfig},
                Data         => $Param{Output},
                TemplateFile => $Param{TemplateFile} || '',
            );
        }
    }

    # There seems to be a bug in FastCGI that it cannot handle unicode output properly.
    #   Work around this by converting to an utf8 byte stream instead.
    #   See also http://bugs.otrs.org/show_bug.cgi?id=6284 and
    #   http://bugs.otrs.org/show_bug.cgi?id=9802.
    if ( $INC{'CGI/Fast.pm'} || $ENV{FCGI_ROLE} || $ENV{FCGI_SOCKET_PATH} ) {    # are we on FCGI?
        $Kernel::OM->Get('Encode')->EncodeOutput( $Param{Output} );
        binmode STDOUT, ':bytes';
    }

    print ${ $Param{Output} };

    return 1;
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

            # extract template list
            my $TemplateList = $FilterConfig->{Templates};

            # check template list
            if ( !$TemplateList || ref $TemplateList ne 'HASH' || !%{$TemplateList} ) {

                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Please add a template list to output filter $FilterConfig->{Module} "
                        . "to improve performance. Use ALL if OutputFilter should modify all "
                        . "templates of the system (deprecated).",
                );
            }

            # check template list
            if ( $Param{TemplateFile} && ref $TemplateList eq 'HASH' && !$TemplateList->{ALL} ) {
                next FILTER if !$TemplateList->{ $Param{TemplateFile} };
            }

            $Self->FatalDie() if !$MainObject->Require( $FilterConfig->{Module} );

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

=item LinkQuote()

so some URL link detections

    my $HTMLWithLinks = $LayoutObject->LinkQuote(
        Text => $HTMLWithOutLinks,
    );

also string ref is possible

    my $HTMLWithLinksRef = $LayoutObject->LinkQuote(
        Text => \$HTMLWithOutLinksRef,
    );

=cut

sub LinkQuote {
    my ( $Self, %Param ) = @_;

    my $Text   = $Param{Text}   || '';
    my $Target = $Param{Target} || 'NewPage' . int( rand(199) );

    # check ref
    my $TextScalar;
    if ( !ref $Text ) {
        $TextScalar = $Text;
        $Text       = \$TextScalar;
    }

    # run output filter text
    my @Filters;
    if ( $Self->{FilterText} && ref $Self->{FilterText} eq 'HASH' ) {

        # extract filter list
        my %FilterList = %{ $Self->{FilterText} };

        my $MainObject = $Kernel::OM->Get('Main');

        FILTER:
        for my $Filter ( sort keys %FilterList ) {

            # extract filter config
            my $FilterConfig = $FilterList{$Filter};

            next FILTER if !$FilterConfig;
            next FILTER if ref $FilterConfig ne 'HASH';

            # extract template list
            my $TemplateList = $FilterConfig->{Templates};

            # check template list
            if ( !$TemplateList || ref $TemplateList ne 'HASH' || !%{$TemplateList} ) {

                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message =>
                        "Please add a template list to output filter $FilterConfig->{Module} "
                        . "to improve performance. Use ALL if OutputFilter should modify all "
                        . "templates of the system (deprecated).",
                );
            }

            # check template list
            if ( $Param{TemplateFile} && ref $TemplateList eq 'HASH' && !$TemplateList->{ALL} ) {
                next FILTER if !$TemplateList->{ $Param{TemplateFile} };
            }

            $Self->FatalDie() if !$MainObject->Require( $FilterConfig->{Module} );

            # create new instance
            my $Object = $FilterConfig->{Module}->new(
                %{$Self},
                LayoutObject => $Self,
            );

            next FILTER if !$Object;

            push @Filters, {
                Object => $Object,
                Filter => $FilterConfig,
            };
        }
    }

    for my $Filter (@Filters) {
        $Text = $Filter->{Object}->Pre(
            Filter => $Filter->{Filter},
            Data   => $Text
        );
    }
    for my $Filter (@Filters) {
        $Text = $Filter->{Object}->Post(
            Filter => $Filter->{Filter},
            Data   => $Text
        );
    }

    # do mail to quote
    ${$Text} =~ s/(mailto:.+?)(\.\s|\s|\)|\"|]|')/<a href=\"$1\">$1<\/a>$2/gi;

    # check ref && return result like called
    if ($TextScalar) {
        return ${$Text};
    }
    else {
        return $Text;
    }
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

sub CustomerAgeInHours {
    my ( $Self, %Param ) = @_;

    my $Age = defined( $Param{Age} ) ? $Param{Age} : return;
    my $Space     = $Param{Space} || '<br/>';
    my $AgeStrg   = '';
    my $HourDsc   = Translatable('h');
    my $MinuteDsc = Translatable('m');
    if ( $Kernel::OM->Get('Config')->Get('TimeShowCompleteDescription') ) {
        $HourDsc   = Translatable('hour(s)');
        $MinuteDsc = Translatable('minute(s)');
    }
    if ( $Age =~ /^-(.*)/ ) {
        $Age     = $1;
        $AgeStrg = '-';
    }

    # get hours
    if ( $Age >= 3600 ) {
        $AgeStrg .= int( ( $Age / 3600 ) ) . ' ';
        $AgeStrg .= $Self->{LanguageObject}->Translate($HourDsc);
        $AgeStrg .= $Space;
    }

    # get minutes (just if age < 1 day)
    if ( $Age <= 3600 || int( ( $Age / 60 ) % 60 ) ) {
        $AgeStrg .= int( ( $Age / 60 ) % 60 ) . ' ';
        $AgeStrg .= $Self->{LanguageObject}->Translate($MinuteDsc);
    }
    return $AgeStrg;
}

sub CustomerAge {
    my ( $Self, %Param ) = @_;

    my $ConfigObject = $Kernel::OM->Get('Config');

    my $Age = defined( $Param{Age} ) ? $Param{Age} : return;
    my $Space     = $Param{Space} || '<br/>';
    my $AgeStrg   = '';
    my $DayDsc    = Translatable('d');
    my $HourDsc   = Translatable('h');
    my $MinuteDsc = Translatable('m');
    if ( $ConfigObject->Get('TimeShowCompleteDescription') ) {
        $DayDsc    = Translatable('day(s)');
        $HourDsc   = Translatable('hour(s)');
        $MinuteDsc = Translatable('minute(s)');
    }
    if ( $Age =~ /^-(.*)/ ) {
        $Age     = $1;
        $AgeStrg = '-';
    }

    # get days
    if ( $Age >= 86400 ) {
        $AgeStrg .= int( ( $Age / 3600 ) / 24 ) . ' ';
        $AgeStrg .= $Self->{LanguageObject}->Translate($DayDsc);
        $AgeStrg .= $Space;
    }

    # get hours
    if ( $Age >= 3600 ) {
        $AgeStrg .= int( ( $Age / 3600 ) % 24 ) . ' ';
        $AgeStrg .= $Self->{LanguageObject}->Translate($HourDsc);
        $AgeStrg .= $Space;
    }

    # get minutes (just if age < 1 day)
    if ( $ConfigObject->Get('TimeShowAlwaysLong') || $Age < 86400 ) {
        $AgeStrg .= int( ( $Age / 60 ) % 60 ) . ' ';
        $AgeStrg .= $Self->{LanguageObject}->Translate($MinuteDsc);
    }
    return $AgeStrg;
}

sub ReturnValue {
    my ( $Self, $What ) = @_;

    return $Self->{$What};
}

=item Attachment()

returns browser output to display/download a attachment

    $HTML = $LayoutObject->Attachment(
        Type        => 'inline',        # optional, default: attachment, possible: inline|attachment
        Filename    => 'FileName.png',  # optional
        ContentType => 'image/png',
        Content     => $Content,
        Sandbox     => 1,               # optional, default 0; use content security policy to prohibit external
                                        #   scripts, flash etc.
    );

    or for AJAX html snippets

    $HTML = $LayoutObject->Attachment(
        Type        => 'inline',        # optional, default: attachment, possible: inline|attachment
        Filename    => 'FileName.html', # optional
        ContentType => 'text/html',
        Charset     => 'utf-8',         # optional
        Content     => $Content,
        NoCache     => 1,               # optional
    );

=cut

sub Attachment {
    my ( $Self, %Param ) = @_;

    # check needed params
    for (qw(Content ContentType)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Got no $_!",
            );
            $Self->FatalError();
        }
    }

    # return attachment
    my $Output = 'Content-Disposition: ';
    if ( $Param{Type} ) {
        $Output .= $Param{Type};
        $Output .= '; ';
    }
    else {
        $Output .= $Kernel::OM->Get('Config')->Get('AttachmentDownloadType') || 'attachment';
        $Output .= '; ';
    }

    if ( $Param{Filename} ) {

        # IE 10+ supports this
        my $URLEncodedFilename = URI::Escape::uri_escape_utf8( $Param{Filename} );
        $Output .= " filename=\"$Param{Filename}\"; filename*=utf-8''$URLEncodedFilename";
    }
    $Output .= "\n";

    # get attachment size
    $Param{Size} = bytes::length( $Param{Content} );

    # add no cache headers
    if ( $Param{NoCache} ) {
        $Output .= "Expires: Tue, 1 Jan 1980 12:00:00 GMT\n";
        $Output .= "Cache-Control: no-cache\n";
        $Output .= "Pragma: no-cache\n";
    }
    $Output .= "Content-Length: $Param{Size}\n";
    $Output .= "X-UA-Compatible: IE=edge,chrome=1\n";

    if ( !$Kernel::OM->Get('Config')->Get('DisableIFrameOriginRestricted') ) {
        $Output .= "X-Frame-Options: SAMEORIGIN\n";
    }

    if ( $Param{Sandbox} && !$Kernel::OM->Get('Config')->Get('DisableContentSecurityPolicy') ) {

        # Disallow external and inline scripts, active content, frames, but keep allowing inline styles
        #   as this is a common use case in emails.
        # Also disallow referrer headers to prevent referrer leaks.
        # img-src:    allow external and inline (data:) images
        # script-src: block all scripts
        # object-src: allow 'self' so that the browser can load plugins for PDF display
        # Disallow external and inline scripts, active content, frames, but keep allowing inline styles
        #   as this is a common use case in emails.
        # Also disallow referrer headers to prevent referrer leaks.
        $Output
            .= "Content-Security-Policy: default-src *; img-src * data:; script-src 'none'; object-src 'self'; frame-src 'none'; style-src 'unsafe-inline'; referrer no-referrer;\n";
    }

    if ( $Param{Charset} ) {
        $Output .= "Content-Type: $Param{ContentType}; charset=$Param{Charset};\n\n";
    }
    else {
        $Output .= "Content-Type: $Param{ContentType}\n\n";
    }

    # disable utf8 flag, to write binary to output
    my $EncodeObject = $Kernel::OM->Get('Encode');
    $EncodeObject->EncodeOutput( \$Output );
    $EncodeObject->EncodeOutput( \$Param{Content} );

    # fix for firefox HEAD problem
    if ( !$ENV{REQUEST_METHOD} || $ENV{REQUEST_METHOD} ne 'HEAD' ) {
        $Output .= $Param{Content};
    }

    # reset binmode, don't use utf8
    binmode STDOUT, ':bytes';

    return $Output;
}

sub TransformDateSelection {
    my ( $Self, %Param ) = @_;

    # get key prefix
    my $Prefix = $Param{Prefix} || '';

    # time zone translation if needed
    if ( $Kernel::OM->Get('Config')->Get('TimeZoneUser') && $Self->{UserTimeZone} ) {
        my $TimeStamp = $Self->{TimeObject}->TimeStamp2SystemTime(
            String => $Param{ $Prefix . 'Year' } . '-'
                . $Param{ $Prefix . 'Month' } . '-'
                . $Param{ $Prefix . 'Day' } . ' '
                . ( $Param{ $Prefix . 'Hour' }   || 0 ) . ':'
                . ( $Param{ $Prefix . 'Minute' } || 0 )
                . ':00',
        );
        $TimeStamp = $TimeStamp - ( $Self->{UserTimeZone} * 3600 );
        (
            $Param{ $Prefix . 'Second' },
            $Param{ $Prefix . 'Minute' },
            $Param{ $Prefix . 'Hour' },
            $Param{ $Prefix . 'Day' },
            $Param{ $Prefix . 'Month' },
            $Param{ $Prefix . 'Year' }
        ) = $Self->{UserTimeObject}->SystemTime2Date( SystemTime => $TimeStamp );
    }

    # reset prefix
    $Param{Prefix} = '';

    return %Param;
}

=item Ascii2RichText()

converts text to rich text

    my $HTMLString = $LayoutObject->Ascii2RichText(
        String => $TextString,
    );

=cut

sub Ascii2RichText {
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

    # ascii 2 html
    $Param{String} = $Kernel::OM->Get('HTMLUtils')->ToHTML(
        String => $Param{String},
    );

    return $Param{String};
}

=item RichText2Ascii()

converts text to rich text

    my $TextString = $LayoutObject->RichText2Ascii(
        String => $HTMLString,
    );

=cut

sub RichText2Ascii {
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

    # ascii 2 html
    $Param{String} = $Kernel::OM->Get('HTMLUtils')->ToAscii(
        String => $Param{String},
    );

    return $Param{String};
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

=end Internal:

=item RichTextDocumentServe()

serve a rich text (HTML) document for local view inside of an iframe in correct charset and with correct
links for inline documents.

By default, all inline/active content (such as script, object, applet or embed tags)
will be stripped. If there are external images, they will be stripped too,
but a message will be shown allowing the user to reload the page showing the external images.

    my %HTMLFile = $LayoutObject->RichTextDocumentServe(
        Data => {
            Content     => $HTMLBodyRef,
            ContentType => 'text/html; charset="iso-8859-1"',
        },
        URL               => 'AgentTicketAttachment;Subaction=HTMLView;ArticleID=123;FileID=',
        Attachments       => \%AttachmentListOfInlineAttachments,

        LoadInlineContent => 0,     # Serve the document including all inline content. WARNING: This might be dangerous.

        LoadExternalImages => 0,    # Load external images? If this is 0, a message will be included if
                                    # external images were found and removed.
    );

=cut

sub RichTextDocumentServe {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data URL Attachments)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get charset and convert content to internal charset
    my $Charset;
    if ( $Param{Data}->{ContentType} =~ m/.+?charset=("|'|)(.+)/ig ) {
        $Charset = $2;
        $Charset =~ s/"|'//g;
    }
    if ( !$Charset ) {
        $Charset = 'us-ascii';
        $Param{Data}->{ContentType} .= '; charset="us-ascii"';
    }

    # convert charset
    if ($Charset) {
        $Param{Data}->{Content} = $Kernel::OM->Get('Encode')->Convert(
            Text  => $Param{Data}->{Content},
            From  => $Charset,
            To    => 'utf-8',
            Check => 1,
        );

        # replace charset in content
        $Param{Data}->{ContentType} =~ s/\Q$Charset\E/utf-8/gi;
        $Param{Data}->{Content} =~ s/(<meta[^>]+charset=("|'|))\Q$Charset\E/$1utf-8/gi;
    }

    # add html links
    $Param{Data}->{Content} = $Self->HTMLLinkQuote(
        String => $Param{Data}->{Content},
    );

    # cleanup some html tags to be cross browser compat.
    $Param{Data}->{Content} = $Self->RichTextDocumentCleanup(
        String => $Param{Data}->{Content},
    );

    # safety check
    if ( !$Param{LoadInlineContent} ) {

        # Strip out active content first, keeping external images.
        my %SafetyCheckResult = $Kernel::OM->Get('HTMLUtils')->Safety(
            String       => $Param{Data}->{Content},
            NoApplet     => 1,
            NoObject     => 1,
            NoEmbed      => 1,
            NoSVG        => 1,
            NoIntSrcLoad => 0,
            NoExtSrcLoad => 0,
            NoJavaScript => 1,
            Debug        => $Self->{Debug},
        );

        $Param{Data}->{Content} = $SafetyCheckResult{String};

        if ( !$Param{LoadExternalImages} ) {

            # Strip out external images, but show a confirmation button to
            #   load them explicitly.
            my %SafetyCheckResult = $Kernel::OM->Get('HTMLUtils')->Safety(
                String       => $Param{Data}->{Content},
                NoApplet     => 1,
                NoObject     => 1,
                NoEmbed      => 1,
                NoSVG        => 1,
                NoIntSrcLoad => 0,
                NoExtSrcLoad => 1,
                NoJavaScript => 1,
                Debug        => $Self->{Debug},
            );

            $Param{Data}->{Content} = $SafetyCheckResult{String};

            if ( $SafetyCheckResult{Replace} ) {

                # Generate blocker message.
                my $Message = $Self->Output( TemplateFile => 'AttachmentBlocker' );

                # Add it to the beginning of the body, if possible, otherwise prepend it.
                if ( $Param{Data}->{Content} =~ /<body.*?>/si ) {
                    $Param{Data}->{Content} =~ s/(<body.*?>)/$1\n$Message/si;
                }
                else {
                    $Param{Data}->{Content} = $Message . $Param{Data}->{Content};
                }
            }

        }
    }

    # build base url for inline images
    my $SessionID = '';
    if ( $Self->{SessionID} && !$Self->{SessionIDCookie} ) {
        $SessionID = ';' . $Self->{SessionName} . '=' . $Self->{SessionID};
    }

    # replace inline images in content with runtime url to images
    my $AttachmentLink = $Self->{Baselink} . $Param{URL};
    $Param{Data}->{Content} =~ s{
        (=|"|')cid:(.*?)("|'|>|\/>|\s)
    }
    {
        my $Start= $1;
        my $ContentID = $2;
        my $End = $3;

        # improve html quality
        if ( $Start ne '"' && $Start ne '\'' ) {
            $Start .= '"';
        }
        if ( $End ne '"' && $End ne '\'' ) {
            $End = '"' . $End;
        }

        # find matching attachment and replace it with runtime url to image
        ATTACHMENT_ID:
        for my $AttachmentID (  sort keys %{ $Param{Attachments} }) {
            next ATTACHMENT_ID if lc $Param{Attachments}->{$AttachmentID}->{ContentID} ne lc "<$ContentID>";
            $ContentID = $AttachmentLink . $AttachmentID . $SessionID;
            last ATTACHMENT_ID;
        }

        # return new runtime url
        $Start . $ContentID . $End;
    }egxi;

    # bug #5053
    # inline images using Content-Location as identifier instead of Content-ID even RFC2557
    # http://www.ietf.org/rfc/rfc2557.txt

    # find matching attachment and replace it with runtlime url to image
    ATTACHMENT:
    for my $AttachmentID ( sort keys %{ $Param{Attachments} } ) {
        next ATTACHMENT if !$Param{Attachments}->{$AttachmentID}->{ContentID};

        # content id cleanup
        $Param{Attachments}->{$AttachmentID}->{ContentID} =~ s/^<//;
        $Param{Attachments}->{$AttachmentID}->{ContentID} =~ s/>$//;

        next ATTACHMENT if !$Param{Attachments}->{$AttachmentID}->{ContentID};

        $Param{Data}->{Content} =~ s{
        (=|"|')(\Q$Param{Attachments}->{$AttachmentID}->{ContentID}\E)("|'|>|\/>|\s)
    }
    {
        my $Start= $1;
        my $ContentID = $2;
        my $End = $3;

        # improve html quality
        if ( $Start ne '"' && $Start ne '\'' ) {
            $Start .= '"';
        }
        if ( $End ne '"' && $End ne '\'' ) {
            $End = '"' . $End;
        }

        # return new runtime url
        $ContentID = $AttachmentLink . $AttachmentID . $SessionID;
        $Start . $ContentID . $End;
    }egxi;
    }

    return %{ $Param{Data} };
}

=item RichTextDocumentCleanup()

please see L<Kernel::System::HTML::Layout::DocumentCleanup()>

=cut

sub RichTextDocumentCleanup {
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

    $Param{String} = $Kernel::OM->Get('HTMLUtils')->DocumentCleanup(
        String => $Param{String},
    );

    return $Param{String};
}

=begin Internal:

=cut

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

=item WrapPlainText()

This sub has two main functionalities:
1. Check every line and make sure that "\n" is the ending of the line.
2. If the line does _not_ start with ">" (e.g. not cited text)
wrap it after the number of "MaxCharacters" (e.g. if MaxCharacters is "80" wrap after 80 characters).
Do this _just_ if the line, that should be wrapped, contains space characters at which the line can be wrapped.

If you need more info to understand what it does, take a look at the UnitTest WrapPlainText.t to see
use cases there.

my $WrappedPlainText = $LayoutObject->WrapPlainText(
    PlainText     => "Some Plain text that is longer than the amount stored in MaxCharacters",
    MaxCharacters => 80,
);

=cut

sub WrapPlainText {
    my ( $Self, %Param ) = @_;

    # Return if we did not get MaxCharacters
    # or MaxCharacters doesn't contain just an int
    if ( !IsPositiveInteger( $Param{MaxCharacters} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Got no or invalid MaxCharacters!",
        );
        return;
    }

    # Return if we didn't get PlainText
    if ( !defined $Param{PlainText} ) {
        return;
    }

    # Return if we got no Scalar
    if ( ref $Param{PlainText} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Had no string in PlainText!",
        );
        return;
    }

    # Return PlainText if we have less than MaxCharacters
    if ( length $Param{PlainText} < $Param{MaxCharacters} ) {
        return $Param{PlainText};
    }

    my $WorkString = $Param{PlainText};

    # Normalize line endings to avoid problems with \r\n (bug#11078).
    $WorkString =~ s/\r\n?/\n/g;
    $WorkString =~ s/(^>.+|.{4,$Param{MaxCharacters}})(?:\s|\z)/$1\n/gm;
    return $WorkString;
}

#COMPAT: to 3.0.x and lower (can be removed later)
sub TransfromDateSelection {
    my $Self = shift;

    return $Self->TransformDateSelection(@_);
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
