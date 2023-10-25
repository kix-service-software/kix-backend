# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package HTML::WikiConverter::Jira;
use base 'HTML::WikiConverter';

use warnings;
use strict;

use URI;
use File::Basename;
our $VERSION = '0.01';

sub attributes {
    my( $Self, $Node, $Rules ) = @_;

    return {
        preserve_italic        => { default => 0 },
        preserve_bold          => { default => 0 },
        strip_tags             => { default => [ qw/ head style script ~comment title meta link object / ] },
        pad_headings           => { default => 0 },
        preserve_templates     => { default => 0 },
        preserve_nowiki        => { default => 0 },
        passthrough_naked_tags => { default => [ qw/ tbody thead font span / ] },
    };
}

sub rules {
    my $Self = shift;

    my %Rules = (
        # headings
        h1 => { start => 'h1. ', line_format => 'single', trim => 'both', block => 1 },
        h2 => { start => 'h2. ', line_format => 'single', trim => 'both', block => 1 },
        h3 => { start => 'h3. ', line_format => 'single', trim => 'both', block => 1 },
        h4 => { start => 'h4. ', line_format => 'single', trim => 'both', block => 1 },
        h5 => { start => 'h5. ', line_format => 'single', trim => 'both', block => 1 },
        h6 => { start => 'h6. ', line_format => 'single', trim => 'both', block => 1 },

        # text
        strong => { start => '*',  end => '*',  line_format => 'single' },
        em     => { start => '_',  end => '_',  line_format => 'single' },
        cite   => { start => '??', end => '??', line_format => 'single' },
        del    => { start => '-',  end => '-',  line_format => 'single' },
        ins    => { start => '+',  end => '+',  line_format => 'single' },
        sup    => { start => '^',  end => '^',  line_format => 'single' },
        sub    => { start => '~',  end => '~',  line_format => 'single' },
        tt     => { start => '{{', end => '}}', line_format => 'single' },
        # text aliases
        i => { alias => 'em' },
        b => { alias => 'strong' },

        # blockquote
        blockquote => { start => 'bq. ', line_format => 'single', block => 1 },

        # line breaks
        br => { replace => "\n\n" },
        hr => { replace => "\n\n----\n\n" },

        # link
        a => { replace => \&_link },

        # image
        img => { replace => \&_image },

        # paragraph
        p => { block => 1, trim => 'both', line_format => 'blocks' },

        # list
        ul => { line_format => 'multi', block => 1 },
        ol => { alias => 'ul' },
        dl => { alias => 'ul' },

        li => { start => \&_li_start, trim => 'leading' },
        dt => { alias => 'li' },
        dd => { alias => 'li' },

        # table
        table   => { block => 1, line_format => 'blocks' },
        tr      => { start => "\n", line_format => 'single' },
        td      => { start => \&_td_start,      end => " |",  trim => 'both', line_format => 'blocks' },
        th      => { start => \&_th_start,      end => " ||", trim => 'both', line_format => 'single' },
        caption => { start => \&_caption_start, end => " |",  trim => 'both', line_format => 'single' },
    );

    return \%Rules;
}

sub _link {
    my( $Self, $Node, $Rules ) = @_;

    my $URL  = defined( $Node->attr('href') ) ? $Node->attr('href') : '';
    my $Text = $Self->get_elem_contents( $Node );

    # Treat them as external links
    return '[' . $URL . ']' if ( $URL eq $Text );
    return '[' . $Text . '|' . $URL . ']';
}

sub _image {
    my( $Self, $Node, $Rules ) = @_;

    return '' if ( !$Node->attr('src') );
    return '!' . $Node->attr('src') . '!';
}

# Calculates the prefix that will be placed before each list item.
# Handles ordered, unordered, and definition list items.
sub _li_start {
    my( $Self, $Node, $Rules ) = @_;

    my @ParentsList = $Node->look_up( _tag => qr/ul|ol|dl/ );
    my $Parent      = $Node->parent();
    my $Bullet      = '';
    if ( $Parent->tag() eq 'ul' ) {
        $Bullet = '*';
    }
    elsif ( $Parent->tag() eq 'ol' ) {
        $Bullet = '#';
    }
    elsif (
        $Parent->tag() eq 'dl'
        && $Node->tag() eq 'dt'
    ) {
        $Bullet = ':';
    }
    elsif ( $Parent->tag() eq 'dl' ) {
        $Bullet = ';';
    }

    my $Prefix = '';
    foreach my $Entry ( @ParentsList ) {
        $Prefix .= $Bullet;
    }

    return "\n" . $Prefix . ' ';
}

sub _td_start {
    my( $Self, $Node, $Rules ) = @_;

    my $ParentIndex = $Node->pindex();

    if (
        defined( $ParentIndex )
        && $ParentIndex == 0
    ) {
        return '| ';
    }

    return ' ';
}

sub _th_start {
    my( $Self, $Node, $Rules ) = @_;

    my $ParentIndex = $Node->pindex();

    if (
        defined( $ParentIndex )
        && $ParentIndex == 0
    ) {
        return '|| ';
    }

  return ' ';
}

sub _caption_start {
    my( $Self, $Node, $Rules ) = @_;

    my $ParentIndex = $Node->pindex();

    if (
        defined( $ParentIndex )
        && $ParentIndex == 0
    ) {
        return '| ';
    }

    return ' ';
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