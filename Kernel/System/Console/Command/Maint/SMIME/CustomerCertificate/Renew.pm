# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::SMIME::CustomerCertificate::Renew;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'CheckItem',
    'Crypt::SMIME',
    'Contact',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Renew existing SMIME certificates from customer back-ends.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Renewing existing customer SMIME certificates...</yellow>\n");

    my $ConfigObject = $Kernel::OM->Get('Config');

    my $StopExecution;
    if ( !$ConfigObject->Get('SMIME') ) {
        $Self->Print("'SMIME' is not activated in SysConfig, can't continue!\n");
        $StopExecution = 1;
    }
    elsif ( !$ConfigObject->Get('SMIME::FetchFromCustomer') ) {
        $Self->Print("'SMIME::FetchFromCustomer' is not activated in SysConfig, can't continue!\n");
        $StopExecution = 1;
    }

    if ($StopExecution) {
        $Self->Print("\n<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my $CryptObject = $Kernel::OM->Get('Crypt::SMIME');
    if ( !$CryptObject ) {
        $Self->PrintError("SMIME environment its not working!\n");
        $Self->Print("<red>Fail.</red>\n");
        return $Self->ExitCodeError();
    }

    my ( $ListOfCertificates, $EmailsFromCertificates ) = $Self->_GetCurrentData();

    my $ContactObject = $Kernel::OM->Get('Contact');

    EMAIL:
    for my $Email ( sort keys %{$EmailsFromCertificates} ) {

        my %ContactList = $ContactObject->ContactSearch(
            Email => $Email,
            Limit => 1
        );

        next EMAIL if !%ContactList;

        my @UserIDs = sort keys %ContactList;

        my %Contact = $ContactObject->ContactGet(
            ID => $UserIDs[0],
        );

        next EMAIL if !%Contact;
        next EMAIL if !$Contact{UserSMIMECertificate};
        next EMAIL if $ListOfCertificates->{ $Contact{UserSMIMECertificate} };

        my @Files = $CryptObject->FetchFromCustomer(
            Search => $Email,
        );

        for my $Filename (@Files) {
            my $Certificate = $CryptObject->CertificateGet(
                Filename => $Filename,
            );

            my %CertificateAttributes = $CryptObject->CertificateAttributes(
                Certificate => $Certificate,
                Filename    => $Filename,
            );

            $Self->Print("  Found new SMIME certificates for <yellow>$Contact{Login}</yellow> ...\n");
            $Self->Print("    Added certificate $CertificateAttributes{Fingerprint} (<yellow>$Filename</yellow>)\n")
        }
    }

    $Self->Print("\n<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

sub _GetCurrentData {
    my ( $Self, %Param ) = @_;

    my $CryptObject = $Kernel::OM->Get('Crypt::SMIME');

    # Get all existing certificates.
    my @CertList = $CryptObject->CertificateList();

    my %ListOfCertificates;
    my %EmailsFromCertificates;

    # Check all existing certificates for emails.
    CERTIFICATE:
    for my $Certname (@CertList) {

        my $CertificateString = $CryptObject->CertificateGet(
            Filename => $Certname,
        );

        my %CertificateAttributes = $CryptObject->CertificateAttributes(
            Certificate => $CertificateString,
            Filename    => $Certname,
        );

        # all SMIME certificates must have an Email Attribute
        next CERTIFICATE if !$CertificateAttributes{Email};

        my $ValidEmail = $Kernel::OM->Get('CheckItem')->CheckEmail(
            Address => $CertificateAttributes{Email},
        );

        next CERTIFICATE if !$ValidEmail;

        # Remember certificate (don't need to be added again).
        $ListOfCertificates{$CertificateString} = $CertificateString;

        # Save email for checking for new certificate.
        $EmailsFromCertificates{ $CertificateAttributes{Email} } = 1;
    }

    return ( \%ListOfCertificates, \%EmailsFromCertificates );
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
