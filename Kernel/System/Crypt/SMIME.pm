# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Crypt::SMIME;

use strict;
use warnings;

use MIME::Decoder;

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'FileTemp',
    'Log',
    'Main',
    'Contact',
    'CheckItem',
);

=head1 NAME

Kernel::System::Crypt::SMIME - smime crypt backend lib

=head1 SYNOPSIS

This is a sub module of Kernel::System::Crypt and contains all smime functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    # check if module is enabled
    return 0 if !$Kernel::OM->Get('Config')->Get('SMIME');

    # call init()
    $Self->_Init();

    # check working ENV
    return 0 if $Self->Check();

    return $Self;
}

=item Check()

check if environment is working

    my $Message = $CryptObject->Check();

=cut

sub Check {
    my ( $Self, %Param ) = @_;

    if ( !-e $Self->{Bin} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{Bin}!",
        );
        return "No such $Self->{Bin}!";
    }
    elsif ( !-x $Self->{Bin} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "$Self->{Bin} not executable!",
        );
        return "$Self->{Bin} not executable!";
    }
    elsif ( !-e $Self->{CertPath} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{CertPath}!",
        );
        return "No such $Self->{CertPath}!";
    }
    elsif ( !-d $Self->{CertPath} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{CertPath} directory!",
        );
        return "No such $Self->{CertPath} directory!";
    }
    elsif ( !-w $Self->{CertPath} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "$Self->{CertPath} not writable!",
        );
        return "$Self->{CertPath} not writable!";
    }
    elsif ( !-e $Self->{PrivatePath} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{PrivatePath}!",
        );
        return "No such $Self->{PrivatePath}!";
    }
    elsif ( !-d $Self->{PrivatePath} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{PrivatePath} directory!",
        );
        return "No such $Self->{PrivatePath} directory!";
    }
    elsif ( !-w $Self->{PrivatePath} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "$Self->{PrivatePath} not writable!",
        );
        return "$Self->{PrivatePath} not writable!";
    }

    return;
}

=item Crypt()

crypt a message

    my $Message = $CryptObject->Crypt(
        Message  => $Message,
        Filename => $CertificateFilename,
    );

    my $Message = $CryptObject->Crypt(
        Message     => $Message,
        Hash        => $CertificateHash,
        Fingerprint => $CertificateFingerprint,
    );

=cut

sub Crypt {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Message)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( !$Param{Filename} && !( $Param{Hash} || $Param{Fingerprint} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Message  => "Need Param: Filename or Hash and Fingerprint!",
            Priority => 'error',
        );
        return;
    }

    # get temp file object
    my $FileTempObject = $Kernel::OM->Get('FileTemp');

    my $Certificate = $Self->CertificateGet(%Param);
    my ( $FHCertificate, $CertFile ) = $FileTempObject->TempFile();
    print $FHCertificate $Certificate;
    close $FHCertificate;
    my ( $FH, $PlainFile ) = $FileTempObject->TempFile();
    print $FH $Param{Message};
    close $FH;
    my ( $FHCrypted, $CryptedFile ) = $FileTempObject->TempFile();
    close $FHCrypted;

    my $Options    = "smime -encrypt -binary -des3 -in $PlainFile -out $CryptedFile $CertFile";
    my $LogMessage = $Self->_CleanOutput(qx{$Self->{Cmd} $Options 2>&1});
    if ($LogMessage) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't crypt: $LogMessage!"
        );
        return;
    }

    my $CryptedRef = $Kernel::OM->Get('Main')->FileRead( Location => $CryptedFile );

    return if !$CryptedRef;
    return $$CryptedRef;
}

=item Decrypt()

decrypt a message and returns a hash (Successful, Message, Data)

    my %Message = $CryptObject->Decrypt(
        Message  => $CryptedMessage,
        Filename => $Filename,
    );

    my %Message = $CryptObject->Decrypt(
        Message     => $CryptedMessage,
        Hash        => $Hash,
        Fingerprint => $Fingerprint,
    );

=cut

sub Decrypt {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Message)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( !$Param{Filename} && !( $Param{Hash} || $Param{Fingerprint} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Message  => "Need Param: Filename or Hash and Fingerprint!",
            Priority => 'error',
        );
        return;
    }

    my $Filename    = $Param{Filename} || '';
    my $Certificate = $Self->CertificateGet(%Param);
    my %Attributes  = $Self->CertificateAttributes(
        Certificate => $Certificate,
        Filename    => $Filename,
    );
    my ( $Private, $Secret ) = $Self->PrivateGet(%Attributes);

    # get temp file object
    my $FileTempObject = $Kernel::OM->Get('FileTemp');

    my ( $FHPrivate, $PrivateKeyFile ) = $FileTempObject->TempFile();
    print $FHPrivate $Private;
    close $FHPrivate;
    my ( $FHCertificate, $CertFile ) = $FileTempObject->TempFile();
    print $FHCertificate $Certificate;
    close $FHCertificate;
    my ( $FH, $CryptedFile ) = $FileTempObject->TempFile();
    print $FH $Param{Message};
    close $FH;
    my ( $FHDecrypted, $PlainFile ) = $FileTempObject->TempFile();
    close $FHDecrypted;
    my ( $FHSecret, $SecretFile ) = $FileTempObject->TempFile();
    print $FHSecret $Secret;
    close $FHSecret;

    my $Options = "smime -decrypt -in $CryptedFile -out $PlainFile -recip $CertFile -inkey $PrivateKeyFile"
        . " -passin file:$SecretFile";
    my $LogMessage = qx{$Self->{Cmd} $Options 2>&1};
    unlink $SecretFile;

    if (
        $Param{SearchingNeededKey}
        && $LogMessage =~ m{PKCS7_dataDecode:no recipient matches certificate}
        && $LogMessage =~ m{PKCS7_decrypt:decrypt error}
        )
    {
        return (
            Successful => 0,
            Message    => 'Impossible to decrypt with installed private keys!',
        );
    }

    if ($LogMessage) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't decrypt: $LogMessage!"
        );
        return (
            Successful => 0,
            Message    => $LogMessage,
        );
    }

    my $DecryptedRef = $Kernel::OM->Get('Main')->FileRead( Location => $PlainFile );
    if ( !$DecryptedRef ) {
        return (
            Successful => 0,
            Message    => "OpenSSL: Can't read $PlainFile!",
            Data       => undef,
        );

    }
    return (
        Successful => 1,
        Message    => "OpenSSL: OK",
        Data       => $$DecryptedRef,
    );
}

=item Sign()

sign a message

    my $Sign = $CryptObject->Sign(
        Message  => $Message,
        Filename => $PrivateFilename,
    );
    my $Sign = $CryptObject->Sign(
        Message     => $Message,
        Hash        => $Hash,
        Fingerprint => $Fingerprint,
    );

=cut

sub Sign {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Message)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( !$Param{Filename} && !( $Param{Hash} || $Param{Fingerprint} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Message  => "Need Param: Filename or Hash and Fingerprint!",
            Priority => 'error',
        );
        return;
    }

    my $Certificate = $Self->CertificateGet(%Param);
    my %Attributes  = $Self->CertificateAttributes(
        Certificate => $Certificate,
        Filename    => $Param{Filename}
    );
    my ( $Private, $Secret ) = $Self->PrivateGet(%Attributes);

    # get temp file object
    my $FileTempObject = $Kernel::OM->Get('FileTemp');

    my ( $FH, $PlainFile ) = $FileTempObject->TempFile();
    print $FH $Param{Message};
    close $FH;
    my ( $FHPrivate, $PrivateKeyFile ) = $FileTempObject->TempFile();
    print $FHPrivate $Private;
    close $FHPrivate;
    my ( $FHCertificate, $CertFile ) = $FileTempObject->TempFile();
    print $FHCertificate $Certificate;
    close $FHCertificate;
    my ( $FHSign, $SignFile ) = $FileTempObject->TempFile();
    close $FHSign;
    my ( $FHSecret, $SecretFile ) = $FileTempObject->TempFile();
    print $FHSecret $Secret;
    close $FHSecret;

    my $Options = "smime -sign -in $PlainFile -out $SignFile -signer $CertFile -inkey $PrivateKeyFile"
        . " -text -binary -passin file:$SecretFile";

    my $LogMessage = $Self->_CleanOutput(qx{$Self->{Cmd} $Options 2>&1});
    unlink $SecretFile;
    if ($LogMessage) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't sign: $LogMessage! (Command: $Options)"
        );
        return;
    }

    my $SignedRef = $Kernel::OM->Get('Main')->FileRead( Location => $SignFile );

    return if !$SignedRef;
    return $$SignedRef;

}

=item Verify()

verify a message with signature and returns a hash (Successful, Message, Signers, SignerCertificate)

    my %Data = $CryptObject->Verify(
        Message => $Message,
        CACert  => $PathtoCACert,                   # the certificates autority that endorse a self
                                                    # signed certificate
    );

returns:

    %Data = (
        SignatureFound    => 1,                     # or 0 if no signature was found
        Successful        => 1,                     # or 0 if the verification process failed
        Message           => $Message,              # short version of the verification output
        MessageLong       => $MessageLong,          # full verification output
        Signers           => [                      # optional, array reference to all signers
            'someone@company.com',                  #    addresses
        ],
        SignerCertificate => $SignerCertificate,    # the certificate that signs the message
        Content           => $Content,              # the message content
    );

=cut

sub Verify {
    my ( $Self, %Param ) = @_;

    my %Return;
    my $Message     = '';
    my $MessageLong = '';
    my $UsedKey     = '';

    # check needed stuff
    if ( !$Param{Message} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Message!"
        );
        return;
    }

    # get temp file object
    my $FileTempObject = $Kernel::OM->Get('FileTemp');

    my ( $FH, $SignedFile ) = $FileTempObject->TempFile();
    print $FH $Param{Message};
    close $FH;
    my ( $FHOutput, $VerifiedFile ) = $FileTempObject->TempFile();
    close $FHOutput;
    my ( $FHSigner, $SignerFile ) = $FileTempObject->TempFile();
    close $FHSigner;

    # path to the cert, when self signed certs
    # specially for openssl 1.0
    my $CertificateOption = '';
    if ( $Param{CACert} ) {
        $CertificateOption = "-CAfile $Param{CACert}";
    }

    my $Options = "smime -verify -in $SignedFile -out $VerifiedFile -signer $SignerFile "
        . "-CApath $Self->{CertPath} $CertificateOption $SignedFile";

    my @LogLines = qx{$Self->{Cmd} $Options 2>&1};

    for my $LogLine (@LogLines) {
        $MessageLong .= $LogLine;
        if ( $LogLine =~ /^\d.*:(.+?):.+?:.+?:$/ || $LogLine =~ /^\d.*:(.+?)$/ ) {
            $Message .= ";$1";
        }
        else {
            $Message .= $LogLine;
        }
    }

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    my $SignerCertRef    = $MainObject->FileRead( Location => $SignerFile );
    my $SignedContentRef = $MainObject->FileRead( Location => $VerifiedFile );

    # return message
    if ( $Message =~ /Verification successful/i ) {

        # Determine email address(es) from attributes of signer certificate.
        my %SignerCertAttributes;
        $Self->_FetchAttributesFromCert( $SignerFile, \%SignerCertAttributes );
        my @SignersArray = split( ', ', $SignerCertAttributes{Email} );

        # Include additional certificate attributes in the message:
        #   - signer(s) email address(es)
        #   - certificate hash
        #   - certificate fingerprint
        #   Please see bug#12284 for more information.
        my $MessageSigner = join( ', ', @SignersArray ) . ' : '
            . $SignerCertAttributes{Hash} . ' : '
            . $SignerCertAttributes{Fingerprint};

        %Return = (
            SignatureFound    => 1,
            Successful        => 1,
            Message           => 'OpenSSL: ' . $Message . ' (' . $MessageSigner . ')',
            MessageLong       => 'OpenSSL: ' . $MessageLong . ' (' . $MessageSigner . ')',
            Signers           => [@SignersArray],
            SignerCertificate => $$SignerCertRef,
            Content           => $$SignedContentRef,
        );
    }
    elsif ( $Message =~ /self signed certificate/i ) {
        %Return = (
            SignatureFound => 1,
            Successful     => 0,
            Message =>
                'OpenSSL: self signed certificate, to use it send the \'Certificate\' parameter : '
                . $Message,
            MessageLong =>
                'OpenSSL: self signed certificate, to use it send the \'Certificate\' parameter : '
                . $MessageLong,
            SignerCertificate => $$SignerCertRef,
            Content           => $$SignedContentRef,
        );
    }

    # digest failure means that the content of the email does not match witht he signature
    elsif ( $Message =~ m{digest failure}i ) {
        %Return = (
            SignatureFound => 1,
            Successful     => 0,
            Message =>
                'OpenSSL: The signature does not match the message content : ' . $Message,
            MessageLong =>
                'OpenSSL: The signature does not match the message content : ' . $MessageLong,
            SignerCertificate => $$SignerCertRef,
            Content           => $$SignedContentRef,
        );
    }
    else {
        %Return = (
            SignatureFound => 0,
            Successful     => 0,
            Message        => 'OpenSSL: ' . $Message,
            MessageLong    => 'OpenSSL: ' . $MessageLong,
        );
    }
    return %Return;
}

=item Search()

search a certifcate or an private key

    my @Result = $CryptObject->Search(
        Search => 'some text to search',
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    my @Result = $Self->CertificateSearch(%Param);
    @Result = ( @Result, $Self->PrivateSearch(%Param) );
    return @Result;
}

=item CertificateSearch()

search a local certifcate

    my @Result = $CryptObject->CertificateSearch(
        Search => 'some text to search',
    );

=cut

sub CertificateSearch {
    my ( $Self, %Param ) = @_;

    my $Search = $Param{Search} || '';

    # 1 - Get certificate list
    my @CertList = $Self->CertificateList();

    my @Result;
    if (@CertList) {

        # 2 - For the certs in list get its attributes and add them to @Results
        @Result = $Self->_CheckCertificateList(
            CertificateList => \@CertList,
            Search          => $Search
        );
    }

    # 3 - If there are no results already in the system, then check for the certificate in customer data
    if ( !@Result && $Kernel::OM->Get('Config')->Get('SMIME::FetchFromCustomer') ) {

        # Search and add certificates from Customer data if Result from CertList is empty
        if (
            $Search &&
            $Self->FetchFromCustomer(
                Search => $Search,
            )
            )
        {
            # 4 - if found, get its details and add them to the @Results
            @CertList = $Self->CertificateList();
            if (@CertList) {
                @Result = $Self->_CheckCertificateList(
                    CertificateList => \@CertList,
                    Search          => $Search
                );
            }
        }
    }

    return @Result;
}

sub _CheckCertificateList {
    my ( $Self, %Param ) = @_;

    my @CertList = @{ $Param{CertificateList} };
    my $Search = $Param{Search} || '';

    my @Result;

    for my $Filename (@CertList) {
        my $Certificate = $Self->CertificateGet( Filename => $Filename );
        my %Attributes = $Self->CertificateAttributes(
            Certificate => $Certificate,
            Filename    => $Filename,
        );
        my $Hit = 0;
        if ($Search) {
            ATTRIBUTE:
            for my $Attribute ( sort keys %Attributes ) {
                if ( $Attributes{$Attribute} =~ m{\Q$Search\E}ixms ) {
                    $Hit = 1;
                    last ATTRIBUTE;
                }
            }
        }
        else {
            $Hit = 1;
        }

        $Attributes{Filename} = $Filename;

        if ($Hit) {
            push @Result, \%Attributes;
        }
    }

    return @Result;
}

=item FetchFromCustomer()

add certificates from ContactAttributes to local certificates
returns an array of filenames of added certificates

    my @Result = $CryptObject->FetchFromCustomer(
        Search => $SearchEmailAddress,
    );

Returns:

    @Result = ( '6e620dcc.0', '8096d0a9.0', 'c01cdfa2.0' );

=cut

sub FetchFromCustomer {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!"
        );
        return;
    }

    # Check customer users for userSMIMECertificate
    my $ContactObject = $Kernel::OM->Get('Contact');
    my %Contacts;
    if ( $Param{Search} ) {

        my $ValidEmail = $Kernel::OM->Get('CheckItem')->CheckEmail(
            Address => $Param{Search},
        );

        # If valid email address, only do a PostMasterSearch
        if ($ValidEmail) {
            %Contacts = $ContactObject->ContactSearch(
                PostMasterSearch => $Param{Search},
            );
        }
    }

    my @CertFileList;

    # Check found Contacts
    for my $ContactID ( sort keys %Contacts ) {
        my %Contact = $ContactObject->ContactGet(
            ID => $ContactID,
        );

        # Add Certificate if available
        if ( $Contact{UserSMIMECertificate} ) {

            # if don't add, maybe in UnitTests
            return @CertFileList if $Param{DontAdd};

            # Convert certificate to the correct format (pk7, pk12, pem, der)
            my $Cert = $Self->ConvertCertFormat(
                String => $Contact{UserSMIMECertificate},
            );
            my %Result = $Self->CertificateAdd(
                Certificate => $Cert,
            );
            if ( $Result{Successful} && $Result{Successful} == 1 ) {
                push @CertFileList, $Result{Filename};
            }
        }
    }

    return @CertFileList;
}

=item ConvertCertFormat()

Convert certificate strings into importable PEM format.

    my $Result = $CryptObject->ConvertCertFormat(
        String     => $CertificationString,
        Passphrase => Password for PFX (optional)
    );

Returns:
    $Result =
    "-----BEGIN CERTIFICATE-----
    MIIEXjCCA0agAwIBAgIJAPIBQyBe/HbpMA0GCSqGSIb3DQEBBQUAMHwxCzAJBgNV
    ...
    nj2wbQO4KjM12YLUuvahk5se
    -----END CERTIFICATE-----
    ";

=cut

sub ConvertCertFormat {
    my ( $Self, %Param ) = @_;

    if ( !$Param{String} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need String!"
        );
        return;
    }
    my $String = $Param{String};
    my $PassPhrase = $Param{Passphrase} // '';

    my $FileTempObject = $Kernel::OM->Get('FileTemp');

    # Create original certificate file.
    my ( $FileHandle, $TmpCertificate ) = $FileTempObject->TempFile();
    print $FileHandle $String;
    close $FileHandle;

    # For PEM format no conversion needed.
    my $Options   = "x509 -in $TmpCertificate -noout";
    my $ReadError = $Self->_CleanOutput(qx{$Self->{Cmd} $Options 2>&1});

    return $String if !$ReadError;

    # Create empty file (to save the converted certificate).
    my ( $FH, $CertFile ) = $FileTempObject->TempFile(
        Suffix => '.pem',
    );
    close $FH;

    my %OptionsLookup = (
        DER => {
            Read    => "x509 -inform der -in $TmpCertificate -noout",
            Convert => "x509 -inform der -in $TmpCertificate -out $CertFile",
        },
        P7B => {
            Read    => "pkcs7 -in $TmpCertificate -noout",
            Convert => "pkcs7 -in $TmpCertificate -print_certs -out $CertFile",
        },
        PFX => {
            Read => "pkcs12 -in $TmpCertificate -noout -nomacver -passin pass:'$PassPhrase'",
            Convert =>
                "pkcs12 -in $TmpCertificate -out $CertFile -nomacver -clcerts -nokeys -passin pass:'$PassPhrase'",
        },
    );

    # Determine the format of the file using OpenSSL.
    my $DetectedFormat;
    FORMAT:
    for my $Format ( sort keys %OptionsLookup ) {

        # Read the file on each format, if there is any output it means it could not be read.
        next FORMAT if $Self->_CleanOutput(qx{$Self->{Cmd} $OptionsLookup{$Format}->{Read} 2>&1});

        $DetectedFormat = $Format;
        last FORMAT;
    }

    if ( !$DetectedFormat ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Certificate could not be read, PassPhrase is invalid or file is corrupted!",
        );
        return;
    }

    # Convert certificate to PEM.
    my $ConvertError = $Self->_CleanOutput(qx{$Self->{Cmd} $OptionsLookup{$DetectedFormat}->{Convert} 2>&1});

    if ($ConvertError) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't convert certificate from $DetectedFormat to PEM: $ConvertError",
        );

        return;
    }

    # Read converted certificate.
    my $CertFileRefPEM = $Kernel::OM->Get('Main')->FileRead(
        Location => $CertFile,
    );

    return ${$CertFileRefPEM};
}

=item CertificateAdd()

add a certificate to local certificates
returns result message and new certificate filename

    my %Result = $CryptObject->CertificateAdd(
        Certificate => $CertificateString,
    );

=cut

sub CertificateAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Certificate} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Certificate!'
        );
        return;
    }
    my %Attributes = $Self->CertificateAttributes(
        Certificate => $Param{Certificate},
    );
    my %Result;

    if ( !$Attributes{Hash} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Can\'t add invalid certificate!'
        );
        %Result = (
            Successful => 0,
            Message    => 'Can\'t add invalid certificate!',
        );
        return %Result;
    }

    # search for certs with same hash
    my @Result = $Self->CertificateSearch(
        Search => $Attributes{Hash},
    );

    # does the cert already exists?
    for my $CertResult (@Result) {
        if ( $Attributes{Fingerprint} eq $CertResult->{Fingerprint} ) {
            %Result = (
                Successful => 0,
                Message    => 'Certificate already installed!',
            );
            return %Result;
        }
    }

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    # look for an available filename
    FILENAME:
    for my $Count ( 0 .. 9 ) {
        if ( -e "$Self->{CertPath}/$Attributes{Hash}.$Count" ) {
            next FILENAME;
        }

        my $File = "$Self->{CertPath}/$Attributes{Hash}.$Count";
        ## no critic
        if ( open( my $OUT, '>', $File ) ) {
            ## use critic
            print $OUT $Param{Certificate};
            close($OUT);
            %Result = (
                Successful => 1,
                Message    => 'Certificate uploaded',
                Filename   => "$Attributes{Hash}.$Count",
            );

            # delete cache
            $CacheObject->CleanUp(
                Type => 'SMIME_Cert',
            );
            $CacheObject->CleanUp(
                Type => 'SMIME_Private',
            );

            return %Result;
        }

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't write $File: $!!"
        );
        %Result = (
            Successful => 0,
            Message    => "Can't write $File: $!!",
        );
        return %Result;
    }

    %Result = (
        Successful => 0,
        Message    => "No more available filenames for certificate hash:$Attributes{Hash}!",
    );
    return %Result;
}

=item CertificateGet()

get a local certificate

    my $Certificate = $CryptObject->CertificateGet(
        Filename => $CertificateFilename,
    );

    my $Certificate = $CryptObject->CertificateGet(
        Fingerprint => $Fingerprint,
        Hash        => $Hash,
    );

=cut

sub CertificateGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Filename} && !( $Param{Fingerprint} && $Param{Hash} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename or Fingerprint and Hash!'
        );
        return;
    }

    if ( !$Param{Filename} && ( $Param{Fingerprint} && $Param{Hash} ) ) {
        $Param{Filename} = $Self->_CertificateFilename(%Param);
        return if !$Param{Filename};
    }

    my $File = "$Self->{CertPath}/$Param{Filename}";
    my $CertificateRef = $Kernel::OM->Get('Main')->FileRead( Location => $File );

    return if !$CertificateRef;
    return $$CertificateRef;
}

=item CertificateRemove()

remove a local certificate

    $CryptObject->CertificateRemove(
        Filename => $CertificateHash,
    );

    $CryptObject->CertificateRemove(
        Hash        => $CertificateHash,
        Fingerprint => $CertificateHash,
    );

=cut

sub CertificateRemove {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Filename} && !( $Param{Hash} && $Param{Fingerprint} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename or Hash and Fingerprint!'
        );
        return;
    }

    if ( !$Param{Filename} && $Param{Hash} && $Param{Fingerprint} ) {
        $Param{Filename} = $Self->_CertificateFilename(%Param);
        return if !$Param{Filename};
    }

    my %Result;

    # private certificate shouldn't exists if certificate is deleted
    # therefor if exists, first remove private certificate
    # if private delete fails abort certificate removing

    my ($PrivateExists) = $Self->PrivateGet(
        Filename => $Param{Filename},
    );

    if ($PrivateExists) {
        my %PrivateResults = $Self->PrivateRemove(
            Filename => $Param{Filename},
        );
        if ( !$PrivateResults{Successful} ) {
            %Result = (
                Successful => 0,
                Message    => "Delete certificate aborted, $PrivateResults{Message}: $!!",
            );
            return %Result;
        }
    }

    my $Message = "Certificate successfully removed";
    my $Success = 1;

    # remove certificate
    my $Cert = unlink "$Self->{CertPath}/$Param{Filename}";
    if ( !$Cert ) {
        $Message = "Impossible to remove certificate: $Self->{CertPath}/$Param{Filename}: $!!";
        $Success = 0;
    }

    if ($PrivateExists) {
        $Message .= ". Private certificate successfully deleted";
    }

    if ($Success) {

        # get cache object
        my $CacheObject = $Kernel::OM->Get('Cache');

        # delete cache
        $CacheObject->CleanUp(
            Type => 'SMIME_Cert',
        );
        $CacheObject->CleanUp(
            Type => 'SMIME_Private',
        );
    }

    %Result = (
        Successful => $Success,
        Message    => $Message,
    );

    return %Result;
}

=item CertificateList()

get list of local certificates filenames

    my @CertList = $CryptObject->CertificateList();

=cut

sub CertificateList {
    my ( $Self, %Param ) = @_;

    my @CertList;
    my @Filters;
    for my $Number ( 0 .. 9 ) {
        push @Filters, "*.$Number";
    }

    my @List = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => "$Self->{CertPath}",
        Filter    => \@Filters,
    );

    for my $File (@List) {
        $File =~ s{^.*/}{}xms;
        push @CertList, $File;
    }

    return @CertList;
}

=item CertificateAttributes()

get certificate attributes

    my %CertificateAttributes = $CryptObject->CertificateAttributes(
        Certificate => $CertificateString,
        Filename    => '12345.1',              # optional (useful to use cache)
    );

=cut

sub CertificateAttributes {
    my ( $Self, %Param ) = @_;

    my %Attributes;
    if ( !$Param{Certificate} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Certificate!'
        );
        return;
    }

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    my $CacheKey;
    if ( defined $Param{Filename} && $Param{Filename} ) {

        $CacheKey = 'CertAttributes::Filename::' . $Param{Filename};

        # check cache
        my $Cache = $CacheObject->Get(
            Type => 'SMIME_Cert',
            Key  => $CacheKey,
        );

        # return if cache found,
        return %{$Cache} if ref $Cache eq 'HASH';
    }

    # get temp file object
    my $FileTempObject = $Kernel::OM->Get('FileTemp');

    my ( $FH, $Filename ) = $FileTempObject->TempFile();
    print $FH $Param{Certificate};
    close $FH;
    $Self->_FetchAttributesFromCert( $Filename, \%Attributes );
    if ( $Attributes{Hash} ) {
        my ($Private) = $Self->PrivateGet(%Attributes);
        if ($Private) {
            $Attributes{Private} = 'Yes';
        }
        else {
            $Attributes{Private} = 'No';
        }
        $Attributes{Type} = 'cert';
    }

    if ($CacheKey) {

        # set cache
        $CacheObject->Set(
            Type  => 'SMIME_Cert',
            Key   => $CacheKey,
            Value => \%Attributes,
            TTL   => $Self->{CacheTTL},
        );
    }

    return %Attributes;
}

=item CertificateRead()

show a local certificate in plain text

    my $CertificateText = $CryptObject->CertificateRead(
        Filename => $CertificateFilename,
    );

    my $CertificateText = $CryptObject->CertificateRead(
        Fingerprint => $Fingerprint,
        Hash        => $Hash,
    );

=cut

sub CertificateRead {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Filename} && !( $Param{Fingerprint} && $Param{Hash} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename or Fingerprint and Hash!'
        );
        return;
    }

    if ( !$Param{Filename} && ( $Param{Fingerprint} && $Param{Hash} ) ) {
        $Param{Filename} = $Self->_CertificateFilename(%Param);
        return if !$Param{Filename};
    }

    my $File = "$Self->{CertPath}/$Param{Filename}";

    # check if file exists and can be readed
    if ( !-e $File ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Certificate $File does not exist!"
        );
        return;
    }
    if ( !-r $File ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Cannot read certificate $File!"
        );
        return;
    }

    # set options to retrieve certiciate contents
    my $Options = "x509 -in $File -noout -text";

    # get the output string
    my $Output = qx{$Self->{Cmd} $Options 2>&1};

    return $Output;
}

=item PrivateSearch()

returns private keys

    my @Result = $CryptObject->PrivateSearch(
        Search => 'some text to search',
    );

=cut

sub PrivateSearch {
    my ( $Self, %Param ) = @_;

    my $Search = $Param{Search} || '';
    my @Result;
    my @Certificates = $Self->CertificateList();

    for my $File (@Certificates) {
        my $Certificate = $Self->CertificateGet( Filename => $File );
        my %Attributes = $Self->CertificateAttributes(
            Certificate => $Certificate,
            Filename    => $File,
        );

        my $Hit = 0;
        if ($Search) {
            ATTRIBUTE:
            for my $Attribute ( sort keys %Attributes ) {
                if ( $Attributes{$Attribute} =~ m{\Q$Search\E}ixms ) {
                    $Hit = 1;
                    last ATTRIBUTE;
                }
            }
        }
        else {
            $Hit = 1;
        }
        if ( $Hit && $Attributes{Private} && $Attributes{Private} eq 'Yes' ) {
            $Attributes{Type}     = 'key';
            $Attributes{Filename} = $File;
            push @Result, \%Attributes;
        }
    }
    return @Result;
}

=item PrivateAdd()

add private key

    my %Result = $CryptObject->PrivateAdd(
        Private => $PrivateKeyString,
        Secret  => 'Password',
    );

=cut

sub PrivateAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Private Secret)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my %Result;

    # get private attributes
    my %Attributes = $Self->PrivateAttributes(%Param);
    if ( !$Attributes{Modulus} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'No Private Key!'
        );
        %Result = (
            Successful => 0,
            Message    => 'No private key',
        );
        return;
    }

    # get certificate
    my @Certificates = $Self->CertificateSearch( Search => $Attributes{Modulus} );
    if ( !@Certificates ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Certificate of Private Key first -$Attributes{Modulus})!",
        );
        %Result = (
            Successful => 0,
            Message    => "Need Certificate of Private Key first -$Attributes{Modulus})!",
        );
        return %Result;
    }
    elsif ( $#Certificates > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Multiple Certificates with the same Modulus, can\'t add Private Key!',
        );
        %Result = (
            Successful => 0,
            Message    => 'Multiple Certificates with the same Modulus, can\'t add Private Key!',
        );
        return %Result;
    }
    my %CertificateAttributes = $Self->CertificateAttributes(
        Certificate => $Self->CertificateGet( Filename => $Certificates[0]->{Filename} ),
        Filename    => $Certificates[0]->{Filename},
    );
    if ( $CertificateAttributes{Hash} ) {
        my $File = "$Self->{PrivatePath}/$Certificates[0]->{Filename}";
        ## no critic
        if ( open( my $PrivKeyFH, '>', "$File" ) ) {
            ## use critic
            print $PrivKeyFH $Param{Private};
            close $PrivKeyFH;
            open( my $PassFH, '>', "$File.P" );    ## no critic
            print $PassFH $Param{Secret};
            close $PassFH;
            %Result = (
                Successful => 1,
                Message    => 'Private Key uploaded!',
                Filename   => $Certificates[0]->{Filename},
            );

            # get cache object
            my $CacheObject = $Kernel::OM->Get('Cache');

            # delete cache
            $CacheObject->CleanUp(
                Type => 'SMIME_Cert',
            );
            $CacheObject->CleanUp(
                Type => 'SMIME_Private',
            );

            return %Result;
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Can't write $File: $!!"
            );
            %Result = (
                Successful => 0,
                Message    => "Can't write $File: $!!",
            );
            return %Result;
        }
    }

    $Kernel::OM->Get('Log')->Log(
        Priority => 'error',
        Message  => 'Can\'t add invalid private key!'
    );
    %Result = (
        Successful => 0,
        Message    => 'Can\'t add invalid private key!',
    );

    return %Result;
}

=item PrivateGet()

get private key

    my ($PrivateKey, $Secret) = $CryptObject->PrivateGet(
        Filename => $PrivateFilename,
    );

    my ($PrivateKey, $Secret) = $CryptObject->PrivateGet(
        Hash    => $Hash,
        Modulus => $Modulus,
    );

=cut

sub PrivateGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Filename} && !( $Param{Hash} && $Param{Modulus} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename or Hash and Modulus!'
        );
        return;
    }

    if ( !$Param{Filename} && ( $Param{Hash} && $Param{Modulus} ) ) {
        $Param{Filename} = $Self->_PrivateFilename(
            Hash    => $Param{Hash},
            Modulus => $Param{Modulus},
        );
        return if !$Param{Filename};
    }

    my $File = "$Self->{PrivatePath}/$Param{Filename}";

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    my $Private;
    if ( -e $File ) {
        $Private = $MainObject->FileRead( Location => $File );
    }

    return if !$Private;

    # read secret
    $File = "$Self->{PrivatePath}/$Param{Filename}.P";
    my $Secret = $MainObject->FileRead( Location => $File );

    return ( $$Private, $$Secret ) if ( $Private && $Secret );

    return;
}

=item PrivateRemove()

remove private key

    $CryptObject->PrivateRemove(
        Filename => $Filename,
    );

    $CryptObject->PrivateRemove(
        Hash    => $Hash,
        Modulus => $Modulus,
    );

=cut

sub PrivateRemove {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Filename} && !( $Param{Hash} && $Param{Modulus} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Filename or Hash and Modulus!'
        );
        return;
    }

    my %Return;
    if ( !$Param{Filename} && ( $Param{Hash} && $Param{Modulus} ) ) {
        $Param{Filename} = $Self->_PrivateFilename(
            Hash    => $Param{Hash},
            Modulus => $Param{Modulus},
        );
        %Return = (
            Successful => 0,
            Message    => "Filename not found for hash: $Param{Hash} in: $Self->{PrivatePath}, $!!",
        );
        return %Return if !$Param{Filename};
    }

    my $SecretDelete = unlink "$Self->{PrivatePath}/$Param{Filename}.P";

    # abort if secret is not deleted
    if ( !$SecretDelete ) {
        %Return = (
            Successful => 0,
            Message =>
                "Delete private aborted, not possible to delete Secret: $Self->{PrivatePath}/$Param{Filename}.P, $!!",
        );
        return %Return;
    }

    my $PrivateDelete = unlink "$Self->{PrivatePath}/$Param{Filename}";
    if ($PrivateDelete) {

        my $Certificate = $Self->CertificateGet(
            Filename => $Param{Filename},
        );

        # get cert attributes
        my %CertificateAttributes = $Self->CertificateAttributes(
            Certificate => $Certificate,
            Filename    => $Param{Filename},
        );

        %Return = (
            Successful => 1,
            Message    => 'Private key deleted!'
        );

        # get cache object
        my $CacheObject = $Kernel::OM->Get('Cache');

        # delete cache
        $CacheObject->CleanUp(
            Type => 'SMIME_Cert',
        );
        $CacheObject->CleanUp(
            Type => 'SMIME_Private',
        );

        return %Return;
    }

    %Return = (
        Successful => 0,
        Message    => "Impossible to delete key $Param{Filename} $!!"
    );

    return %Return;
}

=item PrivateList()

returns a list of private key hashs

    my @PrivateList = $CryptObject->PrivateList();

=cut

sub PrivateList {
    my ( $Self, %Param ) = @_;

    my @CertList;
    my @Filters;
    for my $Number ( 0 .. 9 ) {
        push @Filters, "*.$Number";
    }

    my @List = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => "$Self->{PrivatePath}",
        Filter    => \@Filters,
    );

    for my $File (@List) {
        $File =~ s{^.*/}{}xms;
        push @CertList, $File;
    }

    return @CertList;

}

=item PrivateAttributes()

returns attributes of private key

    my %Hash = $CryptObject->PrivateAttributes(
        Private  => $PrivateKeyString,
        Secret   => 'Password',
        Filename => '12345.1',              # optional (useful for cache)
    );

=cut

sub PrivateAttributes {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Private Secret)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    my $CacheKey;
    if ( defined $Param{Filename} && $Param{Filename} ) {

        $CacheKey = 'PrivateAttributes::Filename::' . $Param{Filename};

        # check cache
        my $Cache = $CacheObject->Get(
            Type => 'SMIME_Private',
            Key  => $CacheKey,
        );

        # return if cache found,
        return %{$Cache} if ref $Cache eq 'HASH';
    }

    # get temp file object
    my $FileTempObject = $Kernel::OM->Get('FileTemp');

    my %Attributes;
    my %Option = (
        Modulus => '-modulus',
    );
    my ( $FH, $Filename ) = $FileTempObject->TempFile();
    print $FH $Param{Private};
    close $FH;
    my ( $FHSecret, $SecretFile ) = $FileTempObject->TempFile();
    print $FHSecret $Param{Secret};
    close $FHSecret;
    my $Options    = "rsa -in $Filename -noout -modulus -passin file:$SecretFile";
    my $LogMessage = qx{$Self->{Cmd} $Options 2>&1};
    unlink $SecretFile;
    $LogMessage =~ tr{\r\n}{}d;
    $LogMessage =~ s/Modulus=//;
    $Attributes{Modulus} = $LogMessage;
    $Attributes{Type}    = 'P';

    if ($CacheKey) {

        # set cache
        $CacheObject->Set(
            Type  => 'SMIME_Private',
            Key   => $CacheKey,
            Value => \%Attributes,
            TTL   => $Self->{CacheTTL},
        );
    }

    return %Attributes;
}

=item CheckCertPath()

Checks and fixes the private secret files that do not have an index. (Needed because this
changed during the migration from OTRS 3.0 to 3.1.)

Checks and fixed certificates, private keys and secrets files to have a correct name
depending on the current OpenSSL hash algorithm.

    my $Result = $CryptObject->CheckCertPath ();

    a result could be:

    $Result = {
        Success => 1                # or 0 if fails
        Details => $Details         # a readable string log of all activities and errors found
    };

=cut

sub CheckCertPath {
    my ( $Self, %Param ) = @_;

    # normalize private secret file names
    #
    # in otrs 3.0 private secret files are stored in format like 12345678.p, from otrs 3.1 this
    # files must be in a format like 12345678.0.p where .0 could be from 0 to 9 depending on the
    # private key file name.

    my $NormalizeResult = $Self->_NormalizePrivateSecretFiles();

    if ( !$NormalizeResult->{Success} ) {
        return {
            Success => 0,
            Details => $NormalizeResult->{Details}
                . "\n<red>Error in Normalize Private Secret Files.</red>\n\n",
            ShortDetails => "<red>Error in Normalize Private Secret Files.</red>\n\n",
        };
    }

    return {
        Success => 1,
        Details => $NormalizeResult->{Details},
    };
}

=begin Internal:

=cut

sub _Init {
    my ( $Self, %Param ) = @_;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    $Self->{Bin}         = $ConfigObject->Get('SMIME::Bin') || '/usr/bin/openssl';
    $Self->{CertPath}    = $ConfigObject->Get('SMIME::CertPath');
    $Self->{PrivatePath} = $ConfigObject->Get('SMIME::PrivatePath');

    # get the cache TTL (in seconds)
    $Self->{CacheTTL} = int( $ConfigObject->Get('SMIME::CacheTTL') || 86400 );

    if ( $^O =~ m{mswin}i ) {

        # take care to deal properly with paths containing whitespace
        $Self->{Cmd} = qq{"$Self->{Bin}"};
    }
    else {

        # make sure that we are getting POSIX (i.e. english) messages from openssl
        $Self->{Cmd} = "LC_MESSAGES=POSIX $Self->{Bin}";
    }

    # ensure that there is a random state file that we can write to (otherwise openssl will bail)
    $ENV{RANDFILE} = $ConfigObject->Get('TempDir') . '/.rnd';    ## no critic

    # prepend RANDFILE declaration to openssl cmd
    $Self->{Cmd} = "HOME=" . $ConfigObject->Get('Home') . " RANDFILE=$ENV{RANDFILE} $Self->{Cmd}";

    # get the openssl version string, e.g. OpenSSL 0.9.8e 23 Feb 2007
    $Self->{OpenSSLVersionString} = qx{$Self->{Cmd} version};

    # get the openssl major version, e.g. 1 for version 1.0.0
    if ( $Self->{OpenSSLVersionString} =~ m{ \A (?: OpenSSL )? \s* ( \d )  }xmsi ) {
        $Self->{OpenSSLMajorVersion} = $1;
    }

    return $Self;
}

sub _FetchAttributesFromCert {
    my ( $Self, $Filename, $AttributesRef ) = @_;

    # The hash algorithm used in the -subject_hash and -issuer_hash options before OpenSSL 1.0.0
    # was based on the deprecated MD5 algorithm and the encoding of the distinguished name.
    # In OpenSSL 1.0.0 and later it is based on a canonical version of the DN using SHA1.
    #
    # The older algorithm can be used with -subject_hash_old attribute, but doing this will might
    # cause for openssl 1.0.0 that the -CApath option (e.g. in verify function) will not find the
    # CA files in the path, due that openssl search for the file names based in current algorithm
    #
    # -subject_hash_old was used in otrs in the past (to keep the old hashes style, and perhaps to
    # ease a migration between openssl versions ) but now is not recommended anymore.

    # testing new solution
    my $OptionString = ' '
        . '-subject_hash '
        . '-issuer '
        . '-fingerprint -sha1 '
        . '-serial '
        . '-subject '
        . '-startdate '
        . '-enddate '
        . '-email '
        . '-modulus '
        . ' ';

    # call all attributes at same time
    my $Options = "x509 -in $Filename -noout $OptionString";

    # get the output string
    my $Output = qx{$Self->{Cmd} $Options 2>&1};

    # filters
    my %Filters = (
        Hash        => '(\w{8})',
        Issuer      => 'issuer=\s*(.*)',
        Fingerprint => 'SHA1\sFingerprint=(.*)',
        Serial      => 'serial=(.*)',
        Subject     => 'subject=\s*/(.*)',
        StartDate   => 'notBefore=(.*)',
        EndDate     => 'notAfter=(.*)',
        Email       => '([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4})',
        Modulus     => 'Modulus=(.*)',
    );

    # parse output string
    my @Attributes = split( /\n/, $Output );
    for my $Line (@Attributes) {

        # clean end spaces
        $Line =~ tr{\r\n}{}d;

        # look for every attribute by filter
        FILTER:
        for my $Filter ( sort keys %Filters ) {
            next FILTER if $Line !~ m{ \A $Filters{$Filter} \z }xms;
            my $Match = $1 || '';

            # email filter is allowed to match multiple times for alternate names (SubjectAltName)
            if ( $Filter eq 'Email' ) {
                push @{ $AttributesRef->{$Filter} }, $Match;
            }

            # all other filters are one-time matches, so we exclude the filter from all remaining lines (performance)
            else {
                $AttributesRef->{$Filter} = $Match;
                delete $Filters{$Filter};
            }

            last FILTER;
        }
    }

    # prepare attributes data for use
    if ( ref $AttributesRef->{Email} eq 'ARRAY' ) {
        $AttributesRef->{Email} = join ', ', sort @{ $AttributesRef->{Email} };
    }
    if ( $AttributesRef->{Issuer} ) {
        $AttributesRef->{Issuer} =~ s{=}{= }xmsg;
    }
    if ( $AttributesRef->{Subject} ) {
        $AttributesRef->{Subject} =~ s{\/}{ }xmsg;
        $AttributesRef->{Subject} =~ s{=}{= }xmsg;
    }

    my %Month = (
        Jan => '01',
        Feb => '02',
        Mar => '03',
        Apr => '04',
        May => '05',
        Jun => '06',
        Jul => '07',
        Aug => '08',
        Sep => '09',
        Oct => '10',
        Nov => '11',
        Dec => '12',
    );

    for my $DateType ( 'StartDate', 'EndDate' ) {
        if (
            $AttributesRef->{$DateType}
            &&
            $AttributesRef->{$DateType} =~ /(.+?)\s(.+?)\s(\d\d:\d\d:\d\d)\s(\d\d\d\d)/
            )
        {
            my $Day   = $2;
            my $Month = '';
            my $Year  = $4;

            if ( $Day < 10 ) {
                $Day = "0" . int($Day);
            }

            MONTH_KEY:
            for my $MonthKey ( sort keys %Month ) {
                if ( $AttributesRef->{$DateType} =~ /$MonthKey/i ) {
                    $Month = $Month{$MonthKey};
                    last MONTH_KEY;
                }
            }
            $AttributesRef->{"Short$DateType"} = "$Year-$Month-$Day";
        }
    }
    return 1;
}

sub _CleanOutput {
    my ( $Self, $Output ) = @_;

    # remove spurious warnings that appear on Windows
    if ( $^O =~ m{mswin}i ) {
        $Output =~ s{Loading 'screen' into random state - done\r?\n}{}igms;
    }

    return $Output;
}

sub _CertificateFilename {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Fingerprint Hash)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get all certificates with hash name
    my @CertList = $Kernel::OM->Get('Main')->DirectoryRead(
        Directory => $Self->{CertPath},
        Filter    => "$Param{Hash}.*",
    );

    # open every file, get attributes and compare fingerprint
    for my $CertFile (@CertList) {
        my %Attributes;
        $Self->_FetchAttributesFromCert( $CertFile, \%Attributes );

        # exit and return on first finger print found
        if ( $Attributes{Fingerprint} && $Attributes{Fingerprint} eq $Param{Fingerprint} ) {
            $CertFile =~ s{^.*/}{}xms;
            return $CertFile;
        }
    }

    return;
}

sub _PrivateFilename {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Hash Modulus)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    # get all certificates with hash name
    my @CertList = $MainObject->DirectoryRead(
        Directory => $Self->{PrivatePath},
        Filter    => $Param{Hash} . '\.*',
    );

    # open every file, get attributes and compare modulus
    CERTFILE:
    for my $CertFile (@CertList) {
        my %Attributes;
        next CERTFILE if $CertFile =~ m{\.P}xms;

        # remove the path and get only the filename (for cache)
        my $CertFilename = $CertFile;
        $CertFilename =~ s{^.*/}{}xms;

        # open secret
        my $Private = $MainObject->FileRead(
            Location => $CertFile,
        );
        my $Secret = $MainObject->FileRead(
            Location => $CertFile . '.P',
        );

        %Attributes = $Self->PrivateAttributes(
            Private  => $$Private,
            Secret   => $$Secret,
            Filename => $CertFilename,
        );

        # exit and return on first modulus found
        if ( $Attributes{Modulus} && $Attributes{Modulus} eq $Param{Modulus} ) {
            return $CertFilename;
        }
    }
    return;
}

sub _NormalizePrivateSecretFiles {
    my ( $Self, %Param ) = @_;

    # get main object
    my $MainObject = $Kernel::OM->Get('Main');

    # get all files that ends with .P from the private directory
    my @List = $MainObject->DirectoryRead(
        Directory => "$Self->{PrivatePath}",
        Filter    => '*.P',
    );

    my $Details = "<yellow>Normalizing private secret files...</yellow>\n"
        . "  - Private path: $Self->{PrivatePath}\n\n";

    # stop if there are no private secrets stored
    if ( scalar @List == 0 ) {
        $Details .= "  No private secret files found, nothing to do!... <green>OK</green>\n";

        return {
            Success => 1,
            Details => $Details,
        };
    }

    my @WrongPrivateSecretList;

    # exclude the private secret files that has a correct name format
    FILENAME:
    for my $File (@List) {
        $File =~ s{^.*/}{}xms;
        next FILENAME if ( $File =~ m{.+ \. \d \. P}smxi );
        push @WrongPrivateSecretList, $File;
    }

    # stop if the are no wrong files to normalize
    if ( scalar @WrongPrivateSecretList == 0 ) {
        $Details .= "  Stored private secrets found, but they are all correct, nothing to do... <green>OK</green>\n";

        return {
            Success => 1,
            Details => $Details,
        };
    }

    # check if the file with the correct name already exist in the system
    FILENAME:
    for my $File (@WrongPrivateSecretList) {

        # build the correct file name
        $File =~ m{(.+) \. P}smxi;
        my $Hash = $1;

        my $CorrectFile;
        my @UsedPrivateSecretFiles;

        KEYFILENAME:
        for my $Count ( 0 .. 9 ) {
            my $PrivateKeyFileLocation = "$Self->{PrivatePath}/$Hash.$Count";

            # get private keys
            if ( -e $PrivateKeyFileLocation ) {
                my $PrivateSecretFileLocation = $PrivateKeyFileLocation . '.P';

                # check if private secret already exists
                if ( !-e $PrivateSecretFileLocation ) {

                    # use first available
                    $CorrectFile = "$Hash.$Count.P";
                    last KEYFILENAME;
                }
                else {
                    push @UsedPrivateSecretFiles, "$Hash.$Count.P";
                    next KEYFILENAME;
                }
            }
        }

        # if there are no keys for the private secret, the file could not be renamed
        if ( !$CorrectFile && scalar @UsedPrivateSecretFiles == 0 ) {
            $Details .= "  Can't rename private secret file $File, because there is no"
                . " private key file for this private secret... <red>Warning</red>\n";
            next FILENAME;
        }

        my $WrongFileLocation = "$Self->{PrivatePath}/$File";

        # if an available file name was found
        if ($CorrectFile) {
            my $CorrectFileLocation = "$Self->{PrivatePath}/$CorrectFile";
            if ( !rename $WrongFileLocation, $CorrectFileLocation ) {
                my $Message = "Could not rename private secret file $WrongFileLocation to $CorrectFileLocation!";
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => $Message,
                );

                $Details .= "  $Message\n";

                return {
                    Success => 0,
                    Details => $Details,
                };
            }

            $Details .= "  Renamed private secret file $File to $CorrectFile ... <green>OK</green>\n";
            next FILENAME;
        }

        # otherwise try to find if any of the used files has the same content
        $Details .= "  Can't rename private secret file: $File\nAll private key files for hash"
            . " $Hash has already a correct private secret filename associated!\n";

        # get the contents of the wrong private secret file
        my $WrongFileContent = $MainObject->FileRead(
            Location => $WrongFileLocation,
            Result   => 'SCALAR',
        );

        # loop over the found private secret files for the same private key hash
        for my $PrivateSecretFile (@UsedPrivateSecretFiles) {
            my $PrivateSecretFileLocation = "$Self->{PrivatePath}/$PrivateSecretFile";

            # check if the file contents are the same
            my $PrivateSecretFileContent = $MainObject->FileRead(
                Location => $PrivateSecretFileLocation,
                Result   => 'SCALAR',
            );

            # safe to delete wrong file if contents are are identical
            if ( ${$WrongFileContent} eq ${$PrivateSecretFileContent} ) {

                $Details
                    .= "  The content of files $File and $PrivateSecretFile is the same, it is safe to remove $File\n";

                $Details .= "    Remove private secret file $WrongFileLocation from the file system...";

                # remove file
                my $Success = $MainObject->FileDelete(
                    Location => $WrongFileLocation,
                );

                # return error if file was not deleted
                if ( !$Success ) {
                    my $Message = "Could not remove private secret file $WrongFileLocation from the file system!";
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => $Message,
                    );

                    $Details .= " <red>Failed</red>\n";

                    return {
                        Success => 0,
                        Details => $Details,
                    };
                }

                # continue to next wrong private secret file
                $Details .= " <green>OK</green>\n";

                next FILENAME;
            }

            # otherwise just log that the contents are different, do not delete file
            $Details .= "  The content of files $File and $PrivateSecretFile is different\n";
        }

        # all private secret files has different content, just log this as a waring and continue to
        # the next wrong private secret file
        $Details . "  The private secret file $File has information not stored in any other"
            . " private secret file for hash $Hash\n"
            . "    The file will not be deleted... <red>Warning</red>\n";
        next FILENAME;
    }

    return {
        Success => 1,
        Details => $Details,
    };
}

1;

=end Internal:

=cut





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
