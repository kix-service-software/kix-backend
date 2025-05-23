# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Layout::Template;

use strict;
use warnings;

use Scalar::Util qw();
use Template;
use Template::Stash::XS;
use Template::Context;
use Template::Plugins;

use Kernel::Output::Template::Provider;

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::Output::HTML::LayoutTemplate - template rendering engine based on Template::Toolkit

=head1 PUBLIC INTERFACE

=over 4

=item Output()

generates HTML output based on a template file.

Using a template file:

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'AdminLog.tt',
        Data         => \%Param,
    );

Using a template string:

    my $HTML = $LayoutObject->Output(
        Template => '<b>[% Data.SomeKey | html %]</b>',
        Data     => \%Param,
    );

Additional parameters:

    KeepScriptTags - this causes [% WRAPPER JSOnDocumentComplete %] blocks NOT
        to be replaced. This is important to be able to generate snippets which can be cached.

    my $HTML = $LayoutObject->Output(
        TemplateFile   => 'AdminLog.tt',
        Data           => \%Param,
        KeepScriptTags => 1,
    );

=cut

sub Output {
    my ( $Self, %Param ) = @_;

    $Param{Data} ||= {};

    # get and check param Data
    if ( ref $Param{Data} ne 'HASH' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need HashRef in Param Data! Got: '" . ref( $Param{Data} ) . "'!",
        );
        die "Need HashRef in Param Data! Got: '" . ref( $Param{Data} ) . "'!\n";
    }

    # fill init Env
    if ( !$Self->{EnvRef} ) {
        %{ $Self->{EnvRef} } = %ENV;

        # all $Self->{*}
        for ( sort keys %{$Self} ) {
            if ( defined $Self->{$_} && !ref $Self->{$_} ) {
                $Self->{EnvRef}->{$_} = $Self->{$_};
            }
        }
    }

    # add new env
    if ( $Self->{EnvNewRef} ) {
        for my $Key ( sort keys %{ $Self->{EnvNewRef} } ) {
            $Self->{EnvRef}->{$Key} = $Self->{EnvNewRef}->{$Key};
        }
        undef $Self->{EnvNewRef};
    }

    # if we use the HTML5 input type 'email' jQuery Validate will always validate
    # we do not want that if CheckEmailAddresses is set to 'no' in SysConfig
    $Self->{EnvRef}->{EmailFieldType}
        = $Kernel::OM->Get('Config')->Get('CheckEmailAddresses') ? 'email' : 'text';

    # TODO: new solution needed for extensions
    # my @TemplateFolders = (
    #     "$Self->{CustomTemplateDir}",
    #     "$Self->{CustomStandardTemplateDir}",
    #     "$Self->{TemplateDir}",
    #     "$Self->{StandardTemplateDir}",
    # );
    #
    # my @KIXTemplateFolders = ();
    # foreach my $TmpDir (@INC) {
    #     last if $TmpDir =~ /\/bin\/Custom$/;
    #     next if grep { $_ eq $TmpDir."/Kernel/Output/HTML/Templates/Standard" } @KIXTemplateFolders;
    #     push @KIXTemplateFolders, $TmpDir."/Kernel/Output/HTML/Templates/Standard";
    # }
    #
    # @TemplateFolders = ( @KIXTemplateFolders, @TemplateFolders );
    my @TemplateFolders = (
        "$Self->{TemplateDir}"
    );

    my $TemplateString;

    # take templates from string/array
    if (defined $Param{Template} && ref $Param{Template} eq 'ARRAY') {
        $TemplateString = join('', @{$Param{Template}});
    }
    elsif (defined $Param{Template}) {
        $TemplateString = $Param{Template};
    }
    elsif ($Param{TemplateFile}) {
        $Param{TemplateFileTT} .= "$Param{TemplateFile}.tt";
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need Template or TemplateFile Param!',
        );
        die "Need Template or TemplateFile Param!\n";
    }

    if ( !$Self->{TemplateObject} ) {

        $Self->{TemplateProviderObject} = Kernel::Output::Template::Provider->new(
            {
                INCLUDE_PATH => \@TemplateFolders,
                EVAL_PERL    => 1,
                COMPILE_EXT  => '.ttc',
            }
        );
        $Self->{TemplateProviderObject}->KIXInit(
            LayoutObject => $Self,
        );

        my $Plugins = Template::Plugins->new(
            {
                PLUGIN_BASE => $Kernel::OM->GetModuleFor('Output::Template::Plugin'),
            }
        );

        my $Context = Template::Context->new(
            {
                EVAL_PERL      => 1,
                STASH          => Template::Stash::XS->new(),
                LOAD_TEMPLATES => [ $Self->{TemplateProviderObject} ],
                LOAD_PLUGINS   => [$Plugins],
            }
        );

        # Store a weak reference to the LayoutObject in the context
        #   to avoid ring references. We need it for the plugins.
        $Context->{LayoutObject} = $Self;
        Scalar::Util::weaken( $Context->{LayoutObject} );

        my $Success = $Self->{TemplateObject} = Template->new(
            {
                CONTEXT => $Context,

                #DEBUG => Template::Constants::DEBUG_ALL,
            }
        );

        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "$Template::ERROR;",
            );
            die "$Template::ERROR\n";
        }
    }

    my $Output;
    my $Success = $Self->{TemplateObject}->process(
        $Param{TemplateFileTT} // \$TemplateString,
        {
            Data => $Param{Data} // {},
            global => {
                BlockData      => $Self->{BlockData}     // [],
                KeepScriptTags => $Param{KeepScriptTags} // 0,
            },
        },
        \$Output,
    );
    if ( !$Success ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => $Self->{TemplateObject}->error(),
        );
        die $Self->{TemplateObject}->error() . "\n";
    }

    # If the browser does not send the session cookie, we need to append it to all links and image urls.
    #   We cannot do this in the template preprocessor because links are often dynamically generated.
    if ( $Self->{SessionID} && !$Self->{SessionIDCookie} ) {

        # rewrite a hrefs
        $Output =~ s{
            (<a.+?href=")(.+?)(\#.+?|)(".+?>)
        }
        {
            my $AHref   = $1;
            my $Target  = $2;
            my $End     = $3;
            my $RealEnd = $4;
            if ( lc($Target) =~ /^(http:|https:|#|ftp:)/ ||
                $Target !~ /\.(pl|php|cgi|fcg|fcgi|fpl)(\?|$)/ ||
                $Target =~ /(\?|&|;)\Q$Self->{SessionName}\E=/) {
                $AHref.$Target.$End.$RealEnd;
            }
            else {
                $AHref.$Target.';'.$Self->{SessionName}.'='.$Self->{SessionID}.$End.$RealEnd;
            }
        }iegxs;

        # rewrite img and iframe src
        $Output =~ s{
            (<(?:img|iframe).+?src=")(.+?)(".+?>)
        }
        {
            my $AHref = $1;
            my $Target = $2;
            my $End = $3;
            if (lc($Target) =~ m{^http s? :}smx || !$Self->{SessionID} ||
                $Target !~ /\.(pl|php|cgi|fcg|fcgi|fpl)(\?|$)/ ||
                $Target =~ /\Q$Self->{SessionName}\E=/) {
                $AHref.$Target.$End;
            }
            else {
                $AHref.$Target.'&'.$Self->{SessionName}.'='.$Self->{SessionID}.$End;
            }
        }iegxs;
    }

    return $Output;
}

=item AddJSOnDocumentComplete()

dynamically add JavaScript code that should be executed in Core.App.Ready().
Call this for any dynamically generated code that is not in a template.

    $LayoutObject->AddJSOnDocumentComplete(
        Code => $MyCode,
    );

=cut

sub AddJSOnDocumentComplete {
    my ( $Self, %Param ) = @_;

    $Self->{_JSOnDocumentComplete} //= [];
    push( @{ $Self->{_JSOnDocumentComplete} }, $Param{Code} );

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
