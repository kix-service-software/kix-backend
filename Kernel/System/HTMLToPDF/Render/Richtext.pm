# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Render::Richtext;

use strict;
use warnings;

use base qw(
    Kernel::System::HTMLToPDF::Render::Common
);

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);

sub Run {
    my ($Self, %Param) = @_;

    my $LayoutObject            = $Kernel::OM->Get('Output::HTML::Layout');
    my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

    my $Datas = $Param{Data};
    my $Block = $Param{Block};
    my $Css   = q{};
    my $Value;

    if ( $Block->{ID} ) {
        $LayoutObject->Block(
            Name => 'CSS',
            Data => $Block
        );

        if ( IsArrayRefWithData($Block->{Style}->{Class}) ) {
            for my $Style ( @{$Block->{Style}->{Class}} ) {
                next if ( !$Style->{Selector} || !$Style->{CSS} );

                $LayoutObject->Block(
                    Name => 'StyleClass',
                    Data => {
                        %{$Block},
                        %{$Style}
                    }
                );
            }
        }

        $Css = $LayoutObject->Output(
            TemplateFile => 'HTMLToPDF/Richtext',
        );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => 'PDF Convert: Can\'t set CSS for block type "Richtext", because no given ID.'
        );
    }

    if ( ref $Block->{Value} eq 'ARRAY' ) {
        my @Values;
        for my $Entry ( @{$Block->{Value}} ) {
            my %Result = $Self->ReplacePlaceholders(
                String       => $Entry,
                UserID       => $Param{UserID},
                Count        => $Param{Count},
                Translate    => $Block->{Translate},
                Object       => $Param{Object},
                ObjectID     => $Param{ObjectID},
                MainObject   => $Param{MainObject},
                MainObjectID => $Param{MainObjectID},
                Datas        => $Datas,
                ReplaceAs    => $Block->{ReplaceAs} // q{-}
            );

            next if $Result{Text} eq q{};

            $Result{Text} =~ s{<p>(<img\salt=""\ssrc=".*\"\s\/>)<\/p>}{$1}gsmx;

            if ( $Block->{Translate} ) {
                $Result{Text} = $LayoutObject->{LanguageObject}->Translate($Result{Text});
            }

            push( @Values, $Result{Text});
        }
        $Value = join( ($Block->{Join} // q{ }), @Values);
    }
    else {
        my %Result = $Self->ReplacePlaceholders(
            String       => $Block->{Value},
            UserID       => $Param{UserID},
            Count        => $Param{Count},
            Translate    => $Block->{Translate},
            Object       => $Param{Object},
            ObjectID     => $Param{ObjectID},
            MainObject   => $Param{MainObject},
            MainObjectID => $Param{MainObjectID},
            Datas        => $Datas,
            ReplaceAs    => $Block->{ReplaceAs} // q{-}
        );

        $Value = $Result{Text};
        $Value =~ s{<p>(<img\salt=""\ssrc=".*\"\s\/>)<\/p>}{$1}gsmx;
    }

    $LayoutObject->Block(
        Name => 'HTML',
        Data => {
            Value  => $Value,
            ID     => $Block->{ID}
        }
    );

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Richtext'
    );

    return (
        HTML => $HTML,
        Css  => $Css
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
