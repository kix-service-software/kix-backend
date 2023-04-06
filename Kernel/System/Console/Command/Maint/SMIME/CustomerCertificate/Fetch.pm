# --
# Modified version of the work: Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::SMIME::CustomerCertificate::Fetch;

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

    $Self->Description('Fetch SMIME certificates from customer backends.');
    $Self->AddOption(
        Name => 'add-all',
        Description =>
            "Add all found certificates from the customer backend into the system within the predefined search limit in customer backed (This operation might take some time).",
        Required   => 0,
        HasValue   => 0,
        ValueRegex => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'email',
        Description => "Only gets a certificate for the specified email address.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Fetching customer SMIME certificates...</yellow>\n");

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

    # Get certificate for just one customer.
    if ( $Self->GetOption('email') ) {
        my $EmailAddress = $Self->GetOption('email');

        my $ValidEmail = $Kernel::OM->Get('CheckItem')->CheckEmail(
            Address => $EmailAddress,
        );
        if ( !$ValidEmail ) {
            $Self->PrintError("  $EmailAddress NOT valid ($ValidEmail)\n");
            return $Self->ExitCodeError();
        }

        my @Files = $CryptObject->FetchFromCustomer(
            Search => $EmailAddress,
        );

        if ( !@Files ) {
            $Self->Print("  No new certificates found.\n");
        }

        for my $Filename (@Files) {
            my $Certificate = $CryptObject->CertificateGet(
                Filename => $Filename,
            );

            my %CertificateAttributes = $CryptObject->CertificateAttributes(
                Certificate => $Certificate,
                Filename    => $Filename,
            );

            $Self->Print("  Added certificate $CertificateAttributes{Fingerprint} (<yellow>$Filename</yellow>)\n")
        }

        $Self->Print("\n<green>Done.</green>\n");
        return $Self->ExitCodeOk();
    }

    my ( $ListOfCertificates, $EmailsFromCertificates ) = $Self->_GetCurrentData();

    my $ContactObject = $Kernel::OM->Get('Contact');

    # Check customer user for UserSMIMECertificate property
    my %Contacts = $ContactObject->ContactSearch(
        Email => '*',
    );

    CONTACT:
    for my $ContactID ( sort keys %Contacts ) {
        my %Contact = $ContactObject->ContactGet(
            ID => $ContactID,
        );

        next CONTACT if !$Contact{UserSMIMECertificate};

        $Self->Print("  Searching SMIME certificates for <yellow>$Contacts{$ContactID}</yellow>...");

        if ( $ListOfCertificates->{ $Contact{UserSMIMECertificate} } ) {
            $Self->Print(" Already added\n");
            next CONTACT;
        }
        else {

            my @Files = $CryptObject->FetchFromCustomer(
                Search => $Contact{Email},
            );

            for my $Filename (@Files) {
                my $Certificate = $CryptObject->CertificateGet(
                    Filename => $Filename,
                );

                my %CertificateAttributes = $CryptObject->CertificateAttributes(
                    Certificate => $Certificate,
                    Filename    => $Filename,
                );
                $Self->Print(
                    "\n    Added certificate $CertificateAttributes{Fingerprint} (<yellow>$Filename</yellow>)\n"
                );
            }
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
