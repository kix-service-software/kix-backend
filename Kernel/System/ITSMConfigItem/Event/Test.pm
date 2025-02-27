# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::Event::Test;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # create needed objects
    $Self->{LogObject}   = $Kernel::OM->Get('Log');

    my @keyarr = keys(%Param);

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    my %Error = ();

    #check required params...
    foreach (qw(Event UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "ITSMConfigItem-Event-Test: Need $_!"
            );
            return;
        }
    }

    my @ParamKeys = keys(%Param);

    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message  => "ITSMConfigItem-Event-Test: Event ($Param{Event}) "
            . "occured - keys: @ParamKeys."
    );

    #
    # THIS IS THE PART WHERE THE ACTUAL WORK IS DONE
    # ...check attributes, links and all this stuff...
    #

    #if this is a PreEvent, it's possible to change or add params in the calling module...
    #content of %ReturnParams will update %Param...
    #my %ReturnParams = ();
    #$ReturnParams{KEY} = NEWValue;
    #return \%ReturnParams;
    #...of course, the calling module needs to know about this

    #if some plausi check fails, set the error code an the corresponding message for the user...
    $Error{Error}   = 42;
    $Error{Message} = "Dude, this will never work - because it's a permanent message!";

#   ...of course, the calling module need to know about this. If so, it will be shown in the frontend...

    return \%Error;

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
