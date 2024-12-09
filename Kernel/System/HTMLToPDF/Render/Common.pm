# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Render::Common;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::HTMLToPDF::Common - print management

=head1 SYNOPSIS

All print functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Key ( keys %Param ) {
        next if $Key !~ /^Backend/smx;
        $Self->{$Key} = $Param{$Key};
    }

    return $Self;
}

sub _GetCSS {
    my ( $Self, %Param ) = @_;

    my $Block = $Param{Block};

    return q{} if !$Block->{ID};
    return q{} if $Self->{CSSIDs}->{$Block->{ID}};

    $Kernel::OM->Get('Output::HTML::Layout')->Block(
        Name => 'CSS',
        Data => $Block
    );

    if ( IsArrayRefWithData($Block->{Style}->{Class}) ) {
        for my $Style ( @{$Block->{Style}->{Class}} ) {
            next if ( !$Style->{Selector} || !$Style->{CSS} );

            $Kernel::OM->Get('Output::HTML::Layout')->Block(
                Name => 'StyleClass',
                Data => {
                    %{$Block},
                    %{$Style}
                }
            );
        }
    }

    my $Css = $Kernel::OM->Get('Output::HTML::Layout')->Output(
        TemplateFile => "HTMLToPDF/$Param{Template}",
    );
    $Self->{CSSIDs}->{$Block->{ID}} = 1;

    return $Css;
}

sub ReplacePlaceholders {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(String)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message => "Need $Needed!"
            );
            return;
        }
    }

    my %Result = (
        Text  => $Param{String},
        Class => 'Proportional',
    );

    # replace Font
    $Self->_ReplaceFont(
        Result => \%Result
    );

    # replace custom classes
    $Self->_ReplaceClass(
        Result => \%Result
    );

    # replace current user and time
    $Result{Text} = $Self->_ReplaceSpecialCurrent(
        Text      => $Result{Text},
        Translate => $Param{Translate},
        UserID    => $Param{UserID}
    );

    # replace count
    $Result{Text} = $Self->_ReplaceCount(
        Text   => $Result{Text},
        Count  => $Param{Count}
    );

    # replace filename time
    $Result{Text} = $Self->_ReplaceSpecialTime(
        Text => $Result{Text}
    );

    # replace specific keys
    $Result{Text} = $Self->_ReplaceSpecialKey(
        Text       => $Result{Text},
        Object     => $Param{Object},
        ReplaceKey => $Param{ReplaceKey}
    );

    # replace object placeholders
    $Result{Text} = $Self->_ReplaceObjectAttributes(
        Text      => $Result{Text},
        Datas     => $Param{Datas},
        Object    => $Param{Object},
        ReplaceAs => $Param{ReplaceAs}
    );

    # replace KIX placeholders
    $Result{Text} = $Self->_ReplaceKIX(
        %Param,
        Text => $Result{Text}
    );

    return %Result;
}

sub _ReplaceFont {
    my ( $Self, %Param ) = @_;

    while ($Param{Result}->{Text} =~ m{<Font_([^>]+)>}sm ) {
        my $Font = $1;
        $Param{Result}->{Text} =~ s/<Font_$Font>//gsm;
        if ( $Font eq 'Bold' ) {
            $Param{Result}->{Class} = 'ProportionalBold';
        }
        if ( $Font eq 'Italic' ) {
            $Param{Result}->{Class} = 'ProportionalItalic';
        }
        if ( $Font eq 'BoldItalic' ) {
            $Param{Result}->{Class} = 'ProportionalBoldItalic';
        }
        if ( $Font eq 'Mono' ) {
            $Param{Result}->{Class} = 'Monospaced';
        }
        if ( $Font eq 'MonoBold' ) {
            $Param{Result}->{Class} = 'MonospacedBold';
        }
        if ( $Font eq 'MonoItalic' ) {
            $Param{Result}->{Class} = 'MonospacedItalic';
        }
        if ( $Font eq 'MonoBoldItalic' ) {
            $Param{Result}->{Class} = 'MonospacedBoldItalic';
        }
    }

    return 1;
}

sub _ReplaceSpecialCurrent {
    my ( $Self, %Param ) = @_;

    my $Text = $Param{Text};

    if ( $Text =~ m{<Current_(?:Time|Date)>}smx ) {
        my @Data = $Kernel::OM->Get('Time')->SystemTime2Date(
            SystemTime => $Kernel::OM->Get('Time')->SystemTime(),
        );
        my $Time = "$Data[2]:$Data[1]:$Data[0]";
        my $Date = "$Data[5]-$Data[4]-$Data[3]";

        my $Value;
        my $Tag = '<Current_Time>';
        if ( $Text =~ m{$Tag}smx ) {
            $Value = $Date . q{ } . $Time;
            if ( $Param{Translate} ) {
                $Value = $Kernel::OM->Get('Output::HTML::Layout')->{LanguageObject}->FormatTimeString(
                    $Value,
                    "DateFormat"
                );
            }
            $Text =~ s/$Tag/$Value/gxsm;
        }

        $Tag = '<Current_Date>';
        if ( $Text =~ m{$Tag}smx ) {
            $Value = $Date;
            if ( $Param{Translate} ) {
                $Value = $Date . q{ } . $Time;
                $Value = $Kernel::OM->Get('Output::HTML::Layout')->{LanguageObject}->FormatTimeString(
                    $Value,
                    "DateFormatShort"
                );
            }
            $Text =~ s/$Tag/$Value/gxsm;
        }
    }

    if ( $Text =~ m{<Current_User>}smx ) {
        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            UserID => $Param{UserID}
        );
        if ( %Contact ) {
            $Text =~ s/<Current_User>/$Contact{Fullname}/gsxm;
        }
        else {
            $Text =~ s/<Current_User>//gsxm;
        }
    }

    return $Text;
}

sub _ReplaceCount {
    my ( $Self, %Param ) = @_;

    my $Text = $Param{Text};

    return $Text if ( $Text !~ m{<Count>}smx );


    if ( defined $Param{Count} ) {
        $Text =~ s/<Count>/$Param{Count}/gsxm;
    }
    else {
        $Text =~ s/<Count>//gsxm;
    }

    return $Text;
}

sub _ReplaceClass {
    my ( $Self, %Param ) = @_;

    while ($Param{Result}->{Text} =~ m{<Class_([^>]+)>}sm ) {
        my $Class = $1;
        $Param{Result}->{Text} =~ s/<Class_$Class>//gsm;
        $Param{Result}->{Class} .= " $Class";
    }

    return 1;
}

sub _ReplaceSpecialTime {
    my ( $Self, %Param ) = @_;

    my $Text = $Param{Text};

    return $Text if $Text !~ m{<TIME_}smx;

    my @Time = $Kernel::OM->Get('Time')->SystemTime2Date(
        SystemTime => $Kernel::OM->Get('Time')->SystemTime()
    );

    if ( $Text =~ m{<TIME_YY(?:YY)?MMDD_hhmm>}smx ) {
        my $TimeStamp = sprintf(
            '%d%02d%02d_%02d%02d',
            $Time[5],
            $Time[4],
            $Time[3],
            $Time[2],
            $Time[1]
        );
        $Text =~ s/<TIME_YY(?:YY)?MMDD_hhmm>/$TimeStamp/gsxm;
    }

    if ( $Text =~ m{<TIME_YY(?:YY)?MMDD>}smx ) {
        my $TimeStamp = sprintf(
            '%d%02d%02d',
            $Time[5],
            $Time[4],
            $Time[3]
        );
        $Text =~ s/<TIME_YY(?:YY)?MMDD>/$TimeStamp/gsxm;
    }

    if ( $Text =~ m{<TIME_YY(?:YY)?MMDDhhmm>}smx ) {
        my $TimeStamp = sprintf(
            '%d%02d%02d%02d%02d',
            $Time[5],
            $Time[4],
            $Time[3],
            $Time[2],
            $Time[1]
        );
        $Text =~ s/<TIME_YY(?:YY)?MMDDhhmm>/$TimeStamp/gsxm;
    }

    $Text =~ s/<TIME_.*>//gsxm;

    return $Text;
}

sub _ReplaceObjectAttributes {
    my ( $Self, %Param ) = @_;

    my $Text      = $Param{Text};
    my $ReplaceAs = $Param{ReplaceAs} // q{-};

    return $Text if ( !$Param{Datas} || !$Param{Object} );

    for my $Tag ( sort keys %{$Param{Datas}} ) {
        my $Pattern = $Param{Object} . '[.]' . $Tag . '[.]Key';
        if ( $Text =~ m/$Pattern/smg ) {
            $Text =~ s/$Pattern/$Tag/smg;
            $Text =~ s/$Pattern/$ReplaceAs/smg;
        }

        $Pattern = $Param{Object} . '[.]' . $Tag . '[.]Value(:?[.](\d+)|)';
        if ( $Text =~ m/$Pattern/smg ) {
            my $Index = $1;
            my $Value;

            if ( $Tag =~ /^DynamicField_/sm ) {
                $Value = $Param{Datas}->{$Tag}->{Value};
            }
            elsif ( $Index ) {
                if ( ref $Param{Datas}->{$Tag} eq 'ARRAY' ) {
                    $Value = $Param{Datas}->{$Tag}->[$Index];
                }
                else {
                    $Value = $Param{Datas}->{$Tag};
                }
            }
            else {
                if ( ref $Param{Datas}->{$Tag} eq 'ARRAY' ) {
                    $Value = join( q{,}, $Param{Datas}->{$Tag});
                }
                else {
                    $Value = $Param{Datas}->{$Tag};
                }
            }
            if ( $Tag =~ /^(?:Create|Change)(?:d|Time)$/sm ) {
                $Value = $Kernel::OM->Get('Output::HTML::Layout')->{LanguageObject}->FormatTimeString(
                    $Value,
                    $Index ? "DateFormatShort" : "DateFormat"
                );
            }
            $Text =~ s/$Pattern/$Value/smg;
            $Text =~ s/$Pattern/$ReplaceAs/smg;
        }
    }

    # replace not exists placeholders of that object
    my $Pattern = $Param{Object} . '[.].*[.]Key';
    my $Pattern2 = $Param{Object} . '[.].*[.]Value(:?[.]\d+|)';
    $Text =~ s/$Pattern/$ReplaceAs/smg;
    $Text =~ s/$Pattern2/$ReplaceAs/smg;

    return $Text;
}

sub _ReplaceSpecialKey {
    my ( $Self, %Param ) = @_;

    my $Text = $Param{Text};

    return $Text if ( !$Param{ReplaceKey} );

    my $List = {
        CreateBy    => 'Created by',
        CreatedBy   => 'Created by',
        ChangeBy    => 'Changed by',
        ChangedBy   => 'Changed by',
        CreatedTime => 'Created at',
        ChangeTime  => 'Change at',
        ChangedTime => 'Change at',
    };

    my $ObjectKeys = $Self->{ReplaceableLabel};

    if (
        defined $ObjectKeys
        && IsHashRefWithData($ObjectKeys)
    ) {
        $List = { %{$List}, %{$ObjectKeys} };
    }

    for my $Pattern ( sort keys %{$List} ) {
        if ( $Text =~ m/$Pattern/smg ) {
            my $Replace = $List->{$Pattern};
            $Text =~ s/$Pattern/$Replace/smg;
            last;
        }
    }

    return $Text;
}

sub _ReplaceKIX {
    my ( $Self, %Param ) = @_;

    my $Text = $Param{Text};

    return $Text if ( !$Text );

    my $ObjectID;
    my $ObjectType;
    my %Data = ();
    if (
        $Param{Object}
        && $Param{ObjectID}
    ) {
        $ObjectID   = $Param{ObjectID};
        $ObjectType = $Param{Object};
        if (
            $Param{MainObjectID}
            && $Param{MainObject}
        ) {
            my $MainObjectKey = $Param{MainObject} . 'ID';
            if ( $Param{MainObject} eq 'Asset' ) {
                $MainObjectKey = 'ConfigItemID';
            }
            $Data{$MainObjectKey} = $Param{MainObjectID};

        }
    }
    elsif (
        $Param{MainObjectID}
        && $Param{MainObject}
    ) {
        $ObjectType = $Param{MainObject};
        if ( $Param{MainObject} eq 'Asset' ) {
            $ObjectType = 'ITSMConfigItem';
        }
        $ObjectID   = $Param{MainObjectID};
    }
    else {
        return $Text;
    }

    $Text = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        Text            => $Text,
        ObjectType      => $ObjectType,
        ObjectID        => $ObjectID,
        Data            => \%Data,
        UserID          => $Param{UserID},
        RichText        => 1,
        ReplaceNotFound => $Param{ReplaceAs} // q{-}
    );

    return $Text;
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