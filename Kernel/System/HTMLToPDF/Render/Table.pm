# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Render::Table;

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

    my $Block = $Param{Block};
    my $Css   = q{};

    if (
        $Block->{ID}
        && !$Self->{CSSIDs}->{$Block->{ID}}
    ) {
        $LayoutObject->Block(
            Name => 'CSS',
            Data => $Block
        );

        $Css = $LayoutObject->Output(
            TemplateFile => 'HTMLToPDF/Table',
        );
        $Self->{CSSIDs}->{$Block->{ID}} = 1;
    }

    $LayoutObject->Block(
        Name => 'HTML',
        Data => {
            ID => $Block->{ID}
        }
    );

    my %AddClass;
    my @Columns;
    my $IsDefault = $Self->_RenderHeader(
        Columns  => \@Columns,
        AddClass => \%AddClass,
        Block    => $Block
    );

    $Self->_RenderBody(
        Columns   => \@Columns,
        AddClass  => \%AddClass,
        Block     => $Block,
        IsDefault => $IsDefault,
        Datas     => $Param{Data},
        Ignores   => $Param{Ignores},
        Allows    => $Param{Allows}
    );

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Table',
    );
    return (
        HTML => $HTML,
        Css  => $Css
    );
}

sub _RenderHeader {
    my ($Self, %Param) = @_;

    my $LayoutObject  = $Kernel::OM->Get('Output::HTML::Layout');

    my $IsDefault = 0;
    my $Block     = $Param{Block};

    if ( IsArrayRefWithData($Block->{Columns}) ) {
        for my $Column ( @{$Block->{Columns}} ) {
            next if !$Column;
            my %Entry = $Self->_ReplacePlaceholders(
                String => $Column
            );
            if ( $Entry{Text} =~ /^(?:Count|Key|Value)$/smx ) {
                $IsDefault = 1;
            }

            $Param{AddClass}->{$Entry{Text}} = $Entry{Font};
            push(@{$Param{Columns}}, $Entry{Text});
        }
    }

    if ( $Block->{Headline} ) {
        $LayoutObject->Block(
            Name => 'HeadBlock'
        );

        for my $Column ( @{$Param{Columns}} ) {
            my $Col = $Column;
            if (
                !$IsDefault
                && $Block->{Translate}
            ) {
                $Col = $LayoutObject->{LanguageObject}->Translate($Col);
            }

            $LayoutObject->Block(
                Name => 'HeadCol',
                Data => {
                    Value => $Col
                }
            );
        }
    }

    return $IsDefault;
}

sub _RenderBody {
    my ($Self, %Param) = @_;

    my $LayoutObject  = $Kernel::OM->Get('Output::HTML::Layout');

    my %Ignore;
    my %Allow;
    my $Datas = $Param{Datas};
    my $Block = $Param{Block};

    $Self->_CheckTableRestriction(
        Allow   => \%Allow,
        Ignore  => \%Ignore,
        Block   => $Block,
        Ignores => $Param{Ignores},
        Allows  => $Param{Allows}
    );

    my $Count = 0;
    if (
        $Param{IsDefault}
        && ref $Datas eq 'HASH'
    ) {
        for my $Key ( sort keys %{$Datas} ) {
            next if $Key eq 'Expands';
            next if !$Self->_CheckAttribute(
                Allow     => \%Allow,
                Ignore    => \%Ignore,
                Attribute => $Key,
                Value     => $Datas->{$Key}
            );

            $LayoutObject->Block(
                Name => 'BodyRow'
            );

            $Self->_ColumnValueGet(
                Columns   => $Param{Columns},
                Key       => $Key,
                Data      => $Datas,
                Translate => $Block->{Translate},
                Join      => $Block->{Join},
                Count     => $Count,
                Classes   => $Param{AddClass}
            );
            $Count++;
        }
    }
    if (
        !$Param{IsDefault}
        && ref $Datas eq 'ARRAY'
    ) {
        ID:
        for my $ID ( @{$Datas} ) {
            my $IDKey      = $Self->{"Object$Block->{Object}"}->{IDKey};
            my %ObjectData = $Self->{"Object$Block->{Object}"}->DataGet(
                $IDKey => $ID,
                UserID => $Param{UserID}
            );

            for my $Key ( sort keys %ObjectData ) {
                next ID if !$Self->_CheckAttribute(
                    Allow     => \%Allow,
                    Ignore    => \%Ignore,
                    Attribute => $Key,
                    Value     => $ObjectData{$Key}
                );
            }

            $LayoutObject->Block(
                Name => 'BodyRow'
            );

            $Self->_ColumnValueGet(
                Columns   => $Param{Columns},
                Data      => \%ObjectData,
                Translate => $Block->{Translate},
                Join      => $Block->{Join},
                Count     => $Count,
                Classes   => $Param{AddClass}
            );
            $Count++;
        }
    }

    return 1;
}


sub _CheckAttribute {
    my ($Self, %Param) = @_;

    my %Allow     = %{$Param{Allow}};
    my %Ignore    = %{$Param{Ignore}};
    my $Value     = $Param{Value};
    my $Attribute = $Param{Attribute};

    if ( %Allow ) {
        return 0 if !defined $Allow{$Attribute};
        return 0 if $Allow{$Attribute} ne 'KEY'
            && $Value !~ m/$Allow{$Attribute}/smx;
    }

    if (
        %Ignore
        && defined Ignore{$Attribute}
    ) {
        return 0 if $Ignore{$Attribute} eq 'KEY';
        return 0 if $Value =~ m/$Ignore{$Attribute}/smx;
    }

    return 1;
}

sub _ColumnValueGet {
    my ($Self, %Param) = @_;

    my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

    my $Columns   = $Param{Columns};
    my $Key       = $Param{Key};
    my $Data      = $Param{Data};
    my $Translate = $Param{Translate};
    my $Join      = $Param{Join};
    my $Classes   = $Param{Classes};

    for my $Column ( @{$Columns} ) {
        my $Value;
        $Key = $Column if !$Key;

        if ( $Column eq 'Count' ) {
            $Value = $Param{Count};
        }

        if ( $Column eq 'Key' ) {
            $Value = $Key;
            if ( $Key =~ /^DynamicField_/smx ) {
                $Value = $Data->{$Key}->{Label};
            }
        }

        if ( $Column eq 'Value' ) {
            $Value = $Data->{$Key};
            if ( $Key =~ /^DynamicField_/smx ) {
                $Value = $Data->{$Key}->{Value};
            }
        }

        if ( ref $Value eq 'ARRAY' ) {
            for my $Val ( @{$Value} ) {
                if ( $Translate ) {
                    $Val = $LayoutObject->{LanguageObject}->Translate($Val);
                }
            }
            if ( $Join ) {
                $Value = join( $Join, @{$Value});
            }
        } elsif ( $Translate ) {
            if (
                $Key =~ /^(?:Create|Change)(?:d|Time)$/smx
                && $Column eq 'Value'
            ) {
                $Value = $LayoutObject->{LanguageObject}->FormatTimeString( $Value, "DateFormat" );
            }
            else {
                $Value = $LayoutObject->{LanguageObject}->Translate($Value);
            }
        }

        $LayoutObject->Block(
            Name => 'BodyCol',
            Data => {
                Value => $Value,
                Class => $Classes->{$Column}
            }
        );
    }

    return 1;
}

sub _CheckTableRestriction {
    my ($Self, %Param) = @_;

    my $Block = $Param{Block};

    if (
        IsHashRefWithData($Param{Allows})
        && $Param{Allows}->{$Block->{ID}}
    ) {
        %{$Param{Allow}} = %{$Param{Allows}->{$Block->{ID}}};
    }
    elsif (
        $Block->{Allow}
        && IsHashRefWithData($Block->{Allow})
    ) {
        %{$Param{Allow}} = %{$Block->{Allow}};
    }

    if (
        IsHashRefWithData($Param{Ignores})
        && $Param{Ignores}->{$Block->{ID}}
    ) {
        %{$Param{Ignore}} = %{$Param{Ignores}->{$Block->{ID}}};
    }
    elsif (
        $Block->{Ignore}
        && IsHashRefWithData($Block->{Ignore})
    ) {
        %{$Param{Ignore}} = %{$Block->{Ignore}};
    }

    return 1;
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