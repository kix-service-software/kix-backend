# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Render::List;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use base qw(
    Kernel::System::HTMLToPDF::Render::Common
);

use Kernel::System::VariableCheck qw(:all);

sub Run {
    my ($Self, %Param) = @_;

    my $Block   = $Param{Block};
    my $Datas   = $Param{Data};
    my $LObject = $Block->{ListObject} || $Param{Object};
    my $LData   = $Block->{ListData};
    my $LCount  = $Block->{ListCount} || 0;
    my $Empty   = $Block->{ShowEmpty} || 0;
    my $Type    = $Block->{ListStyle} || 'none';
    my $Value;
    my $Class;

    my %LTypes = (
        none => {
            Class => 'NoList',
            Used  => 0
        },
        ul => {
            Class => 'UnorderedList',
            Used  => 0
        },
        ol => {
            Class => 'OrderedList',
            Used  => 1
        }
    );

    my $Css = $Self->_GetCSS(
        Block    => $Block,
        Template => 'List'
    );

    if (
        $LData
        && IsHashRefWithData($Datas)
        && $Datas->{$LData}
    ) {
        $Datas = $Datas->{$LData};
    }

    $Kernel::OM->Get('Output::HTML::Layout')->Block(
        Name => 'HTML',
        Data => {
            %{$LTypes{$Type}},
            ID => $Block->{ID}
        }
    );

    if ( IsArrayRefWithData($Datas) ) {
        my $Counter = scalar(@{$Datas});
        if ( $LCount ) {
            $Counter =  $LCount;
        }

        $Self->_SetObjectEntries(
            %Param,
            Datas   => $Datas,
            Object  => $LObject,
            Counter => $Counter
        );
    }
    else {
        my $Values = $Block->{Value};
        if ( !IsArrayRef($Block->{Value}) ) {
            $Values = [ $Block->{Value} ];
        }
        my $Counter = scalar(@{$Values});
        if ( $LCount ) {
            $Counter =  $LCount;
        }

        $Self->_SetStaticEntries(
            %Param,
            Values  => $Values,
            Object  => $LObject,
            Counter => $Counter
        );
    }

    my $HTML = $Kernel::OM->Get('Output::HTML::Layout')->Output(
        TemplateFile => 'HTMLToPDF/List',
    );

    return (
        HTML => $HTML,
        Css  => $Css
    );
}

sub _SetStaticEntries {
    my ( $Self, %Param ) = @_;

    my $Index      = 0;
    my $Counter    = $Param{Counter};
    my $Block      = $Param{Block};
    my $Values     = $Param{Values};
    my $Empty      = $Param{Block}->{ShowEmpty} || 0;
    my $Class      = q{};
    my $EmptyCount = 0;

    return if !$Counter;

    while( $Index < $Counter ) {
        my %Prepared = $Self->_ValuePrepare(
            %Param,
            Datas => $Param{Data},
            Value => $Values->[$Index] || q{}
        );

        if (
            !$Class
            && defined $Prepared{Class}
            && $Prepared{Class}
        ) {
            $Class = $Prepared{Class};
        }

        if (
            !$Prepared{Value}
            && $Empty
        ) {
            $EmptyCount++;
            $Index++;
            next;
        }

        $Kernel::OM->Get('Output::HTML::Layout')->Block(
            Name => 'Entry',
            Data => {
                Value => $Prepared{Value},
                Class => $Class
            }
        );

        $Index++;
    }

    if ( $EmptyCount ) {
        $Self->_RenderEmptyLines(
            Count => $EmptyCount,
            Class => $Class
        )
    }

    return 1;
}


sub _SetObjectEntries {
    my ( $Self, %Param ) = @_;

    my $Object     = $Param{Object};
    my $Index      = 0;
    my $Counter    = $Param{Counter};
    my $Datas      = $Param{Datas};
    my $Class      = q{};
    my $Empty      = $Param{Block}->{ShowEmpty} || 0;
    my $EmptyCount = 0;

    return if !$Counter;

    while( $Index < $Counter ) {

        my %Prepared;
        my %Keys;
        my $IsEmpty = 0;
        for my $Key ( qw{IDKey NumberKey} ) {
            if ( $Self->{"Backend$Object"}->{$Key} ) {
                my $ParamKey = $Self->{"Backend$Object"}->{$Key};
                $Param{$Key} = $ParamKey;
                $Keys{$ParamKey} = $Datas->[$Index] || q{};
                $IsEmpty = 1 if ( !$Keys{$ParamKey} );
            }
        }

        my $InnerData;
        if ( !$IsEmpty ) {
            $InnerData= $Self->{"Backend$Object"}->DataGet(
                %Keys,
                UserID  => $Param{UserID},
                Expands => $Param{Expands},
                Filters => $Param{Filters},
                Count   => $Param{Count}
            );

            %Prepared = $Self->_ValuePrepare(
                %Param,
                %Keys,
                Value  => $Param{Block}->{Value},
                Datas  => $InnerData,
                Object => $Object
            );
        }

        if (
            !$Class
            && defined $Prepared{Class}
            && $Prepared{Class}
        ) {
            $Class = $Prepared{Class};
        }

        if (
            !$Prepared{Value}
            && $Empty
        ) {
            $EmptyCount++;
            $Index++;
            next;
        }

        $Kernel::OM->Get('Output::HTML::Layout')->Block(
            Name => 'Entry',
            Data => {
                Value => $Prepared{Value},
                Class => $Class
            }
        );

        $Index++;
    }

    if ( $EmptyCount ) {
        $Self->_RenderEmptyLines(
            Count => $EmptyCount,
            Class => $Class
        )
    }

    return 1;
}

sub _ValuePrepare {
    my ( $Self, %Param ) = @_;

    my $Block = $Param{Block};
    my $Datas = $Param{Datas};
    my $IDKey = $Param{IDKey};
    my $Value;
    my $Class;

    if ( ref $Param{Value} eq 'ARRAY' ) {
        my @Values;
        for my $Entry ( @{$Param{Value}} ) {
            my %Result = $Self->ReplacePlaceholders(
                String       => $Entry,
                UserID       => $Param{UserID},
                Count        => $Param{Count},
                Translate    => $Block->{Translate},
                Object       => $Param{Object},
                ObjectID     => $Param{$IDKey},
                MainObject   => $Param{MainObject},
                MainObjectID => $Param{MainObjectID},
                Datas        => $Datas,
                ReplaceAs    => $Block->{ReplaceAs} // q{-}
            );

            if ( !$Class ) {
                $Class = $Result{Class};
            }

            if ( $Block->{Translate} ) {
                $Result{Text} = $Kernel::OM->Get('Output::HTML::Layout')->{LanguageObject}->Translate($Result{Text});
            }

            next if ( $Result{Text} eq q{} );

            push( @Values, $Result{Text});
        }
        $Value = join( ($Block->{Join} // q{ }), @Values);
    }
    else {
        my %Result = $Self->ReplacePlaceholders(
            String       => $Param{Value},
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

        if ( !$Class ) {
            $Class = $Result{Class};
        }

        $Value = $Result{Text};

        if ( $Block->{Translate} ) {
            $Value = $Kernel::OM->Get('Output::HTML::Layout')->{LanguageObject}->Translate($Value);
        }
    }

    return (
        Value => $Value,
        Class => $Class
    );
}

sub _RenderEmptyLines {
    my ( $Self, %Param ) = @_;

    for ( 1..$Param{Count} ) {
        $Kernel::OM->Get('Output::HTML::Layout')->Block(
            Name => 'Entry',
            Data => {
                Value => q{&nbsp;},
                Class => $Param{Class}
            }
        );
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