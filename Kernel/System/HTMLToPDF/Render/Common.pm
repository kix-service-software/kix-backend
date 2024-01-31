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

    return $Self;
}

sub _ReplacePlaceholders {
    my ( $Self, %Param ) = @_;

    my $LogObject     = $Kernel::OM->Get('Log');
    my $TimeObject    = $Kernel::OM->Get('Time');
    my $ContactObject = $Kernel::OM->Get('Contact');
    my $LayoutObject  = $Kernel::OM->Get('Output::HTML::Layout');

    # check needed stuff
    for my $Needed (qw(String)) {
        if ( !defined( $Param{$Needed} ) ) {
            $LogObject->Log(
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
    while ($Result{Text} =~ m{<Font_([^>]+)>}sm ) {
        my $Font = $1;
        $Result{Text} =~ s/<Font_$Font>//gsm;
        if ( $Font eq 'Bold' ) {
            $Result{Class} = 'ProportionalBold';
        }
        if ( $Font eq 'Italic' ) {
            $Result{Class} = 'ProportionalItalic';
        }
        if ( $Font eq 'BoldItalic' ) {
            $Result{Class} = 'ProportionalBoldItalic';
        }
        if ( $Font eq 'Mono' ) {
            $Result{Class} = 'Monospaced';
        }
        if ( $Font eq 'MonoBold' ) {
            $Result{Class} = 'MonospacedBold';
        }
        if ( $Font eq 'MonoItalic' ) {
            $Result{Class} = 'MonospacedItalic';
        }
        if ( $Font eq 'MonoBoldItalic' ) {
            $Result{Class} = 'MonospacedBoldItalic';
        }
    }

    # replace custom classes
    while ($Result{Text} =~ m{<Class_([^>]+)>}sm ) {
        my $Class = $1;
        $Result{Text} =~ s/<Class_$Class>//gsm;
        $Result{Class} .= " $Class";
    }

    # replace current user and time
    if ( $Result{Text} =~ m{<Current_Time>}smx ) {
        my $Time = $TimeObject->CurrentTimestamp();
        if ( $Param{Translate} ) {
            $Time = $LayoutObject->{LanguageObject}->FormatTimeString( $Time, "DateFormat" );
        }
        $Result{Text} =~ s/<Current_Time>/$Time/gxsm;
    }
    if ( $Result{Text} =~ m{<Current_User>}smx ) {
        my %Contact = $ContactObject->ContactGet(
            UserID => $Param{UserID}
        );
        if ( %Contact ) {
            $Result{Text} =~ s/<Current_User>/$Contact{Fullname}/gsxm;
        }
        else {
            $Result{Text} =~ s/<Current_User>//gsxm;
        }
    }

    # replace count
    if ( $Result{Text} =~ m{<Count>}smx ) {

        if ( defined $Param{Count} ) {
            $Result{Text} =~ s/<Count>/$Param{Count}/gsxm;
        }
        else {
            $Result{Text} =~ s/<Count>//gsxm;
        }
    }
    # replace filename time
    if ( $Result{Text} =~ m{<TIME_}smx ) {
        my @Time = $TimeObject->SystemTime2Date(
            SystemTime => $TimeObject->SystemTime()
        );

        if ( $Result{Text} =~ m{<TIME_YYMMDD_hhmm}smx ) {
            my $TimeStamp = $Time[5]
                . $Time[4]
                . $Time[3]
                . q{_}
                . $Time[2]
                .$Time[1];
            $Result{Text} =~ s/<TIME_YYMMDD_hhmm>/$TimeStamp/gsxm;
        }

        if ( $Result{Text} =~ m{<TIME_YYMMDD}smx ) {
            my $TimeStamp = $Time[5]
                . $Time[4]
                . $Time[3];
            $Result{Text} =~ s/<TIME_YYMMDD>/$TimeStamp/gsxm;
        }

        if ( $Result{Text} =~ m{<TIME_YYMMDDhhmm}smx ) {
            my $TimeStamp = $Time[5]
                . $Time[4]
                . $Time[3]
                . $Time[2]
                .$Time[1];
            $Result{Text} =~ s/<TIME_YYMMDDhhmm>/$TimeStamp/gsxm;
        }

        $Result{Text} =~ s/<TIME_.*>//gsxm;
    }

    # replace object attributes
    if (
        $Param{Datas}
        && $Param{Object}
    ) {
        for my $Tag ( sort keys %{$Param{Datas}} ) {
            my $Pattern = $Param{Object} . '[.]' . $Tag . '[.]Key';
            if ( $Result{Text} =~ m/$Pattern/smg ) {
                $Result{Text} =~ s/$Pattern/$Tag/smg;
                $Result{Text} =~ s/$Pattern/-/smg;
            }

            $Pattern = $Param{Object} . '[.]' . $Tag . '[.]Value(:?[.](\d+)|)';
            if ( $Result{Text} =~ m/$Pattern/smg ) {
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
                    $Value = $LayoutObject->{LanguageObject}->FormatTimeString( $Value, "DateFormat" );
                }
                $Result{Text} =~ s/$Pattern/$Value/smg;
                $Result{Text} =~ s/$Pattern/-/smg;
            }
        }
        # replace not exists placeholders of that object
        my $Pattern = $Param{Object} . '[.].*[.]Key';
        my $Pattern2 = $Param{Object} . '[.].*[.]Value(:?[.]\d+|)';
        $Result{Text} =~ s/$Pattern/-/smg;
        $Result{Text} =~ s/$Pattern2/-/smg;
    }

    return %Result;
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