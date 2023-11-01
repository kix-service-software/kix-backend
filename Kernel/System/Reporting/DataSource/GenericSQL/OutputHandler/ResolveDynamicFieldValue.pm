# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::ResolveDynamicFieldValue;

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

Kernel::System::Reporting::DataSource::GenericSQL::OutputHandler::ResolveDynamicFieldValue - an output handler for reporting lib data source GenericSQL

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this output handler module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Resolves the actual display value of a dynamic field.'));
    $Self->AddOption(
        Name        => 'Columns',
        Label       => Kernel::Language::Translatable('Columns'),
        Description => Kernel::Language::Translatable('The columns in the raw data containing the Dynamic Field values to resolve.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'FieldNames',
        Label       => Kernel::Language::Translatable('Field Names'),
        Description => Kernel::Language::Translatable('The names of the Dynamic Fields corresponding with the column config.'),
        Required    => 1,
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
    foreach my $Option ( qw(Columns FieldNames) ) {
        if ( !IsArrayRefWithData($Param{Config}->{$Option}) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "ResolveDynamicFieldValue: $Option is not an ARRAY ref or doesn't contain any configuration!",
                );
            }
            return;
        }
    }

    if ( scalar @{$Param{Config}->{Columns}} != scalar @{$Param{Config}->{FieldNames}} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "ResolveDynamicFieldValue: number of list items in Columns and FieldNames is different!",
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

    my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    # get all dynamic fields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet();
    if ( !$DynamicFieldList ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unable to get the list of Dynamic Fields!",
        );
        return;
    }
    my %DynamicFieldConfig = map { $_->{Name} => $_ } @{$DynamicFieldList || []};

    # map columns to field names
    my %ColumnToFieldName;
    my $Index = 0;
    foreach my $Column ( @{$Param{Config}->{Columns}} ) {
        my $Column = $Self->_ReplaceParametersInString(
            String => $Column,
        );
        $ColumnToFieldName{$Column} = $Param{Config}->{FieldNames}->[$Index++]
    }

    ROW:
    foreach my $Row ( @{$Param{Data}->{Data} || []} ) {
        COLUMN:
        foreach my $Column ( @{$Param{Config}->{Columns}}) {
            next COLUMN if !exists $Row->{$Column} || !defined $Row->{$Column};

            # get the current value for each dynamic field
            my $Value = $DynamicFieldBackendObject->ValueLookup(
                DynamicFieldConfig => $DynamicFieldConfig{$ColumnToFieldName{$Column}},
                Key                => $Row->{$Column},
            );
            $Row->{$Column} = join(',', IsArrayRef($Value) ? @{$Value} : ($Value));
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
