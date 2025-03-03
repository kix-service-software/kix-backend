# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Reporting::DataSource::GenericSQL::Function::IfPluginAvailable;

use strict;
use warnings;

use URI::Escape;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Reporting::DataSource::GenericSQL::Function::Common);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'User',
    'Valid',
);

=head1 NAME

Kernel::System::Reporting::DataSource::GenericSQL::Function::IfPluginAvailable - a function for reporting lib data source GenericSQL

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this function module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Returns the given text if the requested plugin is available in this system.'));
    $Self->AddOption(
        Name        => 'Plugin',
        Label       => Kernel::Language::Translatable('Plugin'),
        Description => Kernel::Language::Translatable('The name of the plugin to check for.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Text',
        Label       => Kernel::Language::Translatable('Text'),
        Description => Kernel::Language::Translatable('The text to return if the requested plugin is available.'),
        Required    => 1,
    );

    return;
}

=item Run()

Run this module. Returns the result if successful, otherwise undef.

Example:
    my $Result = $Object->Run(
        Plugin => 'KIXPro',
        Text   => 'this is a test'
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $IsAvailable = $Kernel::OM->Get('Installation')->PluginAvailable(
        Plugin => $Param{Plugin}
    );

    return $Param{Text} if $IsAvailable;

    return '';
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
