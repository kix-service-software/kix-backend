# --
# Modified version of the work: Copyright (C) 2006-2023 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Convert;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

use Kernel::System::VariableCheck qw(:all);

sub Convert {
    my ($Self, %Param) = @_;

    my $LogObject               = $Kernel::OM->Get('Log');
    my $MainObject              = $Kernel::OM->Get('Main');
    my $ConfigObject            = $Kernel::OM->Get('Config');
    my $JSONObject              = $Kernel::OM->Get('JSON');
    my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

    my %Data = $Self->TemplateGet(
        %Param
    );

    if ( !%Data ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'No definition exists!'
        );
        return;
    }

    if ( $Param{IdentifierType} ) {
        my $ObjectParams = $Self->{"Backend$Data{Object}"}->GetParams();

        $Param{$ObjectParams->{$Param{IdentifierType}}} = $Param{IdentifierIDorNumber};
    }

    my $Result = $Self->_CheckParams(
        Object => $Data{Object},
        Data   => \%Param
    );

    if ( IsHashRefWithData($Result) ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => $Result->{error}
        );
        return;
    }

    my $Binary        = '/usr/local/bin/wkhtmltopdf';
    my $Config        = $ConfigObject->Get('HTMLToPDF::wkhtmltopdf');
    my $TempDir       = $ConfigObject->Get('TempDir');
    my $Directory     = $TempDir . '/PDFPrint';
    my $ContentType   = 'application/pdf';
    my $FileExtension = '.pdf';
    my $Filename      = $Param{Filename} || q{};
    my $Output        = q{};

    if ( !-e $Binary ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "HTMLToPDF: wkhtmltopdf binary doesn't exist!",
        );
        return;
    }

    for my $CheckDirectory ( $TempDir, $Directory ) {
        if ( !-e $CheckDirectory ) {
            if ( !mkdir( $CheckDirectory, oct(770) ) ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Can't create directory '$CheckDirectory': $!",
                );
                return;
            }
        }
    }

    if ( !$Filename ) {
        $Filename = $Self->_FilenameCreate(
            %Param,
            Object => $Data{Name},
            Name   => $Data{Object}
        );
    }
    else {
        my %Replaced = $Self->_ReplacePlaceholders(
            String => $Filename,
            UserID => $Param{UserID},
        );
        $Filename = $TemplateGeneratorObject->ReplacePlaceHolder(
            %Param,
            Text     => $Replaced{Text},
            RichText => 1,
            UserID   => $Param{UserID},
            Data     => {}
        )
    }

    for my $Key ( qw(Filters Allows Ignores) ) {
        next if !$Param{$Key};
        my $Tmp = $JSONObject->Decode(
            Data => $Param{$Key}
        );

        $Data{Definition}->{$Key} = $Tmp;
    }

    if ( $Param{Expands} ) {
        $Data{Definition}->{Expands} = $Param{Expands};
    }

    # set user language if configured
    my $UserLanguage = $Kernel::OM->Get('User')->GetUserLanguage(UserID => $Param{UserID});
    if ($UserLanguage) {
        my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');
        local $Kernel::OM = Kernel::System::ObjectManager->new(
            'Language' => {
                UserLanguage => $UserLanguage,
            },
        );
        $LayoutObject->{LanguageObject} = $Kernel::OM->Get('Language');
    }

    my %FileDatas;
    for my $Key ( qw(Header Content Footer ) ) {
        $FileDatas{$Key} = $Self->Render(
            %Param,
            Block     => $Data{Definition}->{$Key},
            Filename  => $Filename . '_' . $Key,
            Directory => $Directory,
            Object    => $Data{Object},
            Expands   => $Data{Definition}->{Expands},
            Filters   => $Data{Definition}->{Filters},
            Allows    => $Data{Definition}->{Allows},
            Ignores   => $Data{Definition}->{Ignores},
            IsContent => $Key eq 'Content' ? 1 : 0
        );
    }

    # prepare temp file names
    my $TempPDFFile  = $Filename . '-Temp.pdf';
    $Self->_Call(
        Binary    => $Binary,
        Config    => $Config,
        Page      => $Data{Definition}->{Page},
        Directory => $Directory,
        Header    => $FileDatas{Header},
        Footer    => $FileDatas{Footer},
        Content   => $FileDatas{Content},
        TmpPDF    => $TempPDFFile
    );

    # read PDF result file
    if ( open( my $FH, '<', ($Directory . q{/} . $TempPDFFile) ) ) {
        local $/ = undef;
        $Output = <$FH>;
        close($FH);
    }

    my @DeleteData = (
        {
            Directory => $Directory,
            Filename  => $FileDatas{Content},
        },
        {
            Directory => $Directory,
            Filename  => $TempPDFFile,
        }
    );
    for my $Key ( qw(Header Footer ) ) {
        next if !$FileDatas{$Key};
        push(
            @DeleteData, {
                Directory => $Directory,
                Filename  => $FileDatas{$Key}
            }
        );
    }

    $Self->_FileDelete(
        Data => \@DeleteData
    );

    return (
        Content     => $Output,
        ContentType => $ContentType,
        Filename    => $Filename . $FileExtension
    );
}

sub _Call {
    my ($Self, %Param) = @_;

    my $Binary    = $Param{Binary};
    my %Config    = %{$Param{Config}};
    my %Page      = %{$Param{Page}};
    my $Directory = $Param{Directory};
    my $Header    = $Param{Header};
    my $Footer    = $Param{Footer};
    my $Content   = $Param{Content};
    my $TmpPDF    = $Param{TmpPDF};

    # prepare system call
    my @SystemCallArg = ( $Binary );

    # add parameter to system call
    if ( ref( $Config{Parameter} ) eq 'ARRAY' ) {
        push( @SystemCallArg, @{ $Config{Parameter} } );
    }

    # add content parameter to system call
    for my $Key ( qw(
            Top Bottom Left Right
        )
    ) {
        next if !$Page{$Key};

        my $Char = substr( $Key, 0 ,1 );
        if ( $Page{$Key} ) {
            push( @SystemCallArg, q{-} . $Char, $Page{ $Key } );
        }
    }
    if ( $Page{SpacingHeader} ) {
        push( @SystemCallArg, '--header-spacing',  $Page{SpacingHeader} );
    }
    if ( $Page{SpacingFooter} ) {
        push( @SystemCallArg, '--footer-spacing',  $Page{SpacingFooter} );
    }

    if ( $Header ) {
        push( @SystemCallArg, '--header-html',  $Directory . q{/} . $Header );
    }
    if ( $Footer ) {
        push( @SystemCallArg, '--footer-html',  $Directory . q{/} . $Footer );
    }

    # add input to system call
    push( @SystemCallArg,  $Directory . q{/} . $Content );

    # add output to system call
    push( @SystemCallArg, $Directory . q{/} . $TmpPDF );

    # process system call
    system( @SystemCallArg );

    return 1;
}

sub _FileDelete {
    my ($Self, %Param) = @_;

    my $MainObject = $Kernel::OM->Get('Main');

    for my $Data ( @{$Param{Data}} ) {

        # delete output file from fs
        $MainObject->FileDelete(
            Directory       => $Data->{Directory},
            Filename        => $Data->{Filename},
            Type            => 'Local',
            DisableWarnings => 1,
        );
    }

    return 1;
}

sub _FilenameCreate {
    my ( $Self, %Param ) = @_;

    my $TimeObject = $Kernel::OM->Get('Time');

    my $Filename;
    my $Name        = $Param{Name};
    my $Object      = $Param{Object};
    my $IDKey       = $Self->{"Backend$Object"}->{IDKey}     || q{};
    my $NumberKey   = $Self->{"Backend$Object"}->{NumberKey} || q{};
    my $CurrentTime = $TimeObject->CurrentTimestamp();

    $CurrentTime =~ s/[-:]+//gmsx;
    $CurrentTime =~ s/\s+//gmsx;

    $Filename = $Name . q{_};

    if (
        $IDKey
        && $Param{$IDKey}
    ) {
        $Filename .= $Param{$IDKey} . q{_};
    }
    elsif (
        $NumberKey
        && $Param{$NumberKey}
    ) {
        $Filename .= $Param{$NumberKey} . q{_};
    }

    $Filename .= $CurrentTime;

    return $Filename;
}

sub _CheckParams {
    my ( $Self, %Param ) = @_;

    return $Self->{"Backend$Param{Object}"}->CheckParams(
        %{$Param{Data}}
    );
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
        Text => $Param{String},
        Font => 'Proportional',
    );

    # replace Font
    while ($Result{Text} =~ m{<Font_([^>]+)>}smx ) {
        my $Font = $1;
        $Result{Text} =~ s/<Font_$Font>//gsm;
        if ( $Font eq 'Bold' ) {
            $Result{Font} = 'ProportionalBold';
        }
        if ( $Font eq 'Italic' ) {
            $Result{Font} = 'ProportionalItalic';
        }
        if ( $Font eq 'BoldItalic' ) {
            $Result{Font} = 'ProportionalBoldItalic';
        }
        if ( $Font eq 'Mono' ) {
            $Result{Font} = 'Monospaced';
        }
        if ( $Font eq 'MonoBold' ) {
            $Result{Font} = 'MonospacedBold';
        }
        if ( $Font eq 'MonoItalic' ) {
            $Result{Font} = 'MonospacedItalic';
        }
        if ( $Font eq 'MonoBoldItalic' ) {
            $Result{Font} = 'MonospacedBoldItalic';
        }
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