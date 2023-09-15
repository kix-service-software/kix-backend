# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Placeholder::Base;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Log
);

=head1 NAME

KIXPro::Kernel::System::Placeholder::TicketSLAAttributes
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

    $Self->{UserLanguage} = $Param{UserLanguage};

    return $Self;
}

=item ReplacePlaceholder()
    just a wrapper for external access to sub _Replace
=cut

sub ReplacePlaceholder {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text Data UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # allow both styles but do not capture it
    $Self->{Start} = '(?><|&lt;)';
    $Self->{End}   = '(?>>|&gt;)';
    if ( $Param{RichText} ) {
        $Param{Text} =~ s/(\n|\r)//g;
    }

    return $Self->_Replace(
        %Param
    );
}

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    return $Param{Text};
}

sub _HashGlobalReplace {
    my ( $Self, $Text, $Tag, %H ) = @_;

    # Generate one single matching string for all keys to save performance.
    my $Keys = join( q{|}, map {quotemeta} grep { defined $H{$_} } keys %H);

    # Add all keys also as lowercase to be able to match case insensitive,
    #   e. g. <KIX_CUSTOMER_From> and <KIX_CUSTOMER_FROM>.
    for my $Key ( sort keys %H ) {
        $H{ lc $Key } = $H{$Key};
    }
    $Text =~ s/(?:$Tag)($Keys)$Self->{End}/$H{ lc $1 }/ieg;

    return $Text;
};

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
