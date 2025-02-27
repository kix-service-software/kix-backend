# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::Translate;

use strict;
use warnings;

use URI::Escape;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::Common);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::Translate - an output handler for reporting lib data source GenericSQL

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this output handler module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Translate a value.'));
    $Self->AddOption(
        Name        => 'Columns',
        Label       => Kernel::Language::Translatable('Columns'),
        Description => Kernel::Language::Translatable('The columns in the raw data to be translated.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Language',
        Label       => Kernel::Language::Translatable('Language'),
        Description => Kernel::Language::Translatable('The identifier of the language, i.e "de". If not given, the systems default language will be used.'),
        Required    => 0,
    );

    return;
}

=item ValidateConfig()

Validates the required config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # required
    );

=cut

sub ValidateConfig {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Config} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Got no Config!',
            );
        }
        return;
    }

    return if !$Self->SUPER::ValidateConfig(%Param);

    # validate the columns
    if ( !IsArrayRefWithData($Param{Config}->{Columns}) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Translate: Columns is not an ARRAY ref or doesn't contain any configuration!",
            );
        }
        return;
    }

    my $Languages = $Kernel::OM->Get('Config')->Get('DefaultUsedLanguages');

    if ( $Param{Config}->{Language} && !$Languages->{$Param{Config}->{Language}} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Translate: language \"$Param{Config}->{Language}\" not supported!",
            );
        }
        return;
    }

    return 1;
};

=item Run()

Run this module. Returns an ArrayRef with the result if successful, otherwise undef.

Example:
    my $Result = $Object->Run(
        Config => { },         # optional
        Data   => {
            Columns => [],
            Data    => [
            {...},
            {...},
        ],        # the row array containing the data
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    $Kernel::OM->ObjectParamAdd(
        'Language' => {
            UserLanguage => $Param{Config}->{Language},
        },
    );
    my $LanguageObject = $Kernel::OM->Get('Language');

    ROW:
    foreach my $Row ( @{$Param{Data}->{Data} || []} ) {
        COLUMN:
        foreach my $Column ( @{$Param{Config}->{Columns}}) {
            next COLUMN if !exists $Row->{$Column} || !defined $Row->{$Column};

            $Row->{$Column} = $LanguageObject->Translate($Row->{$Column});
        }
    }

    return $Param{Data};
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
