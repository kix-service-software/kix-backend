# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Autostart;

use strict;
use warnings;

use Text::ParseWords;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
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
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    
    return $Self;
}

=item Run()

Run autostart.

    my $Result = $AutostartObject->Run();

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    
    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');

    my @Files = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $Home.'/autostart',
        Filter    => '*'
    );

    foreach my $File ( sort @Files ) {
        my $Content = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
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

            chomp($Line);
            my @Command = Text::ParseWords::quotewords('\s+', 0, $Line);
    
            if ( @Command ) {
                my $Result = $Kernel::OM->Get('Kernel::System::Console::InterfaceConsole')->Run(@Command);
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
