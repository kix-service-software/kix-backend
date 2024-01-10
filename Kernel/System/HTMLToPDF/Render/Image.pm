# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Render::Image;

use strict;
use warnings;

use base qw(
    Kernel::System::HTMLToPDF::Render::Common
);

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);

sub Run {
    my ($Self, %Param) = @_;

    my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');
    my $IconObject   = $Kernel::OM->Get('ObjectIcon');

    my $Datas = $Param{Data};
    my $Block = $Param{Block};
    my $Css   = q{};
    my $Value;

    if (
        $Block->{ID}
        && !$Self->{CSSIDs}->{$Block->{ID}}
    ) {
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
            TemplateFile => 'HTMLToPDF/Image',
        );
        $Self->{CSSIDs}->{$Block->{ID}} = 1;
    }

    if ( $Block->{TypeOf} eq 'DB' ) {
        my $IconIDs = $IconObject->ObjectIconList(
            ObjectID => $Param{Block}->{Value}
        );
        if ( !scalar(@{$IconIDs}) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "HTMLToPDF: image could not be rendered, because icon doesn't exist!"
            );
            return;
        }
        my %Icon = $IconObject->ObjectIconGet(
            ID => $IconIDs->[0]
        );

        $Value = "data:$Icon{ContentType};base64,$Icon{Content}";
    }

    if ( $Block->{TypeOf} eq 'Path' ){
        if ( !-e $Block->{Value} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "HTMLToPDF: image could not be rendered, because file doesn't exist!"
            );
            return;
        }
        elsif ( -z $Block->{Value} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "HTMLToPDF: image could not be rendered because file is empty!"
            );
            return;
        }
        $Value = $Block->{Value};
    }

    if ( $Block->{TypeOf} eq 'Base64' ) {
        $Value = $Block->{Value};
    }

    $LayoutObject->Block(
        Name => 'HTML',
        Data => {
            Value     => $Value,
            Translate => $Block->{Translate},
            ID        => $Block->{ID}
        }
    );

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Image'
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