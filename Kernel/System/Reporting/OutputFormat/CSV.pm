# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::OutputFormat::CSV;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Reporting::OutputFormat::Common);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Reporting::OutputFormat::CSV - output format for reporting lib

=head1 SYNOPSIS

Handles CSV output of reports.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this output format module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Converts the report data to CSV.'));
    $Self->AddOption(
        Name        => 'Columns',
        Label       => Kernel::Language::Translatable('Columns'),
        Description => Kernel::Language::Translatable('A list (Array) of the columns to be contained in the order in which they should occur in the output result. If omitted all columns will be used.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Separator',
        Label       => Kernel::Language::Translatable('Separator'),
        Description => Kernel::Language::Translatable('The value separator to be used. Default: , (Comma).'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Quote',
        Label       => Kernel::Language::Translatable('Quote'),
        Description => Kernel::Language::Translatable('The quote character to be used. Default: " (Double Quote).'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'IncludeColumnHeader',
        Label       => Kernel::Language::Translatable('Include Column Headers'),
        Description => Kernel::Language::Translatable('Determine if a header containing the column names should be contained. Default: 1 (true).'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'TranslateColumnNames',
        Label       => Kernel::Language::Translatable('Translate Column Names'),
        Description => Kernel::Language::Translatable('Translate the column names. Default: 1 (true). If set to a language identifier, i.e. "de", this language will be used.'),
        Required    => 0,
    );

    return;
}

=item ValidateConfig()

Validates the config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # optional
    );

=cut

sub ValidateConfig {
    my ( $Self, %Param ) = @_;

    # do some basic checks
    return if !$Self->SUPER::ValidateConfig(
        %Param,
        Config => $Param{Config} || {}      # Config
    );

    # validate if Columns is an ArrayRef
    if ( exists $Param{Config}->{Columns} && !IsArrayRef($Param{Config}->{Columns}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Config "Columns" is not an ArrayRef!',
        );
        return;
    }

    foreach my $Option ( qw(Separator Quote) ) {
        if ( exists $Param{Config}->{$Option} && !$Param{Config}->{$Option} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Config \"$Option\" is invalid!",
            );
            return;
        }
    }

    my $Languages = $Kernel::OM->Get('Config')->Get('DefaultUsedLanguages');

    if ( $Param{Config}->{TranslateColumnNames} && $Param{Config}->{TranslateColumnNames} =~ /^[a-zA-Z]+$/g && !$Languages->{$Param{Config}->{TranslateColumnNames}} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Language \"$Param{Config}->{TranslateColumnNames}\" not supported!",
        );
        return;
    }

    return 1;
}

=item Run()

Run this output module. Returns a HashRef with the result if successful, otherwise undef.

Example:
    my $Result = $Object->Run(
        Config => { },
        Data   => [
            {...},
            {...},
        ],        # the row array containing the data
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Config Data)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # check some more needed stuff
    for (qw(Columns Data)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Parameter \"Data\" doesn't contain $_!",
            );
            return;
        }
    }

    # replace parameters
    $Self->_ReplaceParametersInHashRef(
        HashRef => $Param{Config}
    );

    my @Rows;

    foreach my $Row ( @{$Param{Data}->{Data}} ) {
        my @ResultRow;
        foreach my $Column ( @{$Param{Config}->{Columns} || $Param{Data}->{Columns}} ) {
            push @ResultRow, $Row->{$Column};
        }
        push @Rows, \@ResultRow;
    }

    my $IncludeColumnHeader = defined $Param{Config}->{IncludeColumnHeader} ? $Param{Config}->{IncludeColumnHeader} : 1;
    my $TranslateColumnNames = defined $Param{Config}->{TranslateColumnNames} ? $Param{Config}->{TranslateColumnNames} : 1;

    my @Columns = @{$Param{Config}->{Columns} || $Param{Data}->{Columns} || []};

    if ( $TranslateColumnNames ) {
        if ( $TranslateColumnNames =~ /^[a-zA-Z]+$/g ) {
            $Kernel::OM->ObjectParamAdd(
                'Language' => {
                    UserLanguage => $TranslateColumnNames,
                },
            );
        }
        my $LanguageObject = $Kernel::OM->Get('Language');

        foreach my $Column ( @Columns ) {
            $Column = $LanguageObject->Translate($Column);
        }
    }

    # convert to CSV
    my $Result = $Kernel::OM->Get('CSV')->Array2CSV(
        WithHeader => $Param{Config}->{Title} ? [ $Param{Config}->{Title} ] : undef,
        Head       => $IncludeColumnHeader ? \@Columns : undef,
        Data       => \@Rows,
        Separator  => $Param{Config}->{Separator},
        Quote      => $Param{Config}->{Quote},
        Format     => 'CSV',
    );

    return {
        ContentType => 'text/csv',
        Content     => $Result,
    };
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
