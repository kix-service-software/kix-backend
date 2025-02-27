# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language;

use strict;
use warnings;

use vars qw(@ISA);

use Exporter qw(import);
our @EXPORT_OK = qw(Translatable);    ## no critic

our @ObjectDependencies = (
    'Config',
    'Log',
    'Main',
    'Time',
);

my @DAYS = (
    Translatable('Sun'),
    Translatable('Mon'),
    Translatable('Tue'),
    Translatable('Wed'),
    Translatable('Thu'),
    Translatable('Fri'),
    Translatable('Sat')
);
my @MONS = (
    Translatable('Jan'),
    Translatable('Feb'),
    Translatable('Mar'),
    Translatable('Apr'),
    Translatable('May'),
    Translatable('Jun'),
    Translatable('Jul'),
    Translatable('Aug'),
    Translatable('Sep'),
    Translatable('Oct'),
    Translatable('Nov'),
    Translatable('Dec')
);

=head1 NAME

Kernel::Language - global language interface

=head1 SYNOPSIS

All language functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a language object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Language' => {
            UserLanguage => 'de',
        },
    );
    my $LanguageObject = $Kernel::OM->Get('Language');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # 0=off; 1=on; 2=get all not translated words; 3=get all requests
    $Self->{Debug} = 0;

    # define some defaults
    $Self->{Charset}   = ['utf-8' ];
    $Self->{Separator} = ',';


    # get needed object
    my $ConfigObject = $Kernel::OM->Get('Config');
    my $MainObject   = $Kernel::OM->Get('Main');

    # check if LanguageDebug is configured
    if ( $ConfigObject->Get('Language::Debug') ) {
        $Self->{LanguageDebug} = 1;
    }

    # user language
    $Self->{UserLanguage} = $Param{UserLanguage}
        || $ConfigObject->Get('DefaultLanguage')
        || 'en';

    # check if language is configured
    my %Languages = %{ $ConfigObject->Get('DefaultUsedLanguages') };
    if ( !$Languages{ $Self->{UserLanguage} } ) {
        $Self->{UserLanguage} = 'en';
    }

    # take time zone
    $Self->{TimeZone} = $Param{UserTimeZone} || $Param{TimeZone} || 0;

    # Debug
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'Debug',
            Message  => "UserLanguage = $Self->{UserLanguage}",
        );
    }

    # load translations for given language
    my @Translations = $Kernel::OM->Get('Translation')->TranslationList();
    foreach my $Translation ( @Translations ) {
        $Self->{Translation}->{$Translation->{Pattern}} = $Translation->{Languages}->{$Self->{UserLanguage}};
    }

    # if no return charset is given, use recommended return charset
    if ( !$Self->{ReturnCharset} ) {
        $Self->{ReturnCharset} = $Self->GetRecommendedCharset();
    }

    # get source file charset
    # what charset should I use (take it from translation file)!
    if ( $Self->{Charset} && ref $Self->{Charset} eq 'ARRAY' ) {
        $Self->{TranslationCharset} = $Self->{Charset}->[-1];
    }

    # set date format
    # date formats (%A=WeekDay;%B=LongMonth;%T=Time;%D=Day;%M=Month;%Y=Year;)
    if ($Self->{UserLanguage} =~ m/^de/) {
        $Self->{DateFormat}          = '%D.%M.%Y, %T';
        $Self->{DateFormatLong}      = '%T - %D.%M.%Y';
        $Self->{DateFormatShort}     = '%D.%M.%Y';
        $Self->{DateInputFormat}     = '%D.%M.%Y';
        $Self->{DateInputFormatLong} = '%D.%M.%Y - %T';
    } else {
        $Self->{DateFormat}          = '%M/%D/%Y, %T';
        $Self->{DateFormatLong}      = '%T - %M/%D/%Y';
        $Self->{DateFormatShort}     = '%M/%D/%Y';
        $Self->{DateInputFormat}     = '%M/%D/%Y';
        $Self->{DateInputFormatLong} = '%M/%D/%Y - %T';
    }

    return $Self;
}

=item Translatable()

this is a no-op to mark a text as translatable in the Perl code.

=cut

sub Translatable {
    return shift;
}

=item Translate()

translate a text with placeholders.

        my $Text = $LanguageObject->Translate('Hello %s!', 'world');

=cut

sub Translate {
    my ( $Self, $Text, @Parameters ) = @_;

    $Text //= '';

    $Text = $Self->{Translation}->{$Text} || $Text;

    return $Text if !@Parameters;

    for ( 0 .. $#Parameters ) {
        return $Text if !defined $Parameters[$_];
        $Text =~ s/\%(s|d)/$Parameters[$_]/;
    }

    return $Text;
}

=item Get()

WARNING: THIS METHOD IS DEPRECATED AND WILL BE REMOVED IN FUTURE VERSION OF OTRS! USE Translate() INSTEAD.

Translate a string.

    my $Text = $LanguageObject->Get('Hello');

    Example: (the quoting looks strange, but is in fact correct!)

    my $String = 'History::NewTicket", "2011031110000023", "Postmaster", "3 normal", "open", "9';

    my $TranslatedString = $LanguageObject->Translate( $String );

=cut

sub Get {
    my ( $Self, $What ) = @_;

    # check
    return if !defined $What;
    return '' if $What eq '';

    # check dyn spaces
    my @Dyn;
    if ( $What && $What =~ /^(.+?)",\s{0,1}"(.*?)$/ ) {
        $What = $1;
        @Dyn = split( /",\s{0,1}"/, $2 );
    }

    # check wanted param and returns the
    # lookup or the english data
    if ( $Self->{Translation}->{$What} ) {

        # Debug
        if ( $Self->{Debug} > 3 ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'Debug',
                Message  => "->Get('$What') = ('$Self->{Translation}->{$What}').",
            );
        }

        my $Text = $Self->{Translation}->{$What};
        if (@Dyn) {
            COUNT:
            for ( 0 .. $#Dyn ) {

                # be careful $Dyn[$_] can be 0! bug#3826
                last COUNT if !defined $Dyn[$_];

                if ( $Dyn[$_] =~ /Time\((.*)\)/ ) {
                    $Dyn[$_] = $Self->Time(
                        Action => 'GET',
                        Format => $1,
                    );
                    $Text =~ s/\%(s|d)/$Dyn[$_]/;
                }
                else {
                    $Text =~ s/\%(s|d)/$Dyn[$_]/;
                }
            }
        }

        return $Text;
    }

    # warn if the value is not def
    if ( $Self->{Debug} > 1 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => "->Get('$What') Is not translated!!!",
        );
    }

    if ( $Self->{LanguageDebug} ) {
        print STDERR "No translation available for '$What'\n";
    }

    if (@Dyn) {
        COUNT:
        for ( 0 .. $#Dyn ) {

            # be careful $Dyn[$_] can be 0! bug#3826
            last COUNT if !defined $Dyn[$_];

            if ( $Dyn[$_] =~ /Time\((.*)\)/ ) {
                $Dyn[$_] = $Self->Time(
                    Action => 'GET',
                    Format => $1,
                );
                $What =~ s/\%(s|d)/$Dyn[$_]/;
            }
            else {
                $What =~ s/\%(s|d)/$Dyn[$_]/;
            }
        }
    }

    return $What;
}

=item FormatTimeString()

formats a timestamp according to the specified date format for the current
language (locale).

    my $Date = $LanguageObject->FormatTimeString(
        '2009-12-12 12:12:12',  # timestamp
        'DateFormat',           # which date format to use, e. g. DateFormatLong
        0,                      # optional, hides the seconds from the time output
    );

Please note that the TimeZone will not be applied in the case of DateFormatShort (date only)
to avoid switching to another date.

If you only pass an ISO date ('2009-12-12'), it will be returned unchanged.
Invalid strings will also be returned with an error logged.

=cut

sub FormatTimeString {
    my ( $Self, $String, $Config, $Short ) = @_;

    return '' if !$String;

    $Config ||= 'DateFormat';
    $Short  ||= 0;

    # Valid timestamp
    if ( $String =~ /(\d{4})-(\d{2})-(\d{2})\s(\d{2}):(\d{2}):(\d{2})/ ) {
        my ( $Y, $M, $D, $h, $m, $s ) = ( $1, $2, $3, $4, $5, $6 );
        my $WD;    # day of week

        my $ReturnString = $Self->{$Config} || "$Config needs to be translated!";

        # get time object
        my $TimeObject = $Kernel::OM->Get('Time');

        my $TimeStamp = $TimeObject->TimeStamp2SystemTime(
            String => "$Y-$M-$D $h:$m:$s",
        );

        # Add user time zone diff, but only if we actually display the time!
        # Otherwise the date might be off by one day because of the TimeZone diff.
        if ( $Self->{TimeZone} && $Config ne 'DateFormatShort' ) {
            $TimeStamp = $TimeStamp + ( $Self->{TimeZone} * 60 * 60 );
        }

        ( $s, $m, $h, $D, $M, $Y, $WD ) = $TimeObject->SystemTime2Date(
            SystemTime => $TimeStamp,
        );

        # add AM/PM if necessary
        # FIXME: use strftime from POSFIX with "$h:$m $p" or for "%r" long format
        #   --> locally it does not "print" the AM/PM - so we use the following code for now
        my $Part = '';
        if ($Self->{UserLanguage} !~ m/^de/) {
            if ($h >= 12) {
                if ($h >= 12) {
                    $h -= 12;
                }
                $Part = ' PM';
            } else {
                if ($h == 0) {
                    $h = 12;
                }
                $Part = ' AM';
            }
        }

        if ($Short) {
            $ReturnString =~ s/\%T/$h:$m$Part/g;
        }
        else {
            $ReturnString =~ s/\%T/$h:$m:$s$Part/g;
        }
        $ReturnString =~ s/\%D/$D/g;
        $ReturnString =~ s/\%M/$M/g;
        $ReturnString =~ s/\%Y/$Y/g;

        $ReturnString =~ s{(\%A)}{defined $WD ? $Self->Translate($DAYS[$WD]) : '';}egx;
        $ReturnString
            =~ s{(\%B)}{(defined $M && $M =~ m/^\d+$/) ? $Self->Translate($MONS[$M-1]) : '';}egx;

        if ( $Self->{TimeZone} && $Config ne 'DateFormatShort' ) {
            return $ReturnString . " ($Self->{TimeZone})";
        }
        return $ReturnString;
    }

    # Invalid string passed? (don't log for ISO dates)
    if ( $String !~ /^(\d{2}:\d{2}:\d{2})$/ ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "No FormatTimeString() translation found for '$String' string!",
        );
    }

    return $String;

}

=item GetRecommendedCharset()

DEPRECATED. Don't use this function any more, 'utf-8' is always the internal charset.

Returns the recommended charset for frontend (based on translation
file or utf-8).

    my $Charset = $LanguageObject->GetRecommendedCharset().

=cut

sub GetRecommendedCharset {
    my $Self = shift;

    return 'utf-8';
}

=item GetPossibleCharsets()

Returns an array of possible charsets (based on translation file).

    my @Charsets = $LanguageObject->GetPossibleCharsets().

=cut

sub GetPossibleCharsets {
    my $Self = shift;

    return @{ $Self->{Charset} } if $Self->{Charset};
    return;
}

=item Time()

Returns a time string in language format (based on translation file).

    $Time = $LanguageObject->Time(
        Action => 'GET',
        Format => 'DateFormat',
    );

    $TimeLong = $LanguageObject->Time(
        Action => 'GET',
        Format => 'DateFormatLong',
    );

    $TimeLong = $LanguageObject->Time(
        Action => 'RETURN',
        Format => 'DateFormatLong',
        Year   => 1977,
        Month  => 10,
        Day    => 27,
        Hour   => 20,
        Minute => 10,
        Second => 05,
    );

These tags are supported: %A=WeekDay;%B=LongMonth;%T=Time;%D=Day;%M=Month;%Y=Year;

Note that %A only works correctly with Action GET, it might be dropped otherwise.

Also note that it is also possible to pass HTML strings for date input:

    $TimeLong = $LanguageObject->Time(
        Action => 'RETURN',
        Format => 'DateInputFormatLong',
        Mode   => 'NotNumeric',
        Year   => '<input value="2014"/>',
        Month  => '<input value="1"/>',
        Day    => '<input value="10"/>',
        Hour   => '<input value="11"/>',
        Minute => '<input value="12"/>',
        Second => '<input value="13"/>',
    );

Note that %B may not work in NonNumeric mode.

=cut

sub Time {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Action Format)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }
    my $ReturnString = $Self->{ $Param{Format} } || 'Need to be translated!';
    my ( $s, $m, $h, $D, $M, $Y, $WD, $YD, $DST );

    # set or get time
    if ( lc $Param{Action} eq 'get' ) {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Time');

        ( $s, $m, $h, $D, $M, $Y, $WD, $YD, $DST ) = $TimeObject->SystemTime2Date(
            SystemTime => $TimeObject->SystemTime(),
        );
    }
    elsif ( lc $Param{Action} eq 'return' ) {
        $s = $Param{Second} || 0;
        $m = $Param{Minute} || 0;
        $h = $Param{Hour}   || 0;
        $D = $Param{Day}    || 0;
        $M = $Param{Month}  || 0;
        $Y = $Param{Year}   || 0;
    }

    # do replace
    if ( ( lc $Param{Action} eq 'get' ) || ( lc $Param{Action} eq 'return' ) ) {
        my $Time = '';
        if ( $Param{Mode} && $Param{Mode} =~ /^NotNumeric$/i ) {
            if ( !$s ) {
                $Time = "$h:$m";
            }
            else {
                $Time = "$h:$m:$s";
            }
        }
        else {
            $Time = sprintf( "%02d:%02d:%02d", $h, $m, $s );
            $D    = sprintf( "%02d",           $D );
            $M    = sprintf( "%02d",           $M );
        }
        $ReturnString =~ s/\%T/$Time/g;
        $ReturnString =~ s/\%D/$D/g;
        $ReturnString =~ s/\%M/$M/g;
        $ReturnString =~ s/\%Y/$Y/g;
        $ReturnString =~ s/\%Y/$Y/g;
        $ReturnString =~ s{(\%A)}{defined $WD ? $Self->Translate($DAYS[$WD]) : '';}egx;
        $ReturnString
            =~ s{(\%B)}{(defined $M && $M =~ m/^\d+$/) ? $Self->Translate($MONS[$M-1]) : '';}egx;
        return $ReturnString;
    }

    return $ReturnString;
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
