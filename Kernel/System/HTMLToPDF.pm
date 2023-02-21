# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF;

use strict;
use warnings;

our @ObjectDependencies = (
    "Config",
    "Main",
    "Log",
);

use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::HTMLToPDF - print management

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

    # get and execute placeholder modules
    my $Modules = $Kernel::OM->Get('Config')->Get('HTMLToPDF::Module');
    if (IsHashRefWithData($Modules)) {
        for my $Module (sort keys %{$Modules}) {
            next if !IsHashRefWithData($Modules->{$Module}) || !$Modules->{$Module}->{Module};

            if ( !$Kernel::OM->Get('Main')->Require($Modules->{$Module}->{Module}) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Print module $Modules->{$Module}->{Module} not found!"
                );
                next;
            }
            my $BackendObject = $Modules->{$Module}->{Module}->new( %{$Self} );

            # if the backend constructor failed, it returns an error hash, skip
            next if ( ref $BackendObject ne $Modules->{$Module}->{Module} );

            $Self->{"Backend$Module"} = $BackendObject;
        }
    }

    return $Self;
}

sub Convert {
    my ($Self, %Param) = @_;

    my $LogObject               = $Kernel::OM->Get('Log');
    my $MainObject              = $Kernel::OM->Get('Main');
    my $ConfigObject            = $Kernel::OM->Get('Config');
    my $JSONObject              = $Kernel::OM->Get('JSON');
    my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

    my %Data = $Self->DefinitionGet(
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

    my $Config        = $ConfigObject->Get('HTMLToPDF::wkhtmltopdf');
    my $TempDir       = $ConfigObject->Get('TempDir');
    my $Directory     = $TempDir . '/PDFPrint';
    my $ContentType   = 'application/pdf';
    my $FileExtension = '.pdf';
    my $Filename      = $Param{Filename} || q{};
    my $Output        = q{};

    if (
        !$Config->{Binary}
        || !-e $Config->{Binary}
    ) {
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

    my %FileDatas;
    for my $Key ( qw(Header Content Footer ) ) {
        $FileDatas{$Key} = $Self->_GeneratHTML(
            %Param,
            Block     => $Data{Definition}->{$Key},
            Filename  => $Filename . '_' . $Key,
            Directory => $Directory,
            Object    => $Data{Object},
            Expands   => $Data{Definition}->{Expands},
            Filters   => $Data{Definition}->{Filters},
            Allows    => $Data{Definition}->{Allows},
            Ignores   => $Data{Definition}->{Ignores},
        );
    }

    # prepare temp file names
    my $TempPDFFile  = $Filename . '-Temp.pdf';
    $Self->_Call(
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

    my %Config    = %{$Param{Config}};
    my %Page      = %{$Param{Page}};
    my $Directory = $Param{Directory};
    my $Header    = $Param{Header};
    my $Footer    = $Param{Footer};
    my $Content   = $Param{Content};
    my $TmpPDF    = $Param{TmpPDF};

    # prepare system call
    my $SystemCall = $Config{Binary};
    # add parameter to system call
    if ( ref( $Config{Parameter} ) eq 'ARRAY' ) {
        $SystemCall .= q{ } . join( q{ }, @{ $Config{Parameter} });
    }
    # add content parameter to system call
    for my $Key ( qw(
            Top Bottom Left Right
        )
    ) {
        next if !$Page{$Key};
        my $Char = substr( $Key,0,1 );
        if ( $Page{$Key} ) {
            $SystemCall .= " -$Char $Page{$Key}";
        }
    }
    if ( $Page{SpacingHeader} ) {
        $SystemCall .= ' --header-spacing ' . $Page{SpacingHeader};
    }
    if ( $Page{SpacingFooter} ) {
        $SystemCall .= ' --footer-spacing ' . $Page{SpacingFooter};
    }

    if ( $Header ) {
        $SystemCall .= q{ --header-html "} . $Directory . q{/} . $Header . q{"};
    }
    if ( $Footer ) {
        $SystemCall .= q{ --footer-html "} . $Directory . q{/} . $Footer . q{"};
    }

    # add input to system call
    $SystemCall .= q{ "} . $Directory . q{/} . $Content . q{"};
    # add output to system call
    $SystemCall .= q{ "} . $Directory . q{/} . $TmpPDF . q{"};

    # call wkhtmltopdf from commandline...
    system($SystemCall);

    return 1;
}

sub _FileDelete {
    my ($Self, %Param) = @_;

    my $MainObject   = $Kernel::OM->Get('Main');

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

sub PossibleExpandsGet {
    my ($Self, %Param) = @_;

    return  $Self->{"Backend$Param{Object}"}->GetPossibleExpands();
}

sub DefinitionGet {
    my ($Self, %Param) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $DBObject   = $Kernel::OM->Get('DB');
    my $JSONObject = $Kernel::OM->Get('JSON');

    if (
        !$Param{ID}
        && !$Param{Name}
    ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'No given ID or Name!'
        );
        return;
    }
    my @Bind;
    my $SQL = <<'END';
SELECT id, name, object, valid_id, definition, created, created_by, changed, changed_by
FROM html_to_pdf
WHERE
END

    if ( $Param{ID} ) {
        $SQL .= ' id = ?';
        push( @Bind, \$Param{ID} );
    }
    else {
        $SQL .= ' name = ?';
        push( @Bind, \$Param{Name} );
    }

    return if !$DBObject->Prepare(
        SQL   => $SQL,
        Bind  => \@Bind,
        Limit => 1
    );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{Definition} = $JSONObject->Decode(
            Data => $Row[4]
        );
        $Data{ID}        = $Row[0];
        $Data{Name}      = $Row[1];
        $Data{Object}    = $Row[2];
        $Data{ValidID}   = $Row[3];
        $Data{Created}   = $Row[5];
        $Data{CreatedBy} = $Row[6];
        $Data{Changed}   = $Row[7];
        $Data{ChangedBy} = $Row[8];
        $Data{IDKey}     = $Self->{"Backend$Row[2]"}->{IDKey}     || q{};
        $Data{NumberKey} = $Self->{"Backend$Row[2]"}->{NumberKey} || q{};
    }

    return %Data;
}

sub DefinitionAdd {
    my ($Self, %Param) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $DBObject   = $Kernel::OM->Get('DB');

    for my $Needed ( qw(
            Name Object ValidID Definition UserID
        )
    ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Needed $Needed!"
            );
            return;
        }
    }

    return if !$DBObject->Do(
        SQL  => <<'END',
INSERT INTO html_to_pdf
    (name, description, object, valid_id, definition, created, created_by, changed, changed_by)
VALUES
    (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)
END
        Bind => [
            \$Param{Name},   \$Param{Description},
            \$Param{Object},
            \$Param{ValidID},\$Param{Definition},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    return if !$DBObject->Prepare(
        SQL   => <<'END',
SELECT id
FROM html_to_pdf
WHERE name = ?
END
        Bind  => [ \$Param{Name} ],
        Limit => 1
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    return $ID;
}

sub DefinitionUpdate {
    my ($Self, %Param) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $DBObject   = $Kernel::OM->Get('DB');

    for my $Needed ( qw(
            ID Name Object ValidID Definition UserID
        )
    ) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Needed $Needed!"
            );
            return;
        }
    }

    return if !$DBObject->Do(
        SQL  => <<'END',
UPDATE html_to_pdf
SET
    name       = ?,
    object     = ?,
    definition = ?,
    valid_id   = ?,
    changed    = current_timestamp,
    changed_by = ?
WHERE id = ?
END
        Bind => [
            \$Param{Name},    \$Param{Object},
            \$Param{Definition},
            \$Param{ValidID}, \$Param{UserID},
            \$Param{ID},
        ],
    );

    return 1;
}

sub DefinitionDataList {
    my ($Self, %Param) = @_;

    my $LogObject   = $Kernel::OM->Get('Log');
    my $DBObject    = $Kernel::OM->Get('DB');
    my $ValidObject = $Kernel::OM->Get('Valid');

    my $Result = $Param{Result} || 'HASH';

    # set valid option
    my $Valid = $Param{Valid};
    if ( !defined $Valid || $Valid ) {
        $Valid = 1;
    }
    else {
        $Valid = 0;
    }

    # sql query
    my $SQL = <<'END';
SELECT id
FROM html_to_pdf
END
    if ($Valid) {
        $SQL .= " WHERE valid_id IN "
            . "( ${\(join ', ', $ValidObject->ValidIDsGet())} )";
    }

    return if !$DBObject->Prepare(
        SQL => $SQL
    );

    # fetch the result
    my @IDList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push(@IDList, $Row[0]);
    }

    if ( $Result eq 'ARRAY' ) {
        return @IDList;
    }

    my %List;
    for my $ID ( @IDList ) {
        %{$List{$ID}} = $Self->DefinitionGet(
            ID => $ID
        );
    }

    return %List;
}

sub _CheckParams {
    my ( $Self, %Param ) = @_;

    return $Self->{"Backend$Param{Object}"}->CheckParams(
        %{$Param{Data}}
    );
}

sub _GeneratHTML {
    my ( $Self, %Param ) = @_;

    return q{} if !IsArrayRefWithData($Param{Block});

    my $HasPage = 0;
    my $Output  = q{};
    my $Result  = $Param{Result} || q{};
    my $Object  = $Param{Object};
    my $Css     = q{};
    my $IDKey   = $Param{IDKey} || q{};
    my %Keys;

    if ( $Object ) {
        for my $Key ( qw{IDKey NumberKey} ) {
            if ( $Self->{"Backend$Object"}->{$Key} ) {
                $Keys{$Self->{"Backend$Object"}->{$Key}} = $Param{$Self->{"Backend$Object"}->{$Key}} || q{};
                $Keys{$Key} = $Self->{"Backend$Object"}->{$Key};
            }
        }

        if (
            !$Self->{$Object . 'Data'}
            || (
                $IDKey
                && $Keys{$IDKey}
                && $Self->{$Object . 'Data'}->{$IDKey} ne $Keys{$IDKey}
            )
        ) {
            $Self->{$Object . 'Data'} = $Self->{"Backend$Object"}->DataGet(
                %Keys,
                UserID  => $Param{UserID},
                Expands => $Param{Expands},
                Filters => $Param{Filters},
                Count   => $Param{Count}
            );

            return if !$Self->{$Object . 'Data'};
        }

        for my $Key ( qw{IDKey NumberKey} ) {
            if ( $Self->{"Backend$Object"}->{$Key} ) {
                my $ParamKey = $Self->{"Backend$Object"}->{$Key};
                $Keys{$ParamKey} = $Self->{$Object . 'Data'}->{$ParamKey} || q{};
            }
        }
    }

    my $Datas = $Self->{$Object . 'Data'};
    if ( $Param{Data} ) {
        return q{} if ( !$Datas->{Expands}->{$Param{Data}} );
        $Datas = $Datas->{Expands}->{$Param{Data}};
    }

    for my $Block ( @{$Param{Block}} ) {
        $HasPage = 1 if $Block->{Type} && $Block->{Type} eq 'Page';
        my $Content = q{};
        my $BlockData;
        if ( $Block->{Data} ) {
            next if ( !$Datas->{Expands}->{$Block->{Data}} );
            $BlockData = $Datas->{Expands}->{$Block->{Data}};
        }
        elsif (
            $Block->{Include}
            && $Datas->{Expands}->{$Block->{Include}}
        ) {
            %{$BlockData} = (
                %{$Self->{$Object . 'Data'}},
                %{$Self->{$Object . 'Data'}->{Expands}->{$Block->{Include}}}
            );
        }
        else {
            $BlockData = $Datas;
        }

        if ( $Block->{Blocks} ) {
            if ( !$Block->{ID} ) {
                $Block->{ID} = 'Blocks';
            }
            if (
                $Block->{Type}
                && $Block->{Type} eq 'List'
                && $Block->{Object}
                && $Block->{Data}
            ) {

                my $Count = 0;
                ID:
                for my $ID ( @{$BlockData} ) {
                    $Count++;

                    my %ListKeys;

                    if( $Self->{"Backend$Block->{Object}"}->{IDKey} ) {
                        $ListKeys{$Self->{"Backend$Block->{Object}"}->{IDKey}} = $ID || q{};
                        $ListKeys{IDKey} = $Self->{"Backend$Block->{Object}"}->{IDKey};
                    }

                    my %HTML = $Self->_GeneratHTML(
                        %ListKeys,
                        UserID     => $Param{UserID},
                        Block      => $Block->{Blocks},
                        Result     => 'Content',
                        Object     => $Block->{Object} || $Object,
                        Expands    => $Block->{Expand},
                        Count      => $Count,
                        Filters    => $Param{Filters},
                        Allows     => $Param{Allows},
                        Ignores    => $Param{Ignores}
                    );

                    next ID if !%HTML;

                    $Css     .= $HTML{Css};
                    $Content .= $HTML{HTML};
                }
            }
            else {
                my %HTML = $Self->_GeneratHTML(
                    %Param,
                    Object  => $Block->{Object} || $Object,
                    Data    => $Block->{Data} || q{},
                    Block   => $Block->{Blocks},
                    Result  => 'Content',
                    Filters => $Param{Filters},
                    Allows  => $Param{Allows},
                    Ignores => $Param{Ignores}
                );
                $Css     .= $HTML{Css};
                $Content .= $HTML{HTML};
            }
        }
        elsif ( $Block->{Type} ) {

            my $Function = "_Render$Block->{Type}";
            my %HTML = $Self->$Function(
                %Keys,
                Data    => $BlockData,
                Block   => $Block,
                UserID  => $Param{UserID},
                Count   => $Param{Count},
                Allows  => $Param{Allows},
                Ignores => $Param{Ignores}
            );
            $Css     .= $HTML{Css};
            $Content .= $HTML{HTML};
        }
        $Output .= $Self->_RenderBlock(
            Data => {
                ID    => $Block->{ID} || q{},
                Value => $Content,
            }
        );
    }

    if ( $Result ne 'Content' ) {

        my $HTML = $Self->_RenderContainer(
            Data => {
                Value   => $Output,
                CSS     => $Css,
                HasPage => $HasPage,
                %Keys
            }
        );

        # write html to fs
        return $Kernel::OM->Get('Main')->FileWrite(
            Directory  => $Param{Directory},
            Filename   => $Param{Filename} . '.html',
            Content    => \$HTML,
            Mode       => 'binmode',
            Type       => 'Local',
            Permission => '640',
        );

    }

    return (
        Css  => $Css,
        HTML => $Output
    );
}

sub _RenderContainer {
    my ($Self, %Param) = @_;
    my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

    return $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Container',
        Data => {
            Value   => $Param{Data}->{Value},
            HasPage => $Param{Data}->{HasPage} // 0,
            CSS     => $Param{Data}->{CSS} || q{}
        }
    );
}

sub _RenderBlock {
    my ($Self, %Param) = @_;
    my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

    return $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Block',
        Data => {
            Value => $Param{Data}->{Value} // q{},
            ID    => $Param{Data}->{ID} || q{}
        }
    );
}

sub _RenderPage {
    my ($Self, %Param) = @_;
    my $LayoutObject = $Kernel::OM->Get('Output::HTML::Layout');

    my $Datas = $Param{Data};
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
            TemplateFile => 'HTMLToPDF/Page',
        );
        $Self->{CSSIDs}->{$Block->{ID}} = 1;
    }

    $LayoutObject->Block(
        Name => 'HTML',
        Data => {
            Translate => $Block->{Translate},
            PageOf    => $Block->{PageOf},
        }
    );

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Page',
    );

    return (
        HTML => $HTML,
        Css  => $Css
    );
}

sub _RenderText {
    my ($Self, %Param) = @_;

    my $LayoutObject            = $Kernel::OM->Get('Output::HTML::Layout');
    my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

    my $Datas = $Param{Data};
    my $Block = $Param{Block};
    my $IDKey = $Param{IDKey};
    my $Css   = q{};
    my $Value;
    my $Class;

    if (
        $Block->{ID}
        && !$Self->{CSSIDs}->{$Block->{ID}}
    ) {
        $LayoutObject->Block(
            Name => 'CSS',
            Data => $Block
        );

        $Css = $LayoutObject->Output(
            TemplateFile => 'HTMLToPDF/Text',
        );
        $Self->{CSSIDs}->{$Block->{ID}} = 1;
    }

    if ( ref $Block->{Value} eq 'ARRAY' ) {
        my @Values;
        for my $Entry ( @{$Block->{Value}} ) {
            my %Result = $Self->_ReplacePlaceholders(
                String    => $Entry,
                UserID    => $Param{UserID},
                Count     => $Param{Count},
                Translate => $Block->{Translate}
            );

            if ( !$Class ) {
                $Class = $Result{Font};
            }

            my $TmpValue = $TemplateGeneratorObject->ReplacePlaceHolder(
                Text     => $Result{Text},
                $IDKey   => $Param{$IDKey},
                Data     => {},
                UserID   => $Param{UserID},
                RichText => 1
            );

            if ( $Block->{Translate} ) {
                $TmpValue = $LayoutObject->{LanguageObject}->Translate($TmpValue);
            }

            push( @Values, $TmpValue);
        }
        $Value = join( ($Block->{Join} // q{ }), @Values);
    }
    else {
        my %Result = $Self->_ReplacePlaceholders(
            String    => $Block->{Value},
            UserID    => $Param{UserID},
            Count     => $Param{Count},
            Translate => $Block->{Translate}
        );

        if ( !$Class ) {
            $Class = $Result{Font};
        }

        $Value = $TemplateGeneratorObject->ReplacePlaceHolder(
            Text     => $Result{Text},
            $IDKey   => $Param{$IDKey},
            Data     => {},
            UserID   => $Param{UserID},
            RichText => 1
        );
    }

    $LayoutObject->Block(
        Name => 'HTML',
        Data => {
            Value  => $Value,
            IsLink => $Block->{AsLink} || 0,
            Class  => $Class
        }
    );

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Text',
    );

    return (
        HTML => $HTML,
        Css  => $Css
    );
}

sub _RenderRichtext {
    my ($Self, %Param) = @_;

    my $LayoutObject            = $Kernel::OM->Get('Output::HTML::Layout');
    my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

    my $Datas = $Param{Data};
    my $Block = $Param{Block};
    my $IDKey = $Param{IDKey};
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

        $Css = $LayoutObject->Output(
            TemplateFile => 'HTMLToPDF/Richtext',
        );
        $Self->{CSSIDs}->{$Block->{ID}} = 1;
    }

    if ( ref $Block->{Value} eq 'ARRAY' ) {
        my @Values;
        for my $Entry ( @{$Param{Data}->{Value}} ) {
            my $TmpValue = $TemplateGeneratorObject->ReplacePlaceHolder(
                Text     => $Entry,
                $IDKey   => $Param{$IDKey},
                Data     => {},
                UserID   => $Param{UserID},
                RichText => 1
            );

            $TmpValue =~ s/<\/?div[^>]*>//gsmx;
            $TmpValue =~ s{<p>(<img\salt=""\ssrc=".*\"\s\/>)<\/p>}{$1}gsmx;

            if ( $Block->{Translate} ) {
                $TmpValue = $LayoutObject->{LanguageObject}->Translate($TmpValue);
            }

            push( @Values, $TmpValue);
        }
        $Value = join( ($Block->{Join} // q{ }), @Values);
    }
    else {
        $Value = $TemplateGeneratorObject->ReplacePlaceHolder(
            Text     => $Block->{Value},
            $IDKey   => $Param{$IDKey},
            Data     => {},
            UserID   => $Param{UserID},
            RichText => 1
        );

        $Value =~ s/<\/?div[^>]*>//gsmx;
        $Value =~ s{<p>(<img\salt=""\ssrc=".*\"\s\/>)<\/p>}{$1}gsmx;
    }

    $LayoutObject->Block(
        Name => 'HTML',
        Data => {
            Value  => $Value
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

sub _RenderTable {
    my ($Self, %Param) = @_;

    my $LayoutObject            = $Kernel::OM->Get('Output::HTML::Layout');
    my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

    my %Ignore;
    my %Allow;
    my $Datas = $Param{Data};
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
        Name => 'HTML'
    );

    $Self->_CheckTableRestriction(
        Allow   => \%Allow,
        Ignore  => \%Ignore,
        Block   => $Block,
        Ignores => $Param{Ignores},
        Allows  => $Param{Allows}
    );

    my %AddClass;
    my $IsDefault = 0;
    my @Columns;
    if ( IsArrayRefWithData($Block->{Columns}) ) {
        for my $Column ( @{$Block->{Columns}} ) {
            next if !$Column;
            my %Entry = $Self->_ReplacePlaceholders(
                String => $Column
            );
            if ( $Entry{Text} =~ /^(?:Count|Key|Value)$/smx ) {
                $IsDefault = 1;
            }

            $AddClass{$Entry{Text}} = $Entry{Font};
            push(@Columns, $Entry{Text});
        }
    }

    if ( $Block->{Headline} ) {
        $LayoutObject->Block(
            Name => 'HeadBlock'
        );

        for my $Column ( @Columns ) {
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

    my $Count = 0;
    if (
        $IsDefault
        && ref $Datas eq 'HASH'
    ) {
        for my $Key ( sort keys %{$Datas} ) {
            next if $Key eq 'Expands';
            if ( %Allow ) {
                next if !defined $Allow{$Key};
                next if $Allow{$Key} ne 'KEY' && $Datas->{$Key} !~ m/$Allow{$Key}/smx;
            }

            if ( %Ignore ) {
                next if defined $Ignore{$Key} && $Ignore{$Key} eq 'KEY';
                next if defined $Ignore{$Key} && $Datas->{$Key} =~ m/$Ignore{$Key}/smx;
            }

            $LayoutObject->Block(
                Name => 'BodyRow'
            );

            $Self->_ColumnValueGet(
                Columns   => \@Columns,
                Key       => $Key,
                Data      => $Datas,
                Translate => $Block->{Translate},
                Join      => $Block->{Join},
                Count     => $Count,
                Classes   => \%AddClass
            );
            $Count++;
        }
    }
    if (
        !$IsDefault
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
                if ( %Allow ) {
                    next if !defined $Allow{$Key};
                    next if $Allow{$Key} ne 'KEY' && $ObjectData{$Key} !~ m/$Allow{$Key}/smx;
                }

                if ( %Ignore ) {
                    next if defined $Ignore{$Key} && $Ignore{$Key} eq 'KEY';
                    next if defined $Ignore{$Key} && $ObjectData{$Key} =~ m/$Ignore{$Key}/smx;
                }
            }

            $LayoutObject->Block(
                Name => 'BodyRow'
            );

            $Self->_ColumnValueGet(
                Columns   => \@Columns,
                Data      => \%ObjectData,
                Translate => $Block->{Translate},
                Join      => $Block->{Join},
                Count     => $Count,
                Classes   => \%AddClass
            );
            $Count++;
        }
    }

    my $HTML = $LayoutObject->Output(
        TemplateFile => 'HTMLToPDF/Table',
    );
    return (
        HTML => $HTML,
        Css  => $Css
    );
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

sub _RenderImage {
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
            Translate => $Block->{Translate}
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