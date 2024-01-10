# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Autostart;

use strict;
use warnings;

use Text::ParseWords;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

our @ObjectDependencies = (
    'Config',
    'Log',
);

=head1 NAME

Kernel::System::ClientRegistration

=head1 SYNOPSIS

Add address book functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a Autostart object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Config');
    $Self->{LogObject}    = $Kernel::OM->Get('Log');

    return $Self;
}

=item Run()

Run autostart.

    my $Result = $AutostartObject->Run();

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Home = $Kernel::OM->Get('Config')->Get('Home');

    my @Files = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => $Home.'/autostart',
        Filter    => '*'
    );

    foreach my $File ( sort @Files ) {

        next if ($File =~ m/\.old$/); # ignore "old" files (dev environment, module-linker)

        my $Content = $Kernel::OM->Get('Main')->FileRead(
            Location => $File,
            Result   => 'ARRAY'
        );

        if ( !IsArrayRefWithData($Content) ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message => "Unable to read autostart file $File!"
            );
            return;
        }

        foreach my $Line ( @{$Content} ) {

            # ignore empty lines and comments
            next if ( $Line =~ /^\s*$/ || $Line =~ /^\s*#/ );

            # replace placeholders
            $Line = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
                Text     => $Line,
                Data     => {},
                RichText => 0,
                UserID   => 1,
            );

            # remove line break
            chomp($Line);

            # replace leading and trailing spaces
            $Line =~ s/(^\s+|\s+$)//g;

            my @Command = Text::ParseWords::quotewords('\s+', 0, $Line);

            if ( @Command ) {
                my $Result = $Kernel::OM->Get('Console')->Run(@Command);
                if ( $Result ) {
                    $Self->{LogObject}->Log(
                        Priority => 'error',
                        Message => "Unable to execute autostart file $File!"
                    );
                    return $Result;
                }
            }
            else {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message => "Unable to execute line '$Line' in autostart file $File!"
                );
                return 1;
            }
        }
    }

    return 0;
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
