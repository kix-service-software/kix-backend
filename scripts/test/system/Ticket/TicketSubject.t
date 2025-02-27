# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

for my $TicketHook ( 'Ticket#', 'Call#', 'Ticket' ) {

    for my $TicketSubjectConfig ( 'Right', 'Left' ) {

        # make sure that the TicketObject gets recreated for each loop.
        $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::Hook',
            Value => $TicketHook,
        );
        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::SubjectFormat',
            Value => $TicketSubjectConfig,
        );
        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::NumberGenerator',
            Value => 'Kernel::System::Ticket::Number::DateChecksum',
        );
        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::SubjectRe',
            Value => 'RE',
        );
        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::SubjectFwd',
            Value => 'AW',
        );

        $Self->True(
            $Kernel::OM->Get('Ticket')->isa('Kernel::System::Ticket::Number::DateChecksum'),
            "TicketObject loaded the correct backend",
        );

        # check GetTNByString
        my $Tn = $Kernel::OM->Get('Ticket')->TicketCreateNumber() || 'NONE!!!';
        my $String = 'Re: ' . $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
            TicketNumber => $Tn,
            Subject      => 'Some Test',
        );
        my $TnGet = $Kernel::OM->Get('Ticket')->GetTNByString($String) || 'NOTHING FOUND!!!';
        $Self->Is(
            $TnGet,
            $Tn,
            "GetTNByString() (DateChecksum: true eq)",
        );
        $Self->IsNot(
            $Kernel::OM->Get('Ticket')->GetTNByString('Ticket#: 200206231010138') || '',
            $Tn,
            "GetTNByString() (DateChecksum: false eq)",
        );
        $Self->False(
            $Kernel::OM->Get('Ticket')->GetTNByString("Ticket#: 1234567") || 0,
            "GetTNByString() (DateChecksum: false)",
        );

        my $NewSubject = $Kernel::OM->Get('Ticket')->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'Re: [' . $TicketHook . ': 2004040510440485] Re: RE: Some Subject',
        );
        $Self->Is(
            $NewSubject,
            'Some Subject',
            "TicketSubjectClean() Re:",
        );

        # TicketSubjectClean()
        $NewSubject = $Kernel::OM->Get('Ticket')->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'Re[5]: [' . $TicketHook . ': 2004040510440485] Re: RE: WG: Some Subject',
        );
        $Self->Is(
            $NewSubject,
            'WG: Some Subject',
            "TicketSubjectClean() Re[5]:",
        );

        # TicketSubjectClean()
        $NewSubject = $Kernel::OM->Get('Ticket')->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'Re[5]: Re: RE: WG: Some Subject [' . $TicketHook . ': 2004040510440485]',
        );
        $Self->Is(
            $NewSubject,
            'WG: Some Subject',
            "TicketSubjectClean() Re[5]",
        );

        # TicketSubjectBuild()
        $NewSubject = $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
            TicketNumber => '2004040510440485',
            Subject      => "Re: [$TicketHook: 2004040510440485] Re: RE: WG: Some Subject",
        );
        if ( $TicketSubjectConfig eq 'Left' ) {
            $Self->Is(
                $NewSubject,
                'RE: [' . $TicketHook . '2004040510440485] WG: Some Subject',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }
        else {
            $Self->Is(
                $NewSubject,
                'RE: WG: Some Subject [' . $TicketHook . '2004040510440485]',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }

        # check Ticket::SubjectRe with "Antwort"
        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::SubjectRe',
            Value => 'Antwort',
        );
        $NewSubject = $Kernel::OM->Get('Ticket')->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'Antwort: ['
                . $TicketHook
                . ': 2004040510440485] Antwort: Antwort: Some Subject2',
        );
        $Self->Is(
            $NewSubject,
            'Some Subject2',
            "TicketSubjectClean() Antwort:",
        );

        # TicketSubjectBuild()
        $NewSubject = $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
            TicketNumber => '2004040510440485',
            Subject      => '[' . $TicketHook . ':2004040510440485] Antwort: Antwort: Some Subject2',
        );
        if ( $TicketSubjectConfig eq 'Left' ) {
            $Self->Is(
                $NewSubject,
                'Antwort: [' . $TicketHook . '2004040510440485] Some Subject2',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }
        else {
            $Self->Is(
                $NewSubject,
                'Antwort: Some Subject2 [' . $TicketHook . '2004040510440485]',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }

        # check Ticket::SubjectRe with "Antwort"
        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::SubjectRe',
            Value => '',
        );
        $NewSubject = $Kernel::OM->Get('Ticket')->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'RE: ['
                . $TicketHook
                . ': 2004040510440485] Antwort: Antwort: Some Subject2',
        );
        $Self->Is(
            $NewSubject,
            'RE: Antwort: Antwort: Some Subject2',
            "TicketSubjectClean() Re: Antwort:",
        );

        # TicketSubjectBuild()
        $NewSubject = $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
            TicketNumber => '2004040510440485',
            Subject      => 'Re: [' . $TicketHook . ': 2004040510440485] Re: Antwort: Some Subject2',
        );
        if ( $TicketSubjectConfig eq 'Left' ) {
            $Self->Is(
                $NewSubject,
                '[' . $TicketHook . '2004040510440485] Re: Re: Antwort: Some Subject2',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }
        else {
            $Self->Is(
                $NewSubject,
                'Re: Re: Antwort: Some Subject2 [' . $TicketHook . '2004040510440485]',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }

        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::SubjectRe',
            Value => 'Re',
        );

        # TicketSubjectClean()
        # check Ticket::SubjectFwd with "FWD"
        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::SubjectFwd',
            Value => 'FWD',
        );

        # TicketSubjectBuild()
        $NewSubject = $Kernel::OM->Get('Ticket')->TicketSubjectBuild(
            TicketNumber => '2004040510440485',
            Subject      => "Re: [$TicketHook: 2004040510440485] Re: RE: WG: Some Subject",
            Action       => 'Forward',
        );
        if ( $TicketSubjectConfig eq 'Left' ) {
            $Self->Is(
                $NewSubject,
                'FWD: [' . $TicketHook . '2004040510440485] WG: Some Subject',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }
        else {
            $Self->Is(
                $NewSubject,
                'FWD: WG: Some Subject [' . $TicketHook . '2004040510440485]',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }

        # check Ticket::SubjectFwd with "WG"
        $Kernel::OM->Get('Config')->Set(
            Key   => 'Ticket::SubjectFwd',
            Value => 'WG',
        );
        $NewSubject = $Kernel::OM->Get('Ticket')->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'Antwort: ['
                . $TicketHook
                . ': 2004040510440485] WG: Fwd: Some Subject2',
            Action => 'Forward',
        );
        $Self->Is(
            $NewSubject,
            'Antwort: WG: Fwd: Some Subject2',
            "TicketSubjectClean() Antwort:",
        );
    }
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
