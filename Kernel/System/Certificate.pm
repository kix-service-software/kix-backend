# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Certificate;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Cache
    ClientNotification
    Config
    FileTemp
    Log
    Main
    ObjectSearch
    VirtualFS
);

use Email::Address::XS;
use MIME::Base64 qw();
use MIME::Parser;
use Kernel::System::VariableCheck qw(:all);

=head1 NAME

Kernel::System::Certificate - Certificate backend lib

=head1 SYNOPSIS

This is a sub module of Kernel::System::Certificate contains all Certificate functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Kernel::OM->Get('Config')->Get('Certificate::Debug') || 0;

    $Self->{CacheType}   = 'Certificate';
    $Self->{OSCacheType} = 'ObjectSearch_Certificate';
    $Self->{CacheTTL}    = 60 * 60 * 24;

    return 0 if !$Self->_Init();

    return $Self;
}


=item CertificateCreate()

create a local certificate

    my $CertificateID = $CertificateObject->CertificateCreate(
        File => {                                   # required
            Content     => 'some base64 content'
            Filesize    => '6059'                   # optional
            ContentType => 'application/pcks7-mime'
            Filename    => 'some name'
        },
        Type       => 'Cert'            # required
        Passphrase => 'some secret'     # required, if type Private
        CType      => 'SMIME'           # required
    );

    return certificate id

=cut

sub CertificateCreate {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckCertificate(%Param);

    my $Attributes = $Self->_GetCertificateAttributes( %Param );

    return if !$Attributes;

    if ( $Param{Type} eq 'Private' ) {
        # checks whether there is a public certificate for the private one
        my $CertID = $Self->CertificateExists(
            %Param,
            Modulus        => $Attributes->{Modulus} || q{},
            HasCertificate => 1
        );

        return if !$CertID;

        my $Certificate = $Self->CertificateGet(
            ID => $CertID
        );

        for my $Key (
            qw(
                Hash CType Serial Subject Issuer
                StartDate EndDate Fingerprint Email
                Varify
            )
        ) {
            next if !$Certificate->{$Key};
            $Attributes->{$Key} = $Certificate->{$Key};
        }
    }

    my $Filename = 'Certificate'
        . q{/}
        . $Param{CType}
        . q{/}
        . $Param{Type}
        . q{/}
        . $Attributes->{Fingerprint};

    # Checks whether a public/private certificate already exists according to the type
    return if $Self->CertificateExists(
        %Param,
        Filename => $Filename
    );

    my %Preferences;
    for my $Key ( sort keys %{$Attributes} ) {
        $Preferences{$Key} = $Attributes->{$Key};
    }

    # add content type to the preferences for serialization
    $Preferences{ContentType} = $Param{File}->{ContentType};

    my $Content = $Param{File}->{Content};

    my $FileID = $Kernel::OM->Get('VirtualFS')->Write(
        Content     => \$Content,
        Filename    => $Filename,
        Mode        => 'binary',
        Preferences => \%Preferences,
        Silent      => $Param{Silent}
    );

    if ( !$FileID ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Certificate could not be create!'
            );
        }
        return;
    }

    return if !$Self->_WriteCertificate(
        Type    => $Preferences{Type},
        Content => $Content,
        ID      => $FileID
    );

    # delete cache
    $Self->_CacheCleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Certificate',
        ObjectID  => $FileID,
    );

    return $FileID;
}

=item CertificateGet()

get a local certificate

    my $Certificate = $CryptObject->CertificateGet(
        ID         => 1          # required
        Include    => 'Content'  # optional, to include the content if needed
        Passphrase => 1          # optional, inlcudes the passphrase
    );

    returns a hashref

    $Certificate = {
        Email           => "selfsigned@example.de",
        FileID          => "4",
        Filename        => "KIX_Cert_4",
        Fingerprint     => "8F:9A:BB:D5:92:2F:54:CB:D6:61:96:A6:67:35:81:64:2A:EC:3F:94",
        Hash            => "791510e5",
        Issuer          => "C =  DE, ST =  Saxony, L =  Example, O =  Example GmbH, CN =  selfsigned, emailAddress =  selfsigned@example.de",
        Modulus         => "9B383D6A49187936214BD3AAF55F9334AA94B42E66BA63021594F056B19E46D21DBFE9868C25AD14C67836E82497DCE5B1F7CB8CF3F253883428EE105E447CA3765BD4D172FB5AF2C3A3A5A6B4FDCA12B5ECC96D7263FB303C48DD8E3D45355D336885D81F0F618CF0D6B3748C7E76B59CD49A6ACDFE9B4DADC65BB1045D8027D416D03520D7F8CB14D05D76D2DECA334811A5747CB5C9632AFDAFFB867D3A9B61775DC8BCE3632AC8E6E247C7F8BACACAE7E6F1B745C8FD0132DF823607D5468A15844BCB643389C50B215D62B8C1B0DBB8F4FB265ED178F0015212494A243124A69F500F72F6DEEF0ACC7FB3196E2DED7BD76A6B743F8B74031A7C3EFA3991421411FA42AFBE8ABE062180BAAC0E9F7CF0E65A8D480DA17BD800935F38A510DF7C87838B014A134DF4371D8C3CA4B2AA93673F3E46698DDB1D2BAF691FB0C68992D96F4F1F83A14D7B9006B609E15FC5D7B68BB7FB1895473E33AF3A113EC85D439026665A277E4AA97C08400CAAD36533C63565670777D2FD77D824089DE74685217236A0DAC0B9066FC274B90A9F8D9F357D8FA08E10A3CB38139881D883DFFADEB6BCA678757155333FB9C9A7523986DEA2539CDE8209E8820480D1E56385333720914BED77BDC1707D3453E9ED24D5BAA81F06EFA0F551C7D58D2DC6BF59D78D222C23D5BC583284515286B48DD5120EF76DE2B6C7F08DA1A94A6A795B",
        Serial          => "0B9444A6464EE36AC4B6BACD1F7FBC786295FB05",
        StartDate       => "2020-06-03 14:41:34",
        EndDate         => "2030-06-01 14:41:34",
        Subject         => "C =  DE, ST =  Saxony, L =  Example, O =  Example GmbH, CN =  selfsigned, emailAddress =  selfsigned@example.de",
        Type            => "Cert"
        Content         => 'some base64 content'
    };

=cut

sub CertificateGet {
    my ( $Self, %Param ) = @_;

    if ( !$Param{ID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Need ID!'
            );
        }
        return;
    }

    my $Mode = 'Preferences';
    if (
        defined $Param{Include}
        && $Param{Include} eq 'Content'
    ) {
        $Mode = 'binary';
    }

    my $CacheKey = 'Certificate::'
        . $Param{ID}
        . q{::}
        . $Mode
        . ($Param{Passphrase} ? q{::Passphrase} : q{});

    # check cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );

    # return if cache found,
    return $Cache if ref $Cache eq 'HASH';

    my %File = $Kernel::OM->Get('VirtualFS')->Read(
        ID       => $Param{ID},
        Mode     => $Mode,
        Silent   => $Param{Silent}
    );

    if ( !%File ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Certificate could not be found!'
            );
        }
        return;
    }

    if (
        !$File{Preferences}->{Type}
        || !$Self->{$File{Preferences}->{Type}}
        || !$Self->{$File{Preferences}->{Type}}->{Path}
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "The file found is not a supported certificate!"
            );
        }
        return;
    }

    my $Filename = 'KIX_'
        . $File{Preferences}->{Type}
        . q{_}
        . $Param{ID};

    my $Certificate = $File{Preferences};
    $Certificate->{FileID}   = $Param{ID};
    $Certificate->{Filename} = $Filename;

    if (
        defined $Param{Include}
        && $Param{Include} eq 'Content'
    ) {
        if ( !$File{Content} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Certificate could load content!'
                );
            }
            return;
        }
        $Certificate->{Content} = ${$File{Content}};
    }
    else {
        # remove unnessary datas
        for my $Key ( qw(Filesize FilesizeRaw) ) {
            delete $Certificate->{$Key};
        }
    }

    if ( !$Param{Passphrase} ) {
        delete $Certificate->{Passphrase};
    }

    # set cache
    if ($CacheKey) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => $CacheKey,
            Value => $Certificate,
            TTL   => $Self->{CacheTTL},
        );
    }

    return $Certificate;
}

=item CertificateDelete()

removes the certificate/private key in the file system and db-storage

    my $Success = $CertificateObject->CertificateDelete(
        ID => 1
    );

=cut

sub CertificateDelete {
    my ( $Self, %Param ) = @_;

    if ( !$Param{ID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need ID!"
            );
        }
        return;
    }

    my %File = $Kernel::OM->Get('VirtualFS')->Read(
        ID     => $Param{ID},
        Silent => $Param{Silent},
        Mode   => 'Preferences'
    );

    if ( !%File ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No certificate found!"
            );
        }
        return;
    }

    if (
        !$File{Preferences}->{Type}
        || !$Self->{$File{Preferences}->{Type}}
        || !$Self->{$File{Preferences}->{Type}}->{Path}
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "The file found is not a supported certificate!"
            );
        }
        return;
    }

    my $Filename = 'KIX_'
        . $File{Preferences}->{Type}
        . q{_}
        . $Param{ID};

    my $Path = $Self->{$File{Preferences}->{Type}}->{Path};
    $Path .= "/$Filename";

    my $Success;
    if ( -e $Path ) {
        $Success = $Kernel::OM->Get('Main')->FileDelete(
            Location        => $Path,
            DisableWarnings => $Param{Silent}
        );

        if ( !$Success ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Couldn't delete certificate!"
                );
            }
            return;
        }
    }

    $Success = $Kernel::OM->Get('VirtualFS')->Delete(
        ID              => $Param{ID},
        DisableWarnings => $Param{Silent}
    );

    if ( !$Success ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Couldn't delete certificate!"
            );
        }
        return;
    }

    # delete cache
    $Self->_CacheCleanUp();

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Certificate',
        ObjectID  => $Param{ID}
    );

    return 1;
}

=item CertificateExists()

Checks whether a certificate/private key already exists, or whether a matching certificate exists for the specified private key.

Checks whether a certificate/private key exists:
    my $Exists = $CertificateObject->CertificateExists(
        Filename => 'Certificate/SMIME/Cert/some fingerprint'  # required, only if want to check the certificate/private key exists
        UserID   => 1,
        Silent   => 1
    );

    Returns 1 if exists

Checks whether a certificate exists for the private key:
    my $CertID = $CertificateObject->CertificateExists(
        HasCertificate => 1,             # required, needed to switch the check method
        Type           => 'Private',     # required
        Modulus        => 'some string', # required, Modulus of the private key to get the certificate with the same modulus
        UserID         => 1,
        Silent         => 1
    );

    Returns the certificate ID, if a certificate was found

=cut

sub CertificateExists {
    my ( $Self,%Param ) = @_;

    if ( $Param{HasCertificate} ) {
        if ( !$Param{Type} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Needed Type!",
                );
            }
            return;
        }

        return 1 if $Param{Type} ne 'Private';

        if ( !$Param{Modulus} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Needed Modulus!",
                );
            }
            return;
        }

        my @CertID = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Certificate',
            UserType   => 'Agent',
            UserID     => $Param{UserID} || 1,
            Result     => 'ARRAY',
            Search     => {
                AND => [
                    {
                        Field    => 'Type',
                        Value    => 'Cert',
                        Operator => 'EQ'
                    },
                    {
                        Field    => 'Modulus',
                        Value    => $Param{Modulus},
                        Operator => 'EQ'
                    }
                ]
            }
        );

        if ( !@CertID ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need Certificate of Private Key first -$Param{Modulus})!",
                );
            }
            return;
        }
        return $CertID[0];
    }
    else {
        if ( !$Param{Filename} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Needed Filename!",
                );
            }
            return;
        }

        my $Exists = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'Certificate',
            UserType   => 'Agent',
            UserID     => $Param{UserID} || 1,
            Result     => 'COUNT',
            Search     => {
                AND => [
                    {
                        Field    => 'Filename',
                        Value    => $Param{Filename},
                        Operator => 'EQ'
                    }
                ]
            }
        );

        if ( $Exists ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'Certificate already exists!'
                );
            }
            return 1;
        }
    }

    return;
}

=item CertificateToFS()

Writes all certificates/private keys stored in the database to the file system

=cut

sub CertificateToFS {
    my ( $Self,%Param ) = @_;

    my $Debug = $Param{Debug} || $Self->{Debug};

    my @Certificates = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Certificate',
        Search     => {
            AND => [
                {
                    Field    => 'CType',
                    Operator => 'EQ',
                    Value    => 'SMIME'
                }
            ]
        },
        Result   => 'ARRAY',
        UserType => 'Agent',
        UserID   => 1
    );

    my $Count = scalar(@Certificates);
    if ( $Debug ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => "CertificateToFS: Found $Count certificate(s)!"
        );
    }

    return 1 if !$Count;

    for my $ID ( @Certificates ) {
        my $Certificate = $Self->CertificateGet(
            ID      => $ID,
            Include => 'Content',
            Silent  => $Debug
        );

        return if ( !IsHashRefWithData($Certificate) );

        return if !$Certificate->{Content};

        return if !$Self->_WriteCertificate(
            Type     => $Certificate->{Type},
            Content  => $Certificate->{Content},
            ID       => $ID,
            NoDelete => 1,
            Silent   => $Debug
        );

    }

    return 1;
}

sub Decrypt {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(Content Type) ) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Needed $Needed!"
                );
            }
            return;
        }
    }

    if ( $Param{Type} eq 'Email' ) {

        my $ContentType = $Self->_CheckContentType(
            %Param
        );
        return if !$ContentType;

        if (
            $ContentType =~ /application\/(x-pkcs7|pkcs7)-mime/i
            && $ContentType !~ /signed/i
        ) {
            # require EmailParser
            if ( !$Kernel::OM->Get('Main')->Require( 'Kernel::System::EmailParser' ) ) {
                return {
                    Flags   => [
                        {
                            Key   => 'SMIMEEncrypted',
                            Value => 1
                        },
                        {
                            Key   => 'SMIMEEncryptedError',
                            Value => 'Internal error!'
                        }
                    ],
                    Content    => $Param{Content},
                    Successful => 0
                };
            }

            my @Content = @{$Param{Content}};
            my $EmailParser = Kernel::System::EmailParser->new(
                Email     => \@Content,
                NoDecrypt => 1,
                NoVerify  => 1
            );

            # get all email addresses on article
            my %EmailsToSearch;
            for my $Email (qw(Resent-To Envelope-To To Cc Delivered-To X-Original-To)) {

                my @EmailAddressOnField = $EmailParser->SplitAddressLine(
                    Line => $EmailParser->GetParam( WHAT => $Email ),
                );

                # filter email addresses avoiding repeated and save on hash to search
                for my $EmailAddress (@EmailAddressOnField) {
                    my $CleanEmailAddress = $EmailParser->GetEmailAddress(
                        Email => $EmailAddress,
                    );
                    $EmailsToSearch{$CleanEmailAddress} = '1';
                }
            }

            # look for private keys for every email address
            my @PrivateKeyIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'Certificate',
                Result     => 'ARRAY',
                Search     => {
                    AND => [
                        {
                            Field    => 'Type',
                            Operator => 'EQ',
                            Value    => 'Private',
                        },
                        {
                            Field    => 'Email',
                            Operator => 'IN',
                            Value    => [ keys %EmailsToSearch ],
                        },
                    ]
                },
                UserID   => 1,
                UserType => 'Agent'
            );

            if ( !scalar( @PrivateKeyIDs ) ) {
                if ( $Self->{Debug} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'debug',
                        Message  => "Impossible to decrypt: private key for email was not found!"
                    );
                }
                return {
                    Flags   => [
                        {
                            Key   => 'SMIMEEncrypted',
                            Value => 1
                        },
                        {
                            Key   => 'SMIMEEncryptedError',
                            Value => 'Private key for email was not found!'
                        }
                    ],
                    Content    => $Param{Content},
                    Successful => 0
                };
            }
            elsif ( $Self->{Debug} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'debug',
                    Message  => 'Private Keys (' . scalar( @PrivateKeyIDs ) . ') found!'
                );
            }

            # search private cert to decrypt email
            my %Decrypt;
            for my $ID ( @PrivateKeyIDs ) {

                # decrypt
                %Decrypt = $Self->_Decrypt(
                    Content => $Param{Content},
                    ID      => $ID
                );

                if ( !%Decrypt ) {
                    return {
                        Flags   => [
                            {
                                Key   => 'SMIMEEncrypted',
                                Value => 1
                            },
                            {
                                Key   => 'SMIMEEncryptedError',
                                Value => 'Internal error!'
                            }
                        ],
                        Content    => $Param{Content},
                        Successful => 0
                    }
                }
                elsif ( $Decrypt{Successful} ) {

                    # replaces crypted body
                    my $NewContent = $EmailParser->GetEmailHead(
                        NoSMIMEContent => 1
                    );
                    push ( @{$NewContent}, @{$Decrypt{Content}} );

                    if ( $Self->{Debug} ) {
                        $Kernel::OM->Get('Log')->Log(
                            Priority => 'debug',
                            Message  => "OpenSSL: OK"
                        );
                    }
                    return {
                        Flags   => [
                            {
                                Key   => 'SMIMEEncrypted',
                                Value => 1
                            }
                        ],
                        Content    => $NewContent,
                        Successful => 1
                    }
                }
            }

            if ( !$Decrypt{Successful} ) {
                if ( $Self->{Debug} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'debug',
                        Message  => "Impossible to decrypt: private keys found do not match encryption!"
                    );
                }

                return {
                    Flags   => [
                        {
                            Key   => 'SMIMEEncrypted',
                            Value => 1
                        },
                        {
                            Key   => 'SMIMEEncryptedError',
                            Value => 'Private keys found do not match encryption!'
                        }
                    ],
                    Content    => $Param{Content},
                    Successful => 0
                }
            }
        }
    }
    else {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Not supported Type $Param{Type}!"
            );
        }
        return;
    }

    return 1;
}

sub Encrypt {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(Entity To) ) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    if ( !$Param{Encrypt} ) {
        if ( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "The email will not be encrypted!"
            );
        }
        # return empty flag to continue the normal process
        return (
            Flags      => [],
            Successful => 1
        );
    }

    # get recipients
    my @ToArray;

    RECIPIENT:
    for my $Recipient ( qw(To Cc Bcc) ) {
        next RECIPIENT if !$Param{$Recipient};
        for my $Email ( Email::Address::XS->parse($Param{$Recipient}) ) {
            my $EmailAddress = $Email->address();
            if ( $EmailAddress !~ /$Param{IgnoreEmailPattern}/gix ) {
                push(@ToArray, $EmailAddress);
            }
        }
    }

    my $Count = scalar( @ToArray );
    if ( $Count > 1 ) {
        if ( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Impossible to encrypt: Only one recipient supported for encryption. Got $Count recipients!"
            );
        }
        return (
            Successful => 0,
            Flags      => [
                {
                    Key   => 'SMIMEEncrypted',
                    Value => 1
                },
                {
                    Key   => 'SMIMEEncryptedError',
                    Value => "Only one recipient supported for encryption. Got $Count recipients!"
                }
            ]
        );
    }

    my $Certificates = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Certificate',
        Result     => 'COUNT',
        Search     => {
            AND => [
                {
                    Field    => 'Type',
                    Operator => 'EQ',
                    Value    => 'Cert'
                },
                {
                    Field    => 'Email',
                    Operator => 'EQ',
                    Value    => $ToArray[0]
                }
            ]
        },
        UserID   => 1,
        UserType => 'Agent'
    );

    if (
        $Param{Encrypt} eq '1'
        && !$Certificates
    ) {
        return (
            Successful => 0,
            Flags      => [
                {
                    Key   => 'SMIMEEncrypted',
                    Value => 1
                },
                {
                    Key   => 'SMIMEEncryptedError',
                    Value => "Could not be sent, because no certificate found!"
                }
            ]
        );
    } elsif ( !$Certificates ) {
        return (
            Successful => 0,
            Flags      => [
                {
                    Key   => 'SMIMEEncrypted',
                    Value => 1
                },
                {
                    Key   => 'SMIMEEncryptedError',
                    Value => "No certificate found!"
                }
            ]
        );
    }

    my $CurrTime       = $Kernel::OM->Get('Time')->CurrentTimestamp();
    my @CertificateIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Certificate',
        Result     => 'ARRAY',
        Search     => {
            AND => [
                {
                    Field    => 'Type',
                    Operator => 'EQ',
                    Value    => 'Cert'
                },
                {
                    Field    => 'Email',
                    Operator => 'EQ',
                    Value    => $ToArray[0]
                },
                {
                    Field    => 'StartDate',
                    Operator => 'LTE',
                    Value    => $CurrTime
                },
                {
                    Field    => 'EndDate',
                    Operator => 'GTE',
                    Value    => $CurrTime
                }
            ]
        },
        Sort     => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Limit    => 1,
        UserID   => 1,
        UserType => 'Agent'
    );

    if ( !scalar(@CertificateIDs) ) {
        if ( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Impossible to encrypt: No valid certificate found for $ToArray[0]!"
            );
        }
        return (
            Successful => 0,
            Flags      => [
                {
                    Key   => 'SMIMEEncrypted',
                    Value => 1
                },
                {
                    Key   => 'SMIMEEncryptedError',
                    Value => "No valid certificate found!"
                }
            ]
        );
    }

    # make multi part
    my $EntityCopy = $Param{Entity}->dup();
    $EntityCopy->make_multipart(
        'mixed;',
        Force => 1,
    );

    # get header to remember
    my $Head = $EntityCopy->head();
    $Head->delete('MIME-Version');
    $Head->delete('Content-Type');
    $Head->delete('Content-Disposition');
    $Head->delete('Content-Transfer-Encoding');
    my $SMIMEHeader = $Head->as_string();

    # get string to sign
    my $Content = $EntityCopy->parts(0)->as_string();

    # according to RFC3156 all line endings MUST be CR/LF
    $Content =~ s/\x0A/\x0D\x0A/g;
    $Content =~ s/\x0D+/\x0D/g;

    my %Encrypt = $Self->_Encrypt(
        Content => $Content,
        ID      => $CertificateIDs[0]
    );

    if (!%Encrypt) {
        return (
            Successful => 0,
            Flags      => [
                {
                    Key   => 'SMIMEEncrypted',
                    Value => 1
                },
                {
                    Key   => 'SMIMEEncryptedError',
                    Value => 'Internal error!'
                }
            ]
        );
    }
    elsif ( $Encrypt{Successful} ) {
        my $Parser = MIME::Parser->new();
        $Parser->output_to_core('ALL');

        $Parser->output_dir( $Kernel::OM->Get('Config')->Get('TempDir') );
        $Param{Entity} = $Parser->parse_data( $SMIMEHeader . $Encrypt{Content} );

        # set 'mail_hdr_modify' for header to enable line folding
        $Param{Entity}->head()->modify(1);

        if ( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Succesful to encrypted"
            );
        }

        return (
            Successful => 1,
            Flags      => [
                {
                    Key   => 'SMIMEEncrypted',
                    Value => 1
                }
            ],
            Entity => $Param{Entity}
        );
    }

    if ( $Self->{Debug} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => "Impossible to encrypt: $Encrypt{Error}!"
        );
    }

    return (
        Successful => 0,
        Flags      => [
            {
                Key   => 'SMIMEEncrypted',
                Value => 1
            },
            {
                Key   => 'SMIMEEncryptedError',
                Value => "$Encrypt{Error}!"
            }
        ]
    );
}

sub Verify {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(Content Type) ) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Needed $Needed!"
                );
            }
            return;
        }
    }

    if ( $Param{Type} eq 'Email' ) {

        my $ContentType = $Self->_CheckContentType(
            %Param
        );
        return if !$ContentType;

        if (
            $ContentType =~ /application\/(x-pkcs7|pkcs7)/i
            && $ContentType =~ /signed/i
        ) {
            # require EmailParser
            if ( !$Kernel::OM->Get('Main')->Require( 'Kernel::System::EmailParser' ) ) {
                return {
                    Flags   => [
                        {
                            Key   => 'SMIMESigned',
                            Value => 1
                        },
                        {
                            Key   => 'SMIMESignedError',
                            Value => 'Internal error!'
                        }
                    ],
                    Content => $Param{Content}
                };
            }

            my $Content = $Param{Content};

            # check sign and get clear content
            my %Verified = $Self->_Verify(
                Content => $Content
            );

            if ( !%Verified ) {
                return {
                    Flags   => [
                        {
                            Key   => 'SMIMESigned',
                            Value => 1
                        },
                        {
                            Key   => 'SMIMESignedError',
                            Value => 'Could not verified!'
                        }
                    ],
                    Content => $Content
                }
            }

            if (
                $Verified{Type} eq 'Unverified'
                && !defined $Verified{Content}
            ) {
                return {
                    Flags   => [
                        {
                            Key   => 'SMIMESigned',
                            Value => 1
                        },
                        {
                            Key   => 'SMIMESignedError',
                            Value => $Verified{Error}
                        }
                    ],
                    Content => $Content
                }
            }
            elsif ( $Verified{Type} eq 'SelfSign' ) {
                my %NoVerified = $Self->_Verify(
                    Content  => $Content,
                    NoVerify => 1
                );

                # If the signature was verified well, use the stripped content to store the email
                if (
                    $NoVerified{Type}
                    && $NoVerified{Content}
                ) {
                    $Verified{Content} = $NoVerified{Content};
                }
            }

            # from RFC 3850
            # 3.  Using Distinguished Names for Internet Mail
            #
            #   End-entity certificates MAY contain ...
            #
            #    ...
            #
            #   Sending agents SHOULD make the address in the From or Sender header
            #   in a mail message match an Internet mail address in the signer's
            #   certificate.  Receiving agents MUST check that the address in the
            #   From or Sender header of a mail message matches an Internet mail
            #   address, if present, in the signer's certificate, if mail addresses
            #   are present in the certificate.  A receiving agent SHOULD provide
            #   some explicit alternate processing of the message if this comparison
            #   fails, which may be to display a message that shows the recipient the
            #   addresses in the certificate or other certificate details.

            # as described in bug#5098 and RFC 3850 an alternate mail handling should be
            # made if sender and signer addresses does not match

            # get original sender from email
            my @OrigEmail = @{$Content};
            my $ParserObjectOrig = Kernel::System::EmailParser->new(
                Email     => \@OrigEmail,
                NoDecrypt => 1,
                NoVerify  => 1
            );

            my $OrigFrom   = $ParserObjectOrig->GetParam( WHAT => 'From' ) || q{};
            my $OrigSender = $ParserObjectOrig->GetEmailAddress( Email => $OrigFrom ) || q{};

            # compare sender email to signer email
            my $SignerSenderMatch = 0;
            SIGNER:
            for my $Signer ( @{ $Verified{Signers} } ) {
                if ( $OrigSender =~ m{\A \Q$Signer\E \z}xmsi ) {
                    $SignerSenderMatch = 1;
                    last SIGNER;
                }
            }

            # sender email does not match signing certificate!
            if ( !$SignerSenderMatch ) {
                my $Message = $Verified{Error};
                $Message =~ s/successful/failed!/;
                $Message .= " (signed by \""
                    . join( ' | ', @{ $Verified{Signers} } )
                    . "\")"
                    . ", but sender address \"$OrigSender\": does not match certificate address!";

                if ( !$Param{Silent} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => $Message
                    );
                }

                return {
                    Flags   => [
                        {
                            Key   => 'SMIMESigned',
                            Value => 1
                        },
                        {
                            Key   => 'SMIMESignedError',
                            Value => $Message
                        }
                    ],
                    Content => $Content
                }
            }
            else{
                return {
                    Flags   => [
                        {
                            Key   => 'SMIMESigned',
                            Value => 1
                        }
                    ],
                    Content => $Content
                }
            }
        }
    }
    else {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Not supported Type $Param{Type}!"
            );
        }
        return;
    }

    return 1;
}

sub Sign {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(Entity From) ) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    # parse mail addresses
    my @ParsedMailAddresses = Email::Address::XS->parse($Param{From});
    my $From;
    foreach my $MailAddress (@ParsedMailAddresses) {
        $From = $MailAddress->address;
    }

    my $CurrTime = $Kernel::OM->Get('Time')->CurrentTimestamp();

    my $PrivateKeys = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Certificate',
        Result     => 'COUNT',
        Search     => {
            AND => [
                {
                    Field    => 'Type',
                    Operator => 'EQ',
                    Value    => 'Private'
                },
                {
                    Field    => 'Email',
                    Operator => 'EQ',
                    Value    => $From
                }
            ]
        },
        UserID   => 1,
        UserType => 'Agent'
    );

    # return empty flag to continue the normal process
    return ( Flags => [] ) if !$PrivateKeys;

    my @PrivateKeyIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Certificate',
        Result     => 'ARRAY',
        Search     => {
            AND => [
                {
                    Field    => 'Type',
                    Operator => 'EQ',
                    Value    => 'Private'
                },
                {
                    Field    => 'Email',
                    Operator => 'EQ',
                    Value    => $From
                },
                {
                    Field    => 'StartDate',
                    Operator => 'LTE',
                    Value    => $CurrTime
                },
                {
                    Field    => 'EndDate',
                    Operator => 'GTE',
                    Value    => $CurrTime
                }
            ]
        },
        UserID   => 1,
        UserType => 'Agent'
    );

    if ( !scalar(@PrivateKeyIDs) ) {
        if ( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Impossible to sign: no valid certificate found for $From!"
            );
        }
        return (
            Flags => [
                {
                    Key   => 'SMIMESigned',
                    Value => 1
                },
                {
                    Key   => 'SMIMESignedError',
                    Value => "No valid certificate found!"
                }
            ]
        );
    }

    # make multi part
    my $EntityCopy = $Param{Entity}->dup();
    $EntityCopy->make_multipart(
        'mixed;',
        Force => 1,
    );

    # get header to remember
    my $Head = $EntityCopy->head();
    $Head->delete('MIME-Version');
    $Head->delete('Content-Type');
    $Head->delete('Content-Disposition');
    $Head->delete('Content-Transfer-Encoding');
    my $SMIMEHeader = $Head->as_string();

    # get string to sign
    my $Content = $EntityCopy->parts(0)->as_string();

    # according to RFC3156 all line endings MUST be CR/LF
    $Content =~ s/\x0A/\x0D\x0A/g;
    $Content =~ s/\x0D+/\x0D/g;

    # remove empty line after multi-part preable as it will be removed later by MIME::Parser
    #    otherwise signed content will be different than the actual mail and verify will
    #    fail
    $Content =~ s{(This is a multi-part message in MIME format...\r\n)\r\n}{$1}g;

    for my $ID ( @PrivateKeyIDs ) {

        my %Sign = $Self->_Sign(
            Content => $Content,
            ID      => $ID
        );

        if (!%Sign) {
            return (
                Flags   => [
                    {
                        Key   => 'SMIMESigned',
                        Value => 1
                    },
                    {
                        Key   => 'SMIMESignedError',
                        Value => 'Internal error!'
                    }
                ]
            );
        }
        elsif ( $Sign{Successful} ) {
            my $Parser = MIME::Parser->new();
            $Parser->output_to_core('ALL');

            $Parser->output_dir( $Kernel::OM->Get('Config')->Get('TempDir') );
            $Param{Entity} = $Parser->parse_data( $SMIMEHeader . $Sign{Content} );

            # set 'mail_hdr_modify' for header to enable line folding
            $Param{Entity}->head()->modify(1);

            return (
                Flags   => [
                    {
                        Key   => 'SMIMESigned',
                        Value => 1
                    }
                ],
                Entity => $Param{Entity}
            );
        }
    }

    if ( $Self->{Debug} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => "Impossible to sign: found certificates could not be applied!"
        );
    }

    return (
        Flags   => [
            {
                Key   => 'SMIMESigned',
                Value => 1
            },
            {
                Key   => 'SMIMESignedError',
                Value => 'Found certificates could not be applied!'
            }
        ]
    );
}

=begin Internal

=item _WriteCertificate()

writes certificates / private keys to the file system

=cut

sub _WriteCertificate {
    my ( $Self,%Param ) = @_;

    for my $Needed ( qw(ID Type Content) ) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Needed $Needed!"
                );
            }
            return;
        }
    }

    my $Path = $Self->{$Param{Type}}->{Path};
    $Path .= '/KIX_'
        . $Param{Type}
        . q{_}
        . $Param{ID};

    if ( -e $Path ) {
        return 1;
    }

    my $Content = MIME::Base64::decode_base64( $Param{Content} );
    my $Success = $Kernel::OM->Get('Main')->FileWrite(
        Location => $Path,
        Content  => \$Content,
        Mode     => 'binmode'
    );

    if ( !$Success ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Certificate could not be create!'
            );
        }
        if ( !$Param{NoDelete} ) {
            $Self->CertificateDelete(
                ID     => $Param{ID},
                Silent => $Param{Silent}
            );
        }
    }

    return $Success;
}

=item _CheckCertificate()

checks the given certificate/private key, if all needed parameters are exists

=cut

sub _CheckCertificate {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(File Type CType) ) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    for my $Needed ( qw(Content ContentType Filename) ) {
        if ( !$Param{File}->{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed in File!"
                );
            }
            return;
        }
    }

    my $ContentTypes = $Self->{$Param{Type}}->{ContentTypes};
    if ( !$ContentTypes->{$Param{File}->{ContentType}} ) {
        if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid content type $Param{File}->{ContentType}"
                );
            }
            return;
    }

    if (
        $Param{Type} eq 'Private'
        && !$Param{Passphrase}
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need Passphrase!"
            );
        }
        return;
    }

    return 1;
}

=item _GetCertificateAttributes()

Captures all necessary certificate/private key information and returns this as a hashref

=cut

sub _GetCertificateAttributes {
    my ( $Self, %Param ) = @_;

    if ( !$Param{File} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need File!'
        );
        return;
    }

    my $File = $Param{File};

    my $Content = MIME::Base64::decode_base64( $File->{Content} );

    my $CacheKey = 'Certificate::'
        . ( $Param{CType} ? $Param{CType} . q{::} : q{} )
        . $Param{Type}
        . q{::}
        . 'Attributes::Filename::'
        . $File->{Filename};

    # check cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    # return if cache found,
    return $Cache if ref $Cache eq 'HASH';

    # get temp file
    my ( $FH, $Filename ) = $Kernel::OM->Get('FileTemp')->TempFile();
    print {$FH} $Content;
    close $FH or return;

    if ( !-e $Filename ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such $Filename!",
        );
        return;
    }

    my $Attributes = $Self->_FetchAttributes(
        Filename    => $Filename,
        Type        => $Param{Type},
        ContentType => $File->{ContentType},
        Passphrase  => $Param{Passphrase} || q{},
        Silent      => $Param{Silent}
    );

    return if !IsHashRefWithData($Attributes);

    # set type
    if ( $Param{Type} eq 'Cert' ) {
        $Attributes->{Type} = 'Cert';
    }
    else {
        $Attributes->{Type} = 'Private';
        if ( $Param{Passphrase} ) {
            $Attributes->{Passphrase} = $Param{Passphrase};
        }
    }

    # set CType
    $Attributes->{CType} = $Param{CType};

    # set cache
    if ($CacheKey) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => $CacheKey,
            Value => $Attributes,
            TTL   => $Self->{CacheTTL}
        );
    }

    return $Attributes;
}

=item _FetchAttributes()

Gets the certificate/private key information via openssl

=cut

sub _FetchAttributes {
    my ( $Self, %Param ) = @_;

    my $AttributesRef;
    my $Filename = $Param{Filename};

    my $Command = $Self->{$Param{Type}}->{ContentTypes}->{$Param{ContentType}};
    my $Options = $Self->{$Param{Type}}->{Options}->{$Command};

    if ( !IsArrayRef($Options) ) {
        $Options = [$Options];
    }

    my $Result;
    for my $OptionStrg ( @{$Options}) {
        # Replacing of needed parameters
        $OptionStrg =~ s/###FILENAME###/$Filename/sm;
        $OptionStrg =~ s/###PASSPHRASE###/$Param{Passphrase}/sm;
        $OptionStrg =~ s/###BIN###/$Self->{Bin}/sm;

        # get the output string
        my $Output = qx{$Self->{Cmd} $OptionStrg 2>&1};

        if ( $Output =~ /error:/sm ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => $Output
                );
            }
            return;
        }

        $Result .= "\n" if $Result;
        $Result .= $Output;
    }

    # filters
    my %Filters = (
        Hash        => '(\w{8})',
        Issuer      => 'issuer=\s*(.*)',
        Fingerprint => 'SHA1(?:\sFingerprint|\s*\(stdin\))=\s*(.*)',
        Serial      => 'serial=(.*)',
        Subject     => 'subject=\s*(.*)',
        StartDate   => 'notBefore=(.*)',
        EndDate     => 'notAfter=(.*)',
        Email       => '([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+)',
        Modulus     => 'Modulus=(.*)',
        Verify      => 'verify\s+(.*)'
    );

    # parse output string
    my @Attributes = split( /\n/sm, $Result );
    for my $Line (@Attributes) {

        # clean end spaces
        $Line =~ tr{\r\n}{}d;

        # look for every attribute by filter
        FILTER:
        for my $Filter ( sort keys %Filters ) {
            my @Matches = $Line =~ m{ \A $Filters{$Filter} \z }xmsi;

            next FILTER if !scalar(@Matches);

            my $Match = $Matches[0] || q{};

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
        next if !$AttributesRef->{$DateType};

        my @Date = $AttributesRef->{$DateType} =~ /(.+?)\s(.+?)\s(\d\d:\d\d:\d\d)\s(\d\d\d\d)/sm;

        next if !@Date || scalar(@Date) < 4;

        my $D    = sprintf('%02d', $Date[1]);
        my $M    = q{};
        my $Y    = $Date[3];
        my $Time = $Date[2];

        MONTH_KEY:
        for my $MonthKey ( sort keys %Month ) {
            if ( $AttributesRef->{$DateType} =~ /$MonthKey/i ) {
                $M = $Month{$MonthKey};
                last MONTH_KEY;
            }
        }
        $AttributesRef->{$DateType} = "$Y-$M-$D $Time";
    }

    return $AttributesRef;
}

=item _Init()

Initializes all necessary internal data

=cut

sub _Init {
    my ( $Self, %Param ) = @_;

    # ToDo: The following MimeTypes are deactivated for the time being,
    #       as the password is also required for the public to access the information.
    my $HomeDir = $Kernel::OM->Get('Config')->Get('Home');
    $Self->{Cert} = {
        Path         => $HomeDir. '/var/ssl/certs',
        ContentTypes => {
            'application/pkcs10'                 => 'req',
            'application/x-x509-ca-cert'         => 'x509',
            'application/x-x509-user-cert'       => 'x509',
            # 'application/x-pkcs7-certificates'   => 'pkcs7',
            # 'application/x-pkcs7-certreqresp'    => 'pkcs7',
            'application/pkix-cert'              => 'x509',
            'application/pkix-crl'               => 'x509',
            'application/x-pem-file'             => 'x509',
            # 'application/x-pkcs12'               => 'pkcs12',
            # 'application/pkcs8'                  => 'pkcs8',
        },
        Options => {
            'req'    => [
                'req -in ###FILENAME### -noout -verify -modulus -subject',
                'req -in ###FILENAME### -outform DER -noout | openssl dgst -sha1 -c'
            ],
            'x509'   => 'x509 -in ###FILENAME### -noout -subject_hash -issuer -fingerprint -sha1 -serial -subject -startdate -enddate -email -modulus',
            # 'pkcs7'  => 'pkcs7 -in ###FILENAME### -inform PEM -print_certs | ###BIN### x509 -noout -subject_hash -issuer -fingerprint -sha1 -serial -subject -startdate -enddate -email -modulus',
            # 'pkcs12' => 'pkcs12 -in ###FILENAME### -nodes -passout pass:###PASSPHRASE### | ###BIN### x509 -noout -subject_hash -issuer -fingerprint -sha1 -serial -subject -startdate -enddate -email -modulus',
            # 'pkcs8'  => 'pkcs8 -in ###FILENAME### -nodes -passout pass:###PASSPHRASE### | ###BIN### x509 -noout -subject_hash -issuer -fingerprint -sha1 -serial -subject -startdate -enddate -email -modulus',
        }
    };
    $Self->{Private} = {
        Path         => $HomeDir. '/var/ssl/private',
        ContentTypes => {
            # 'application/pkcs8'                  => 'pkcs8',
            # 'application/x-pkcs12'               => 'pkcs12',
            'application/x-pem-file'             => 'rsa',
            'application/x-iwork-keynote-sffkey' => 'rsa',
            'application/vnd.apple.keynote'      => 'rsa',
            'application/x-x509-ca-cert'         => 'rsa'
        },
        Options => {
            'rsa'    => 'rsa -in ###FILENAME### -noout -modulus -passin pass:###PASSPHRASE###',
            # 'pkcs12' => 'pkcs12 -in ###FILENAME### -nodes -passin pass:###PASSPHRASE### | ###BIN### x509 -noout -modulus',
            # 'pkcs8'  => 'pkcs8 -in ###FILENAME### -noout -nodes -passin pass:###PASSPHRASE### | ###BIN### x509 -noout -modulus',
        }
    };
    $Self->{Bin} = '/usr/bin/openssl';

    # make sure that we are getting POSIX (i.e. english) messages from openssl
    $Self->{Cmd} = "LC_MESSAGES=POSIX $Self->{Bin}";

    # ensure that there is a random state file that we can write to (otherwise openssl will bail)
    local $ENV{RANDFILE} = $Kernel::OM->Get('Config')->Get('TempDir') . '/.rnd';

    # prepend RANDFILE declaration to openssl cmd
    $Self->{Cmd} = "HOME="
        . $Kernel::OM->Get('Config')->Get('Home')
        . " RANDFILE=$ENV{RANDFILE} $Self->{Cmd}";

    return $Self->_InitCheck();
}

=item _InitCheck()

check if environment is working

=cut

sub _InitCheck {
    my ( $Self, %Param ) = @_;

    my $Success = 1;
    if ( !-e $Self->{Bin} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{Bin}!",
        );
        $Success = 0;
    }
    elsif ( !-x $Self->{Bin} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "$Self->{Bin} not executable!",
        );
        $Success = 0;
    }

    for my $Key ( qw( Cert Private) ) {
        if ( !-e $Self->{$Key}->{Path} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No such $Self->{$Key}->{Path}!",
            );
            $Success = 0;
            last;
        }
        elsif ( !-d $Self->{$Key}->{Path} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No such $Self->{$Key}->{Path} directory!",
            );
            $Success = 0;
            last;
        }
        elsif ( !-w $Self->{$Key}->{Path} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "$Self->{$Key}->{Path} not writable!",
            );
            $Success = 0;
            last;
        }
    }

    return $Success;
}

=item _CacheCleanUp()

Deletes all caches for the Module

=cut

sub _CacheCleanUp {
    my ( $Self, %Param ) = @_;

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{OSCacheType}
    );

    return 1;
}

sub _Decrypt {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Content ID)) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    my $PrivateKey    = $Self->CertificateGet(
        %Param,
        Passphrase => 1
    );
    my @CertificateID = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Certificate',
        Result     => 'ARRAY',
        Search     => {
            AND => [
                {
                    Field    => 'Modulus',
                    Operator => 'EQ',
                    Value    => $PrivateKey->{Modulus}
                },
                {
                    Field    => 'Type',
                    Operator => 'EQ',
                    Value    => 'Cert'
                }
            ]
        },
        Sort => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Limit    => 1,
        UserID   => 1,
        UserType => 'Agent'
    );

    if ( !scalar(@CertificateID) ) {
        if( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Decrypt (Private Key: $PrivateKey->{FileID}): No suitable certificate found!"
            );
        }
        return (
            Successful => 0
        );
    }

    my $Certificate = $Self->CertificateGet(
        ID => $CertificateID[0]
    );

    my $PrivateFile = $Self->{Private}->{Path} . q{/} . $PrivateKey->{Filename};
    my $CertFile    = $Self->{Cert}->{Path} . q{/} .  $Certificate->{Filename};
    my $Content     = join(q{} , @{$Param{Content}} );

    my ( $FH, $CryptedFile ) = $Kernel::OM->Get('FileTemp')->TempFile();
    print $FH $Content;
    close $FH;
    my ( $FHDecrypted, $PlainFile ) = $Kernel::OM->Get('FileTemp')->TempFile();
    close $FHDecrypted;

    my $Options = "smime -decrypt"
        . " -in $CryptedFile"
        . " -out $PlainFile"
        . " -recip $CertFile"
        . " -inkey $PrivateFile"
        . " -passin pass:$PrivateKey->{Passphrase}";

    my $LogMessage = qx{$Self->{Cmd} $Options 2>&1};

    if ($LogMessage) {
        if( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Decrypt (Private Key: $PrivateKey->{FileID}): $LogMessage!"
            );
        }
        return (
            Successful => 0
        );
    }

    my $DecryptedRef = $Kernel::OM->Get('Main')->FileRead(
        Location => $PlainFile,
        Silent   => 1
    );

    if ( !$DecryptedRef ) {
        if( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "OpenSSL: Can't read $PlainFile!"
            );
        }
        return (
            Successful => 0
        );
    }

    my @NewContent = map { "$_\n" } split( /\n/, ${$DecryptedRef});

    return (
        Successful => 1,
        Content    => \@NewContent,
    );
}

sub _Verify {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Content} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need Content!"
            );
        }
        return;
    }

    my $Content = join( q{}, @{$Param{Content}} );
    my ( $FH, $SignedFile ) = $Kernel::OM->Get('FileTemp')->TempFile();
    print $FH $Content;
    close $FH;
    my ( $FHOutput, $VerifiedFile ) = $Kernel::OM->Get('FileTemp')->TempFile();
    close $FHOutput;
    my ( $FHSigner, $SignerFile ) = $Kernel::OM->Get('FileTemp')->TempFile();
    close $FHSigner;

    my @CertificateOption = ();
    if ( $Param{NoVerify} ) {
        push( @CertificateOption, '-noverify' );
    }

    my $Options = 'smime -verify'
        . " -in $SignedFile"
        . " -out $VerifiedFile"
        . " -signer $SignerFile"
        . " -CApath /etc/ssl/certs"
        . q{ } .  join( q{ } , @CertificateOption )
        . " $SignedFile";

    my @LogLines = qx{$Self->{Cmd} $Options 2>&1};

    my $Message     = q{};
    my $MessageLong = q{};
    for my $LogLine (@LogLines) {
        $MessageLong .= $LogLine;
        if ( $LogLine =~ /^\d.*:(.+?):.+?:.+?:$/ || $LogLine =~ /^\d.*:(.+?)$/ ) {
            $Message .= ";$1";
        }
        else {
            $Message .= $LogLine;
        }
    }

    my $SignerCertRef    = $Kernel::OM->Get('Main')->FileRead(
        Location => $SignerFile,
        Silent   => 1
    );
    my $SignedContentRef = $Kernel::OM->Get('Main')->FileRead(
        Location => $VerifiedFile,
        Silent   => 1
    );

    my @NewContent = map { "$_\n" } split( /\n/, ${$SignedContentRef} );

    # return message
    if ( $Message =~ /Verification successful/i ) {

        # Determine email address(es) from attributes of signer certificate.
        my $Attributes = $Self->_FetchAttributes(
            Filename    => $SignerFile,
            Type        => 'Cert',
            ContentType => 'application/x-x509-ca-cert',
            Silent      => $Param{Silent}
        );

        my @SignersArray = split( /, /sm, $Attributes->{Email} );

        if ( $Self->{Debug} ) {
            # Include additional certificate attributes in the message:
            #   - signer(s) email address(es)
            #   - certificate hash
            #   - certificate fingerprint
            #   Please see bug#12284 for more information.
            my $MessageSigner = join( ', ', @SignersArray ) . ' : '
                . $Attributes->{Hash} . ' : '
                . $Attributes->{Fingerprint};

            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => 'OpenSSL: ' . $MessageLong . ' (' . $MessageSigner . ')',
            );
        }

        return (
            Type      => 'Verified',
            Signers   => [@SignersArray],
            Content   => \@NewContent,
        );
    }
    elsif ( $Message =~ /self signed certificate/i ) {
        if ( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => 'OpenSSL: self signed certificate, to use it send the \'Certificate\' parameter : '
                    . $MessageLong,
            );
        }

        return (
            Type      => 'SelfSign',
            Error     => 'OpenSSL: self signed certificate, to use it send the \'Certificate\' parameter : '
                . $Message,
            Content   => \@NewContent
        );
    }

    # digest failure means that the content of the email does not match witht he signature
    elsif ( $Message =~ m{digest failure}i ) {
        if ( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => 'OpenSSL: The signature does not match the message content : ' . $MessageLong,
            );
        }

        return (
            Type      => 'Unverified',
            Error     => 'OpenSSL: The signature does not match the message content : ' . $Message,
            Content   => \@NewContent
        );
    }

    if ( $Self->{Debug} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'debug',
            Message  => 'OpenSSL: ' . $MessageLong,
        );
    }

    return (
        Type  => 'Unverified',
        Error => 'OpenSSL: ' . $Message,
    );
}

sub _Sign {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Content ID)) {
        if ( !$Param{$_} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    my $PrivateKey    = $Self->CertificateGet(
        %Param,
        Passphrase => 1
    );
    my @CertificateID = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Certificate',
        Result     => 'ARRAY',
        Search     => {
            AND => [
                {
                    Field    => 'Modulus',
                    Operator => 'EQ',
                    Value    => $PrivateKey->{Modulus}
                },
                {
                    Field    => 'Type',
                    Operator => 'EQ',
                    Value    => 'Cert'
                }
            ]
        },
        Sort => [
            {
                Field     => 'ID',
                Direction => 'descending'
            }
        ],
        Limit    => 1,
        UserID   => 1,
        UserType => 'Agent'
    );

    if ( !scalar(@CertificateID) ) {
        if( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Sign (Private Key: $PrivateKey->{FileID}): No suitable certificate found!"
            );
        }
        return (
            Successful => 0
        );
    }

    my $Certificate = $Self->CertificateGet(
        ID => $CertificateID[0]
    );

    my $PrivateFile = $Self->{Private}->{Path} . q{/} . $PrivateKey->{Filename};
    my $CertFile    = $Self->{Cert}->{Path} . q{/} .  $Certificate->{Filename};
    my $Content     = $Param{Content};

    if ( IsArrayRef($Param{Content}) ) {
        $Content = join(q{} , @{$Param{Content}} );
    }

    my ( $FH, $PlainFile ) = $Kernel::OM->Get('FileTemp')->TempFile();
    print $FH $Content;
    close $FH;
    my ( $FHSign, $SignFile ) = $Kernel::OM->Get('FileTemp')->TempFile();
    close $FHSign;

    my $Options = "smime -sign "
        . " -in $PlainFile"
        . " -out $SignFile"
        . " -signer $CertFile"
        . " -inkey $PrivateFile"
        . " -text -binary -passin pass:$PrivateKey->{Passphrase}";

    my $LogMessage = $Self->_CleanOutput(qx{$Self->{Cmd} $Options 2>&1});

    if ($LogMessage) {
        if( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Impossible to sign: $LogMessage! (Command: $Options)"
            );
        }
        return(
            Successful => 0,
            Error      => "$LogMessage!"
        );
    }

    my $SignedRef = $Kernel::OM->Get('Main')->FileRead(
        Location => $SignFile
    );
    unlink($SignFile);

    return(
        Successful => 1,
        Content    => ${$SignedRef}
    );
}

sub _Encrypt {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Content ID)) {
        if ( !$Param{$_} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    my $Certificate    = $Self->CertificateGet(
        %Param
    );

    my $CertFile = $Self->{Cert}->{Path} . q{/} .  $Certificate->{Filename};
    my $Content  = $Param{Content};

    if ( IsArrayRef($Param{Content}) ) {
        $Content = join(q{} , @{$Param{Content}} );
    }

    my ( $FH, $PlainFile ) = $Kernel::OM->Get('FileTemp')->TempFile();
    print $FH $Content;
    close $FH;
    my ( $FHCrypted, $CryptedFile ) = $Kernel::OM->Get('FileTemp')->TempFile();
    close $FHCrypted;

    my $Options = "smime -encrypt -binary -des3"
        . " -in $PlainFile"
        . " -out $CryptedFile "
        . $CertFile;

    my $LogMessage = $Self->_CleanOutput(qx{$Self->{Cmd} $Options 2>&1});

    if ($LogMessage) {
        if( $Self->{Debug} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'debug',
                Message  => "Impossible to encrypt: $LogMessage! (Command: $Options)"
            );
        }
        return(
            Successful => 0
        );
    }

    my $CryptedRef = $Kernel::OM->Get('Main')->FileRead(
        Location => $CryptedFile
    );

    return(
        Successful => 1,
        Content    => ${$CryptedRef}
    );
}

sub _CheckContentType {
    my ( $Self, %Param ) = @_;

    if ( !$Param{Content} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need Content!"
            );
        }
        return;
    }

    my $Parser = MIME::Parser->new();
    $Parser->decode_headers(0);
    $Parser->extract_nested_messages(0);
    $Parser->output_to_core("ALL");
    my $Entity = $Parser->parse_data($Param{Content});
    my $Head   = $Entity->head();
    $Head->unfold();
    $Head->combine('Content-Type');
    my $ContentType = $Head->get('Content-Type');
    if ( !$ContentType ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => 'E-mail has no ContentType, so "text/plain" is set!'
            );
        }
        return 'text/plain;charset=utf-8';
    }

    return $ContentType
}

# remove spurious warnings that appear on Windows
sub _CleanOutput {
    my ( $Self, $Output ) = @_;

    if ( $^O =~ m{mswin}i ) {
        $Output =~ s{Loading 'screen' into random state - done\r?\n}{}igms;
    }

    return $Output;
}

=end Internal

=cut

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
