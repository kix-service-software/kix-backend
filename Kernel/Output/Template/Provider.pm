# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::Template::Provider;

use strict;
use warnings;

use base qw (Template::Provider);

use Scalar::Util qw();
use Template::Constants;

our @ObjectDependencies = (
    'Config',
    'Cache',
    'Encode',
    'Log',
    'Main',
);

## no critic qw(ControlStructures::ProhibitNegativeExpressionsInUnlessAndUntilConditions Subroutines::ProhibitUnusedPrivateSubroutines RegularExpressions::ProhibitComplexRegexes)

# Force the use of our own document class.
$Template::Provider::DOCUMENT = $Kernel::OM->GetModuleFor('Output::Template::Document');

=head1 NAME

Kernel::Output::Template::Provider - Template Toolkit custom provider

=head1 PUBLIC INTERFACE

=over 4

=cut

=item KIXInit()

performs some post-initialization and creates a bridget between Template::Toolkit
and KIX by adding the KIX objects to the Provider object. This method must be
called after instantiating the Provider object.

Please note that we only store a weak reference to the LayoutObject to avoid ring
references.

=cut

sub KIXInit {
    my ( $Self, %Param ) = @_;

    # required the document handler
    $Kernel::OM->Get('Main')->Require($Template::Provider::DOCUMENT) || die "Unable to require document handler!";

    # Don't fetch LayoutObject via ObjectManager as there might be several instances involved
    #   at this point (for example in LinkObject there is an own LayoutObject to avoid block
    #   name collisions).
    $Self->{LayoutObject} = $Param{LayoutObject} || die "Got no LayoutObject!";

    #
    # Store a weak reference to the LayoutObject to avoid ring references.
    #   We need it for the filters.
    #
    Scalar::Util::weaken( $Self->{LayoutObject} );

    # define cache type
    $Self->{CacheType} = 'TemplateProvider';

    # caching can be disabled for debugging reasons
    $Self->{CachingEnabled} = $Kernel::OM->Get('Config')->Get('Frontend::TemplateCache') // 1;

    return 1;
}

=item _fetch()

try to get a compiled version of a template from the CacheObject,
otherwise compile the template and return it.

Copied and slightly adapted from Template::Provider.

A note about caching: we have three levels of caching.

    1. we have an in-memory cache that stores the compiled Document objects (fastest).
    2. we store the parsed data in the CacheObject to be re-used in another request.
    3. for string templates, we have an in-memory cache in the parsing method _compile().
        It will return the already parsed object if it sees the same template content again.

=cut

sub _fetch {
    my ( $self, $name, $t_name ) = @_;
    my $stat_ttl = $self->{STAT_TTL};

    $self->debug("_fetch($name)") if $self->{DEBUG};

    # Check in-memory template cache if we already had this template.
    $self->{_TemplateCache} //= {};

    if ( $self->{_TemplateCache}->{$name} ) {
        return $self->{_TemplateCache}->{$name};
    }

    # See if we already know the template is not found
    if ( $self->{NOTFOUND}->{$name} ) {
        return ( undef, Template::Constants::STATUS_DECLINED );
    }

    # Check if the template exists, is cacheable and if a cached version exists.
    if ( -e $name && $self->{CachingEnabled} ) {

        my $template_mtime = $self->_template_modified($name);
        my $CacheKey       = $self->_compiled_filename($name) . '::' . $template_mtime;

        # Is there an up-to-date compiled version in the cache?
        my $Cache = $Kernel::OM->Get('Cache')->Get(
            Type => $self->{CacheType},
            Key  => $CacheKey,
        );

        if ( ref $Cache ) {

            my $compiled_template = $Template::Provider::DOCUMENT->new($Cache);

            # Store in-memory and return the compiled template
            if ($compiled_template) {

                # Make sure template cache does not get too big
                if ( keys %{ $self->{_TemplateCache} } > 1000 ) {
                    $self->{_TemplateCache} = {};
                }

                $self->{_TemplateCache}->{$name} = $compiled_template;

                return $compiled_template;
            }

            # Problem loading compiled template: warn and continue to fetch source template
            warn( $self->error(), "\n" );
        }
    }

    # load template from source
    my ( $template, $error ) = $self->_load( $name, $t_name );

    if ($error) {

        # Template could not be fetched.  Add to the negative/notfound cache.
        $self->{NOTFOUND}->{$name} = time;
        return ( $template, $error );
    }

    # compile template source
    ( $template, $error ) = $self->_compile( $template, $self->_compiled_filename($name) );

    if ($error) {

        # return any compile time error
        return ( $template, $error );
    }

    # Make sure template cache does not get too big
    if ( keys %{ $self->{_TemplateCache} } > 1000 ) {
        $self->{_TemplateCache} = {};
    }

    $self->{_TemplateCache}->{$name} = $template->{data};

    return $template->{data};

}

=item _load()

calls our pre processor when loading a template.

Inherited from Template::Provider.

=cut

sub _load {
    my ( $Self, $Name, $Alias ) = @_;

    my @Result = $Self->SUPER::_load( $Name, $Alias );

    # If there was no error, pre-process our template
    if ( ref $Result[0] ) {

        $Result[0]->{text} = $Self->_PreProcessTemplateContent(
            Content      => $Result[0]->{text},
            TemplateFile => $Result[0]->{name},
        );
    }

    return @Result;
}

=item _compile()

compiles a .tt template into a Perl package and uses the CacheObject
to cache it.

Copied and slightly adapted from Template::Provider.

=cut

sub _compile {
    my ( $self, $data, $compfile ) = @_;
    my $text = $data->{text};
    my ( $parsedoc, $error );

    if ( $self->{DEBUG} ) {
        $self->debug(
            "_compile($data, ",
            defined $compfile ? $compfile : '<no compfile>', ')'
        );
    }

    # Check in-memory parser cache if we already had this template content
    $self->{_ParserCache} //= {};

    if ( $self->{_ParserCache}->{$text} ) {
        return $self->{_ParserCache}->{$text};
    }

    my $parser = $self->{PARSER}
        ||= Template::Config->parser( $self->{PARAMS} )
        || return ( Template::Config->error(), Template::Constants::STATUS_ERROR );

    # discard the template text - we don't need it any more
    delete $data->{text};

    # call parser to compile template into Perl code
    if ( $parsedoc = $parser->parse( $text, $data ) ) {

        $parsedoc->{METADATA} = {
            'name'    => $data->{name},
            'modtime' => $data->{time},
            %{ $parsedoc->{METADATA} },
        };

        # write the Perl code to the file $compfile, if defined
        if ($compfile) {
            my $CacheKey = $compfile . '::' . $data->{time};

            if ( $self->{CachingEnabled} ) {
                $Kernel::OM->Get('Cache')->Set(
                    Type  => $self->{CacheType},
                    TTL   => 60 * 60 * 24,
                    Key   => $CacheKey,
                    Value => $parsedoc,
                );
            }
        }

        if ( $data->{data} = $Template::Provider::DOCUMENT->new($parsedoc) ) {

            # Make sure parser cache does not get too big
            if ( keys %{ $self->{_ParserCache} } > 1000 ) {
                $self->{_ParserCache} = {};
            }

            $self->{_ParserCache}->{$text} = $data;

            return $data;
        }
        $error = $Template::Document::ERROR;
    }
    else {
        $error = Template::Exception->new( 'parse', "$data->{ name } " . $parser->error() );
    }

    # return STATUS_ERROR, or STATUS_DECLINED if we're being tolerant
    return $self->{TOLERANT}
        ? ( undef, Template::Constants::STATUS_DECLINED )
        : ( $error, Template::Constants::STATUS_ERROR )
}

=item store()

inherited from Template::Provider. This function override just makes sure that the original
in-memory cache cannot be used.

=cut

sub store {
    my ( $Self, $Name, $Data ) = @_;

    return $Data;    # no-op
}

=item _PreProcessTemplateContent()

this is our template pre processor.

It handles some KIX specific tags like [% InsertTemplate("TemplateName.tt") %]
and also performs compile-time code injection (ChallengeToken element into forms).

Besides that, it also makes sure the template is treated as UTF8.

This is run at compile time. If a template is cached, this method does not have to be executed on it
any more.

=cut

sub _PreProcessTemplateContent {
    my ( $Self, %Param ) = @_;

    my $Content = $Param{Content};

    # Make sure the template is treated as utf8.
    $Kernel::OM->Get('Encode')->EncodeInput( \$Content );

    my $TemplateFileWithoutTT = substr( $Param{TemplateFile}, 0, -3 );

    #
    # Include other templates into this one before parsing.
    # [% IncludeTemplate("DatePicker.tt") %]
    #
    my $ReplaceCounter = 0;
    my $Replaced;
    do {
        $Replaced = $Content =~ s{
            \[% -? \s* InsertTemplate \( \s* ['"]? (.*?) ['"]? \s* \) \s* -? %\]\n?
            }{
                # Load the template via the provider.
                # We'll use SUPER::load here because we don't need the preprocessing twice.
                my $TemplateContent = ($Self->SUPER::load($1))[0];
                $Kernel::OM->Get('Encode')->EncodeInput(\$TemplateContent);

                # Remove commented lines already here because of problems when the InsertTemplate tag
                #   is not on the beginning of the line.
                $TemplateContent =~ s/^#.*\n//gm;
                $TemplateContent;
            }esmxg;

    } while ( $Replaced && ++$ReplaceCounter <= 100 );

    #
    # Remove DTL-style comments (lines starting with #)
    #
    $Content =~ s/^#.*\n//gm;

    #
    # Insert a BLOCK call into the template.
    # [% RenderBlock('b1') %]...[% END %]
    # becomes
    # [% PerformRenderBlock('b1') %][% BLOCK 'b1' %]...[% END %]
    # This is what we need: define the block and call it from the RenderBlock macro
    # to render it based on available block data from the frontend modules.
    #
    $Content =~ s{
        \[% -? \s* RenderBlockStart \( \s* ['"]? (.*?) ['"]? \s* \) \s* -? %\]
        }{[% PerformRenderBlock("$1") %][% BLOCK "$1" -%]}smxg;

    $Content =~ s{
        \[% -? \s* RenderBlockEnd \( \s* ['"]? (.*?) ['"]? \s* \) \s* -? %\]
        }{[% END -%]}smxg;

    #
    # Add challenge token field to all internal forms
    #
    # (?!...) is a negative look-ahead, so "not followed by https?:"
    # \K is a new feature in perl 5.10 which excludes anything prior
    # to it from being included in the match, which means the string
    # matched before it is not being replaced away.
    # performs better than including $1 in the substitution.
    #
    $Content =~ s{
            <form[^<>]+action="(?!https?:)[^"]*"[^<>]*>\K
        }{[% IF Env("UserChallengeToken") %]<input type="hidden" name="ChallengeToken" value="[% Env("UserChallengeToken") | html %]"/>[% END %][% IF Env("SessionID") && !Env("SessionIDCookie") %]<input type="hidden" name="[% Env("SessionName") %]" value="[% Env("SessionID") | html %]"/>[% END %]}smxig;

    return $Content;

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
