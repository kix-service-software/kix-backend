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
    Config
    Cache
    FileTemp
    ClientNotification
    Log
    VirtualFS
);

use MIME::Base64 qw();

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

    $Self->{Debug} = $Param{Debug} || 0;

    $Self->{CacheType} = 'Certificate';
    $Self->{CacheTTL}  = 60 * 60 * 24;

    return 0 if !$Self->_Init();

    return $Self;
}


=item CertificateCreate()

create a local certificate

    my $CertificateID = $CertificateObject->CertificateCreate(
        File => {                                   # required
            Content     => 'some base64 content'
            Filesize    => '6059'
            ContentType => 'application/pcks7-mime'
            Filename    => 'some name'
        },
        Type       => 'Cert'            # required
        Passphrase => 'some secret'     # required, if type Private
        ObjectType => 'SMIME'           # required
    );

    return certificate id

=cut

sub CertificateCreate {
    my ( $Self, %Param ) = @_;

    return if !$Self->_CheckCertificate(%Param);

    my $Attributes = $Self->_GetCertificateAttributes(
        File => $Param{File}
    );

    return if !$Attributes;

    my $Filename = 'Certificate'
        . q{/}
        . $Param{ObjectType}
        . q{/}
        . $Attributes->{Fingerprint};

    my @Exists = $Self->CertificateSearch(
        Filename => $Filename
    );

    if ( scalar(@Exists) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Certificate already exists!'
            );
        }
        return;
    }

    my %Preferences;
    for my $Key ( sort keys %{$Attributes} ) {
        $Preferences{$Key} = $Attributes->{$Key};
    }

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

    my $Path = $Self->{CertPath};
    if ( $Preferences{Type} eq 'Private') {
        $Path = $Self->{PrivatePath};
    }

    $Path .= '/KIX_'
        . $Preferences{Type}
        . q{_}
        . $FileID;

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
        $Self->CertificateDelete(
            ID     => $FileID,
            Silent => $Param{Silent}
        );

        return;
    }

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

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
        ID      => 1          # required
        Include => 'Content'  # optional, to include the content if needed
    );

    returns a hashref

    $Certificate = {
        Email           => "selfsigned@example.de",
        EndDate         => "Jun  1 14:41:34 2030 GMT",
        FileID          => "4",
        Filename        => "KIX_Cert_4",
        Fingerprint     => "8F:9A:BB:D5:92:2F:54:CB:D6:61:96:A6:67:35:81:64:2A:EC:3F:94",
        Hash            => "791510e5",
        Issuer          => "C =  DE, ST =  Saxony, L =  Example, O =  Example GmbH, CN =  selfsigned, emailAddress =  selfsigned@example.de",
        Modulus         => "9B383D6A49187936214BD3AAF55F9334AA94B42E66BA63021594F056B19E46D21DBFE9868C25AD14C67836E82497DCE5B1F7CB8CF3F253883428EE105E447CA3765BD4D172FB5AF2C3A3A5A6B4FDCA12B5ECC96D7263FB303C48DD8E3D45355D336885D81F0F618CF0D6B3748C7E76B59CD49A6ACDFE9B4DADC65BB1045D8027D416D03520D7F8CB14D05D76D2DECA334811A5747CB5C9632AFDAFFB867D3A9B61775DC8BCE3632AC8E6E247C7F8BACACAE7E6F1B745C8FD0132DF823607D5468A15844BCB643389C50B215D62B8C1B0DBB8F4FB265ED178F0015212494A243124A69F500F72F6DEEF0ACC7FB3196E2DED7BD76A6B743F8B74031A7C3EFA3991421411FA42AFBE8ABE062180BAAC0E9F7CF0E65A8D480DA17BD800935F38A510DF7C87838B014A134DF4371D8C3CA4B2AA93673F3E46698DDB1D2BAF691FB0C68992D96F4F1F83A14D7B9006B609E15FC5D7B68BB7FB1895473E33AF3A113EC85D439026665A277E4AA97C08400CAAD36533C63565670777D2FD77D824089DE74685217236A0DAC0B9066FC274B90A9F8D9F357D8FA08E10A3CB38139881D883DFFADEB6BCA678757155333FB9C9A7523986DEA2539CDE8209E8820480D1E56385333720914BED77BDC1707D3453E9ED24D5BAA81F06EFA0F551C7D58D2DC6BF59D78D222C23D5BC583284515286B48DD5120EF76DE2B6C7F08DA1A94A6A795B",
        Serial          => "0B9444A6464EE36AC4B6BACD1F7FBC786295FB05",
        ShortEndDate    => "2030-06-01",
        ShortStartDate  => "2020-06-03",
        StartDate       => "Jun  3 14:41:34 2020 GMT",
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
    if ( $Param{Include} eq 'Content' ) {
        $Mode = 'binary';
    }

    my $CacheKey = 'Certificate::'
        . $Param{ID}
        . q{::}
        . $Mode;

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
    my $Filename = 'KIX_'
        . $File{Preferences}->{Type}
        . q{_}
        . $Param{ID};

    my $Certificate = $File{Preferences};
    $Certificate->{FileID}   = $Param{ID};
    $Certificate->{Filename} = $Filename;

    # remove unnessary datas
    for my $Key ( qw(Filesize FilesizeRaw) ) {
        delete $Certificate->{$Key};
    }

    if ( $Param{Include} eq 'Content' ) {
        $Certificate->{Content} = ${$File{Content}};
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

remove a local certificate

    my $Success = $CertificateObject->CertificateDelete(
        ID => 1
    );

=cut

sub CertificateDelete {
    my ( $Self, %Param ) = @_;

    if ( !$Param{ID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "No certificate found!"
            );
        }
        return;
    }

    my $Filename = 'KIX_'
        . $File{Preferences}->{Type}
        . q{_}
        . $Param{ID};

    my $Path = $Self->{CertPath};
    if ( $File{Preferences}->{Type} eq 'Private' ) {
        $Path = $Self->{PrivatePath};
    }

    $Path .= "/$Filename";

    my $Success;
    if ( -e $Path ) {
        $Success = $Kernel::OM->Get('Main')->FileDelete(
            Location        => $Path,
            DisableWarnings => $Param{Silent}
        );

        if ( !$Success ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
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
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Couldn't delete certificate!"
            );
        }
        return;
    }

    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Certificate',
        ObjectID  => $Param{ID}
    );

    return 1;
}

=item CertificateSearch()

get list of local certificates file ids

    my @CertList = $CertificateObject->CertificateSearch(
        ObjectType  => 'SMIME'                          # optional
        Type        => 'Cert'                           # optional
        Filename    => 'Certificate/SMIME/KIX_Cert_1'   # optional
    );

    return list of virtual fs ids

=cut

sub CertificateSearch {
    my ( $Self, %Param ) = @_;

    my %SearchWhat;
    for my $Key ( qw(ObjectType Type) ) {
        next if !$Param{$Key};
        $SearchWhat{Preferences}->{$Key} = $Param{$Key};
    }

    if ( $Param{Filename} ) {
        $SearchWhat{Filename} = $Param{Filename};
    }
    else {
        $SearchWhat{Filename} = 'Certificate/*';
    }

    my $CacheKey = 'CertificateSearch';
    for my $Key ( qw(ObjectType Type Filename) ) {
        next if !$Param{$Key};
        $CacheKey .= q{::}
            . $Key
            . q{::}
            . $Param{$Key};
    }

    # check cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );

    # return if cache found,
    return @{$Cache} if ref $Cache eq 'ARRAY';

    my @CertIDs = $Kernel::OM->Get('VirtualFS')->Find(
        %SearchWhat,
        ReturnIDs => 1
    );

    # set cache
    if ($CacheKey) {
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            Key   => $CacheKey,
            Value => \@CertIDs,
            TTL   => $Self->{CacheTTL},
        );
    }

    return @CertIDs;
}

sub _CheckCertificate {
    my ( $Self, %Param ) = @_;

    for my $Needed ( qw(File Type) ) {
        if ( !$Param{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed!"
                );
            }
            return;
        }
    }

    for my $Needed ( qw(Content Filesize ContentType Filename) ) {
        if ( !$Param{File}->{$Needed} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Needed in File!"
                );
            }
            return;
        }
    }

    if ( !$Self->{ContentTypes}->{$Param{File}->{ContentType}} ) {
        if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid file!"
                );
            }
            return;
    }

    if (
        $Param{Type} eq 'Private'
        && !$Param{Passphrase}
    ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need Passphrase!"
            );
        }
        return;
    }

    return 1;
}

sub _GetCertificateAttributes {
    my ( $Self, %Param ) = @_;

    if ( !$Param{File} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need File!'
        );
        return;
    }

    my $File = $Param{File};

    my $Content = MIME::Base64::decode_base64( $File->{Content} );

    my $CacheKey = 'Certificate::'
        . ( $Param{ObjectType} ? $Param{ObjectType} . q{::} : q{} )
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
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Filename!",
        );
        return;
    }
    my $Attributes = $Self->_FetchAttributes( Filename => $Filename );

    if ( $Attributes->{Hash} ) {
        # my ($Private) = $Self->PrivateGet($Attributes);
        # if ($Private) {
        #     $Attributes->{Private} = 'Yes';
        # }
        # else {
        #     $Attributes->{Private} = 'No';
        # }
        $Attributes->{Type} = 'Cert';
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Can\'t add invalid certificate!'
        );
        return;
    }

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

sub _FetchAttributes {
    my ( $Self, %Param ) = @_;

    my $AttributesRef;
    my $Filename = $Param{Filename};

    # testing new solution
    my $OptionString = '-subject_hash '
        . '-issuer '
        . '-fingerprint -sha1 '
        . '-serial '
        . '-subject '
        . '-startdate '
        . '-enddate '
        . '-email '
        . '-modulus ';

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
        Subject     => 'subject=\s*(.*)',
        StartDate   => 'notBefore=(.*)',
        EndDate     => 'notAfter=(.*)',
        Email       => '([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4})',
        Modulus     => 'Modulus=(.*)',
    );

    # parse output string
    my @Attributes = split( /\n/sm, $Output );
    for my $Line (@Attributes) {

        # clean end spaces
        $Line =~ tr{\r\n}{}d;

        # look for every attribute by filter
        FILTER:
        for my $Filter ( sort keys %Filters ) {
            my @Matches = $Line =~ m{ \A $Filters{$Filter} \z }xms;

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

        my $D = sprintf('%02d', $Date[1]);
        my $M = q{};
        my $Y = $Date[3];

        MONTH_KEY:
        for my $MonthKey ( sort keys %Month ) {
            if ( $AttributesRef->{$DateType} =~ /$MonthKey/i ) {
                $M = $Month{$MonthKey};
                last MONTH_KEY;
            }
        }
        $AttributesRef->{"Short$DateType"} = "$Y-$M-$D";
    }

    return $AttributesRef;
}


sub _Init {
    my ( $Self, %Param ) = @_;

    $Self->{CertPath}    = '/etc/ssl/certs';
    $Self->{PrivatePath} = '/etc/ssl/private';
    $Self->{Bin}         = '/usr/bin/openssl';

    # valid content types
    $Self->{ContentTypes} = {
        'application/pkcs8'                 => 1,
        'application/pkcs10'                => 1,
        'application/pkix-cert'             => 1,
        'application/pkix-crl'              => 1,
        'application/pkcs7-mime'            => 1,
        'application/x-x509-ca-cert'        => 1,
        'application/x-x509-user-cert'      => 1,
        'application/x-pkcs7-crl'           => 1,
        'application/x-pem-file'            => 1,
        'application/x-pkcs12'              => 1,
        'application/x-pkcs7-certificates'  => 1,
        'application/x-pkcs7-certreqresp'   => 1
    };

    # make sure that we are getting POSIX (i.e. english) messages from openssl
    $Self->{Cmd} = "LC_MESSAGES=POSIX $Self->{Bin}";

    # ensure that there is a random state file that we can write to (otherwise openssl will bail)
    local $ENV{RANDFILE} = $Kernel::OM->Get('Config')->Get('TempDir') . '/.rnd';

    # prepend RANDFILE declaration to openssl cmd
    $Self->{Cmd} = "HOME="
        . $Kernel::OM->Get('Config')->Get('Home')
        . " RANDFILE=$ENV{RANDFILE} $Self->{Cmd}";

    return $Self->_Check();
}

=item Check()

check if environment is working

    my $Message = $CryptObject->Check();

=cut

sub _Check {
    my ( $Self, %Param ) = @_;

    my $Success = 1;
    if ( !-e $Self->{Bin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{Bin}!",
        );
        $Success = 0;
    }
    elsif ( !-x $Self->{Bin} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "$Self->{Bin} not executable!",
        );
        $Success = 0;
    }

    if ( !-e $Self->{CertPath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{CertPath}!",
        );
        $Success = 0;
    }
    elsif ( !-d $Self->{CertPath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{CertPath} directory!",
        );
        $Success = 0;
    }
    elsif ( !-w $Self->{CertPath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "$Self->{CertPath} not writable!",
        );
        $Success = 0;
    }

    if ( !-e $Self->{PrivatePath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{PrivatePath}!",
        );
        $Success = 0;
    }
    elsif ( !-d $Self->{PrivatePath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such $Self->{PrivatePath} directory!",
        );
        $Success = 0;
    }
    elsif ( !-w $Self->{PrivatePath} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "$Self->{PrivatePath} not writable!",
        );
        $Success = 0;
    }

    return $Success;
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
