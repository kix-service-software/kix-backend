# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Common::ExtractText;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Common);

our @ObjectDependencies = (
    'Log',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Common::ExtractText - A module to extract text via RegEx

=head1 SYNOPSIS

All ExtractText functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Extract parts of a text via Regular Expressions (RegEx).'));
    $Self->AddOption(
        Name        => 'RegEx',
        Label       => Kernel::Language::Translatable('RegEx'),
        Description => Kernel::Language::Translatable('The RegEx containing the capture groups.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Text',
        Label       => Kernel::Language::Translatable('Text'),
        Description => Kernel::Language::Translatable('The text containing the data.'),
        Required    => 0,
        Placeholder => {
            Richtext  => 0,
            Translate => 0,
        },
    );
    $Self->AddOption(
        Name        => 'CaptureGroupNames',
        Label       => Kernel::Language::Translatable('Capture Group Names'),
        Description => Kernel::Language::Translatable('If you don\'t use a RegEx with named capture groups, you can give a comma separated list of names for the capture groups. The order corresponds to the capture group id. If not given, the IDs of the capture groups will be used, starting from 1.'),
        Required    => 0,
    );

    $Self->AddResult(
        Name        => 'ExtractedText',
        Description => Kernel::Language::Translatable('The extracted text(s).'),
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        ObjectID => 123,
        Config   => {
            RegEx  => '...',
            CaptureGroupNames => 'test1,test2,test3',
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my $Text = $Param{Config}->{Text} || '';

    # extract the matches
    my %Results;
    if ( my @Captured = $Text =~ /$Param{Config}->{RegEx}/smx ) {
        my $Index = 0;
        if ( $Param{Config}->{CaptureGroupNames} ) {
            # use the configured names
            foreach my $Name ( split(/\s*,\s*/, $Param{Config}->{CaptureGroupNames}) ) {
                $Results{$Name} = $Captured[$Index++];
            }
        }
        elsif ( %+ ) {
            # named capture groups
            %Results = %+;
        }
        else {
            # fallback
            %Results = map { ++$Index => $_ } @Captured;
        }
    }

    # return the captured results
    $Self->SetResult(
        Name   => 'ExtractedText',
        Value  => \%Results,
        UserID => $Param{UserID}
    );

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
