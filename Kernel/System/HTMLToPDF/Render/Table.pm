# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
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

    if (
        IsHashRefWithData( $Param{ReplaceableLabel} )
        && !defined $Self->{ReplaceableLabel}
    ) {
        $Self->{ReplaceableLabel} = $Param{ReplaceableLabel};
    }

    my $Block = $Param{Block};
    my $IDKey = $Param{IDKey};
    my $Css   = q{};

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
            TemplateFile => 'HTMLToPDF/Table',
        );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => 'PDF Convert: Can\'t set CSS for block type "Table", because no given ID.'
        );
    }

    $LayoutObject->Block(
        Name => 'HTML',
        Data => {
            ID => $Block->{ID}
        }
    );

    if ( $Block->{SubType} eq 'Custom' ) {
        $Self->_TableCustom(
            Block        => $Block,
            Data         => $Param{Data},
            Object       => $Param{Object},
            ObjectID     => $Param{ObjectID},
            MainObject   => $Param{MainObject},
            MainObjectID => $Param{MainObjectID},
            UserID       => $Param{UserID}
        );
    }
    elsif ( $Block->{SubType} eq 'DataSet' ) {
        $Self->_TableDataSet(
            Block   => $Block,
            Data    => $Param{Data},
            Ignores => $Param{Ignores},
            Allows  => $Param{Allows}
        );
    }
    elsif ( $Block->{SubType} eq 'XMLStructure' ) {
        $Self->_TableXMLStructure(
            Block   => $Block,
            Data    => $Param{Data},
            Ignores => $Param{Ignores},
            Allows  => $Param{Allows}
        );
    }
    else {
        $Self->_TableKeyValue(
            Block   => $Block,
            Data    => $Param{Data},
            Ignores => $Param{Ignores},
            Allows  => $Param{Allows}
        );
    }

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Table',
    );
    return (
        HTML => $HTML,
        Css  => $Css
    );
}

sub _TableCustom {
    my ($Self, %Param) = @_;

    my $LayoutObject  = $Kernel::OM->Get('Output::HTML::Layout');

    my $Block = $Param{Block};

    my @AddClass;
    my @Columns;

    $Self->_RenderHeader(
        Columns  => \@Columns,
        AddClass => \@AddClass,
        SubType  => 'Custom',
        Block    => $Block,
        Datas    => $Param{Data},
        Object   => $Param{Object}
    );

    for my $Row ( @{$Block->{Rows}} ) {
        $LayoutObject->Block(
            Name => 'BodyRow'
        );
        for my $Cell ( keys @Columns ) {
            my %Entry = $Self->ReplacePlaceholders(
                String       => $Row->[$Cell],
                Datas        => $Param{Data},
                Translate    => $Block->{Translate},
                Object       => $Param{Object},
                ObjectID     => $Param{ObjectID},
                MainObject   => $Param{MainObject},
                MainObjectID => $Param{MainObjectID},
                UserID       => $Param{UserID},
                ReplaceAs    => $Block->{ReplaceAs} // q{-}
            );

            if ( $Block->{Translate} ) {
                $Entry{Text} = $LayoutObject->{LanguageObject}->Translate($Entry{Text});
            }

            my $Classes = $AddClass[$Cell];
            if ( $Entry{Class} ) {
                $Classes .= q{ } if $Classes;
                $Classes .= $Entry{Class};
            }

            $LayoutObject->Block(
                Name => 'BodyCol',
                Data => {
                    Value => $Entry{Text},
                    Class => $Classes
                }
            );
        }
    }

    return 1;
}

sub _TableKeyValue {
    my ($Self, %Param) = @_;

    my $Block = $Param{Block};

    my %AddClass;
    my @Columns;
    my $IsDefault = $Self->_RenderHeader(
        Columns  => \@Columns,
        AddClass => \%AddClass,
        SubType  => 'KeyValue',
        Block    => $Block
    );

    $Self->_RenderBody(
        Columns  => \@Columns,
        AddClass => \%AddClass,
        Block    => $Block,
        SubType  => 'KeyValue',
        Datas    => $Param{Data},
        Ignores  => $Param{Ignores},
        Allows   => $Param{Allows}
    );

    return 1;
}

sub _TableDataSet {
    my ($Self, %Param) = @_;

    my $Block = $Param{Block};

    my %AddClass;
    my @Columns;
    my $IsDefault = $Self->_RenderHeader(
        Columns  => \@Columns,
        AddClass => \%AddClass,
        SubType  => 'DataSet',
        Block    => $Block
    );

    $Self->_RenderBody(
        Columns   => \@Columns,
        AddClass  => \%AddClass,
        Block     => $Block,
        SubType   => 'DataSet',
        Datas     => $Param{Data},
        Ignores   => $Param{Ignores},
        Allows    => $Param{Allows}
    );

    return 1;
}

sub _TableXMLStructure {
    my ($Self, %Param) = @_;

    my $Block = $Param{Block};

    for my $Line ( @{ $Param{Data} } ) {
        $Kernel::OM->Get('Output::HTML::Layout')->Block(
            Name => 'BodyRow'
        );
        my $KeyText   = $Line->{Key};
        my $ValueText = $Line->{Value} || q{};
        if ( $Block->{Translate} ) {
            $KeyText   = $Kernel::OM->Get('Output::HTML::Layout')->{LanguageObject}->Translate($KeyText);
            if ( $Line->{IsDate} ) {
                $ValueText = $Kernel::OM->Get('Output::HTML::Layout')->{LanguageObject}->FormatTimeString($ValueText . ' 00:00:00' ,'DateFormatShort');
            }
            if ( $Line->{IsDateTime} ) {
                $ValueText = $Kernel::OM->Get('Output::HTML::Layout')->{LanguageObject}->FormatTimeString($ValueText,'DateFormat');
            }
            else {
                $ValueText = $Kernel::OM->Get('Output::HTML::Layout')->{LanguageObject}->Translate($ValueText);
            }
        }

        $Kernel::OM->Get('Output::HTML::Layout')->Block(
            Name => 'BodyCol',
            Data => {
                Value => $KeyText . q{:},
                Class => 'Col1 ' . $Line->{Class},
                Span  => $Line->{FullRow} ? 2 : q{}
            }
        );

        $Kernel::OM->Get('Output::HTML::Layout')->Block(
            Name => 'BodyCol',
            Data => {
                Value => $ValueText,
                Class => 'Col2'
            }
        );
    }

    return 1;
}

sub _RenderHeader {
    my ($Self, %Param) = @_;

    my $LayoutObject  = $Kernel::OM->Get('Output::HTML::Layout');

    my $IsDefault = 0;
    my $Block     = $Param{Block};

    if ( IsArrayRefWithData($Block->{Columns}) ) {
        for my $Column ( @{$Block->{Columns}} ) {
            next if !$Column && $Param{SubType} ne 'Custom';
            my %Entry = $Self->ReplacePlaceholders(
                String       => $Column,
                Datas        => $Param{Datas},
                Object       => $Param{Object},
                ObjectID     => $Param{ObjectID},
                MainObject   => $Param{MainObject},
                MainObjectID => $Param{MainObjectID},
                Translate    => $Block->{Translate},
                UserID       => $Param{UserID},
                ReplaceAs    => $Block->{ReplaceAs} // q{-}
            );

            if ( $Param{SubType} ne 'Custom' ) {
                $Param{AddClass}->{$Entry{Text}} = $Entry{Class};
            }
            else {
                push(@{$Param{AddClass}}, $Entry{Class});
            }
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
                $Param{SubType} ne 'KeyValue'
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
        $Param{SubType} eq 'KeyValue'
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
                Columns    => $Param{Columns},
                Key        => $Key,
                Data       => $Datas,
                Translate  => $Block->{Translate},
                Join       => $Block->{Join},
                ReplaceKey => $Block->{ReplaceKey},
                Count      => $Count,
                Classes    => $Param{AddClass}
            );
            $Count++;
        }
    }
    if (
        $Param{SubType} eq 'DataSet'
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
            && $Value !~ m/$Allow{$Attribute}/sm;
    }

    if (
        %Ignore
        && defined $Ignore{$Attribute}
    ) {
        return 0 if $Ignore{$Attribute} eq 'KEY';
        return 0 if $Value =~ m/$Ignore{$Attribute}/sm;
    }

    return 1;
}

sub _ColumnValueGet {
    my ($Self, %Param) = @_;

    my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

    my $Columns    = $Param{Columns};
    my $Key        = $Param{Key};
    my $Data       = $Param{Data};
    my $Translate  = $Param{Translate};
    my $ReplaceKey = $Param{ReplaceKey};
    my $Join       = $Param{Join};
    my $Classes    = $Param{Classes};

    for my $Column ( @{$Columns} ) {
        my $Value;
        $Key = $Column if !$Key;

        if ( $Column eq 'Count' ) {
            $Value = $Param{Count};
        }

        if ( $Column eq 'Key' ) {
            $Value = $Key;
            if ( $Key =~ /^DynamicField_/sm ) {
                $Value = $Data->{$Key}->{Label};
            }
            elsif ( $ReplaceKey ) {
                $Value = $Self->_ReplaceSpecialKey(
                    Text       => $Value,
                    ReplaceKey => $ReplaceKey
                );
            }
        }

        if ( $Column eq 'Value' ) {
            $Value = $Data->{$Key};
            if ( $Key =~ /^DynamicField_/sm ) {
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
                $Key =~ /^(?:Create|Change)(?:d|Time)$/sm
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
