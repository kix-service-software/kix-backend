# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::LDAPUtils;

use strict;
use warnings;

use utf8;

use MIME::Base64 qw(encode_base64);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Encode',
    'Main',
    'Log',
    'Organisation',
);

=head1 NAME

Kernel::System::LDAPUtils - Utilities for handling ldap data

=head1 SYNOPSIS

A module with utilities to handle ldap data.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $HTMLUtilsObject = $Kernel::OM->Get('LDAPUtils');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get debug level from parent
    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

=item Convert()

Convert a string from a charset to another

    my $ConvertedText = $LDAPUtilsObject->Convert(
        Text => 'abc',
        From => 'utf-8',        # source charset
        To   => 'iso-8859-1'    # target charset
    );

=cut

sub Convert {
    my ( $Self, %Param ) = @_;

    # no convert needed when text is not defined
    return if ( !defined( $Param{Text} ) );

    # when source or target charset is not given, only set utf8-flag
    if (
        !$Param{From}
        || !$Param{To}
    ) {
        $Kernel::OM->Get('Encode')->EncodeInput( \$Param{Text} );
        return $Param{Text};
    }

    # convert charset of text
    return $Kernel::OM->Get('Encode')->Convert(
        Text => $Param{Text},
        From => $Param{From},
        To   => $Param{To},
    );
}

=item DetectMIMETypeFromBase64()

Try to detect the MIME type of a given base64 encoded content by checking "magic bytes"

    my $MIMEType = $LDAPUtilsObject->DetectMIMETypeFromBase64(
        Content => '/9j/...',           # base64 encoded content
    );

=cut

sub DetectMIMETypeFromBase64 {
    my ( $Self, %Param ) = @_;

    # no detection possible when content is not defined
    return if ( !defined( $Param{Content} ) );

    # prepare signature lookup ("magic bytes")
    my %Signatures = (
      'R0lGODdh'    => 'image/gif',
      'R0lGODlh'    => 'image/gif',
      'iVBORw0KGgo' => 'image/png',
      '/9j/'        => 'image/jpeg'
    );

    # process signature lookup
    for my $Signature ( keys( %Signatures ) ) {
        # though it shouldn't be, there CAN be leading spaces from our b64 encoding...
        if( $Param{Content} =~ /^\s*$Signature/ ) {
            return $Signatures{ $Signature };
        }
    }

    return;
}

=item ApplyContactMappingToLDAPResult()

Apply a mapping to a ldap 

    my $MappedData = $LDAPUtilsObject->ApplyContactMappingToLDAPResult(
        LDAPSearch           => $LDAPSearch,      # a Net::LDAP::Search object
        Mapping              => {
            'Email' => 'mail',
        },
        LDAPCharset          => 'iso-8859-1',
        FallbackUnknownOrgID => 1
    );

=cut

sub ApplyContactMappingToLDAPResult {
    my ( $Self, %Param ) = @_;

    # check for expected ldap object
    if ( ref( $Param{LDAPSearch} ) ne 'Net::LDAP::Search' ) {
        $Kernel::OM->Get('Log')->Log(
            LogPrefix => 'Kernel::System::LDAPUtils',
            Priority  => 'error',
            Message   => 'Net::System::LDAPUtils object required',
        );

        return;
    }

    # check for given mapping
    if ( !IsHashRefWithData( $Param{Mapping} ) ) {
        $Kernel::OM->Get('Log')->Log(
            LogPrefix => 'Kernel::System::LDAPUtils',
            Priority  => 'error',
            Message   => 'Got invalid mapping',
        );

        return;
    }

    # check for fallback for unknown organisations
    if ( !$Param{FallbackUnknownOrgID} ) {
        $Kernel::OM->Get('Log')->Log(
            LogPrefix => 'Kernel::System::LDAPUtils',
            Priority  => 'error',
            Message   => 'Fallback for unknown organisation required',
        );

        return;
    }

    my %MappedData;
    for my $Entry ( $Param{LDAPSearch}->all_entries() ) {
        ATTRIBUTE_KEY:
        for my $Key ( keys( %{ $Param{Mapping} } ) ) {
            my @KeyValues = ();
            my $Value;

            my $AttributeEntries = $Param{Mapping}->{ $Key };
            if ( !IsArrayRef( $AttributeEntries ) ) {
                $AttributeEntries = [ $AttributeEntries ];
            }

            ATTRIBUTE_ENTRY:
            for my $AttributeEntry ( @{ $AttributeEntries } ) {
                # reset attribute value array
                my @AttributeValues = ();

                # set a fixed value...
                if ( $AttributeEntry =~ /^SET:/i ) {
                    $Value = substr( $AttributeEntry, 4 );
                    $Value =~ s/^\s+|\s+$//g;
                }
                # set a value concatenation of multiple attributes
                # LDAP attributes are marked with curly brackets
                elsif ( $AttributeEntry =~ /^CONCAT\:(.+)$/i ) {
                    $Value = $1;
                    $Value =~ s/^\s+|\s+$//g;

                    while ( $Value =~ /\{(.+?)\}/ ) {
                        my $Attribute = $1;

                        my $ValuePart = $Entry->get_value( $Attribute ) // '';
                        $ValuePart    =~ s/^\s+|\s+$//g;

                        $Value =~s/\{\Q$Attribute\E\}/$ValuePart/g;
                    }
                }
                # set a value concatenation of multiple attributes with joined values of array attributes
                # LDAP attributes are marked with curly brackets
                # join separator is written in square brackets after ARRAYJOIN
                elsif ( $AttributeEntry =~ /^ARRAYJOIN\[(.+)\]\:(.+)$/i ) {
                    my $SepStrg = $1;
                    $Value      = $2;
                    $Value      =~ s/^\s+|\s+$//g;

                    while ( $Value =~ /\{(.+?)\}/ ) {
                        my $Attribute = $1;

                        my @ValuePartArray = $Entry->get_value( $Attribute );
                        my $ValuePart      = join( $SepStrg, @ValuePartArray ) // '';
                        $ValuePart         =~ s/^\s+|\s+$//g;

                        $Value =~s/\{\Q$Attribute\E\}/$ValuePart/g;
                    }
                }
                # get a single value of an array attribute on a specified index
                # index starting with 0 is written in square brackets after ARRAYINDEX
                elsif ( $AttributeEntry =~ /^ARRAYINDEX\[(.+)\]\:(.+)$/i ) {
                    my $Index     = $1;
                    my $Attribute = $2;

                    my @AttributeArray = $Entry->get_value( $Attribute );

                    $Value = $AttributeArray[ $Index ] // '';
                }
                # handle binary attributes (make it b64...)
                elsif ( $AttributeEntry =~ /^TOBASE64:/i) {
                    my $Attribute = substr( $AttributeEntry, 9 );
                    $Attribute    =~ s/^\s+|\s+$//g;

                    my $LDAPValue = $Entry->get_value( $Attribute );
                    if ( defined( $LDAPValue ) ) {
                        $Value = encode_base64( $LDAPValue );
                    }
                    else {
                        $Value = '';
                    }
                }
                # just set the attribute...
                elsif ( $Entry->get_value( $AttributeEntry ) ) {
                    @AttributeValues = $Entry->get_value( $AttributeEntry );
                    $Value           = $Entry->get_value( $AttributeEntry );
                    $Value           =~ s/^\s+|\s+$//g;
                }
                # set empty if no value can be retrieved or the attribute is not available..
                else {
                    $Value = '';
                }

                # handle array values for specific attributes
                if (
                    scalar( @AttributeValues ) > 1
                    && (
                        $Key eq 'Email'
                        || $Key eq 'OrganisationIDs'
                    )
                ) {
                    # prepare values
                    for my $AttributeValue ( @AttributeValues ) {
                        $AttributeValue =~ s/^\s+|\s+$//g;
                        $AttributeValue = $Self->Convert(
                            Text => $AttributeValue,
                            From => $Param{LDAPCharset},
                            To   => 'utf-8',
                        );
                    }

                    # handle Email
                    if ( $Key eq 'Email' ) {
                        EMAIL:
                        for my $Email ( @AttributeValues ) {
                            # skip empty entries
                            next EMAIL if ( !$Email );

                            # cleanup SMTP prefix ('SMTP:' and 'smtp:')
                            $Email =~ s/^SMTP://i;

                            # add email to list
                            push( @KeyValues, $Email );
                        }

                        # skip further default handling
                        next ATTRIBUTE_ENTRY;
                    }

                    # handle OrganisationIDs
                    if ( $Key eq 'OrganisationIDs' ) {
                        ORG:
                        for my $CurrOrg ( @AttributeValues ) {
                            # lookup value as organisation number
                            my $FoundOrgID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                                Number => $CurrOrg,
                                Silent => 1,
                            );

                            if ( !$FoundOrgID ) {
                                # lookup value as organisation name
                                $FoundOrgID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                                    Name   => $CurrOrg,
                                    Silent => 1,
                                );
                            }

                            if ( !$FoundOrgID ) {
                                # lookup value as organsation id
                                my $FoundOrgNumber = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                                    ID     => $CurrOrg,
                                    Silent => 1,
                                );
                                if ( $FoundOrgNumber ) {
                                    $FoundOrgID = $CurrOrg;
                                }
                                # unknown organisation id, use configured fallback id
                                else {
                                    $FoundOrgID = $Param{FallbackUnknownOrgID};
                                }
                            }

                            # add found id to list
                            if ( $FoundOrgID ) {
                                push( @KeyValues, $FoundOrgID );
                            }
                        }

                        # skip further default handling
                        next ATTRIBUTE_ENTRY;
                    }
                }

                # ensure proper encoding, i.e. utf-8
                $Value = $Self->Convert(
                    Text => $Value,
                    From => $Param{LDAPCharset},
                    To   => 'utf-8',
                );

                # specific handling for PrimaryOrganisationID and OrganisationIDs
                # lookup organisation id
                if (
                    $Key eq 'PrimaryOrganisationID'
                    || $Key eq 'OrganisationIDs'
                ) {
                    if ( $Value ) {
                        my $FoundOrgID;

                        # check if fixed value (organisation id) was given
                        if ( $AttributeEntry !~ /^SET:/i ) {
                            # lookup value as organisation number
                            $FoundOrgID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                                Number => $Value,
                                Silent => 1,
                            );

                            if (!$FoundOrgID ) {
                                # lookup value as organisation name
                                $FoundOrgID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                                    Name   => $Value,
                                    Silent => 1,
                                );
                            }

                            # use found id as value
                            if ( $FoundOrgID ) {
                                $Value = $FoundOrgID;
                            }
                        }

                        if ( !$FoundOrgID ) {
                            # lookup value as organsation id
                            my $FoundOrgNumber = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                                ID     => $Value,
                                Silent => 1,
                            );

                            # unknown organisation id, use configured fallback id
                            if ( !$FoundOrgNumber ) {
                                $Value = $Param{FallbackUnknownOrgID};
                            }
                        }
                    }
                    else {
                        $Value = $Param{FallbackUnknownOrgID};
                    }
                }
                # special handling for Email attributes
                elsif ( $Key =~ m/^Email/ ) {
                    if ( $Value ) {
                        # cleanup SMTP prefix ('SMTP:' and 'smtp:')
                        $Value =~ s/^SMTP://i;
                    }
                }

                # accept multiple values when mapping has an array ref
                # enforce array structure for attribute Email and OrganisationIDs
                if (
                    $Key eq 'Email'
                    || $Key eq 'OrganisationIDs'
                    || IsArrayRef( $Param{Mapping}->{ $Key } )
                ) {
                    push( @KeyValues, $Value );
                }
                else {
                    $MappedData{ $Key } = $Value;
                }
            }

            # when key is not set by single value, use value array
            if ( !defined( $MappedData{ $Key } ) ) {
                # make sure entries of Email and OrganisationIDs are unique
                if (
                    $Key eq 'Email'
                    || $Key eq 'OrganisationIDs'
                ) {
                    @KeyValues = $Kernel::OM->Get('Main')->GetUnique(@KeyValues);
                }
                
                # special handling fpr attribute Email
                if ( $Key eq 'Email' ) {
                    my $EmailIndex = 0;
                    EMAIL:
                    for my $Email ( @KeyValues ) {
                        # skip empty entires
                        next EMAIL if ( !$Email );

                        if ( !$EmailIndex ) {
                            $MappedData{'Email'} = $Email;
                        }
                        else {
                            $MappedData{ 'Email' . $EmailIndex } = $Email;
                        }

                        $EmailIndex += 1;
                    }
                }
                # default handling
                else {
                    $MappedData{ $Key } = \@KeyValues;
                }
            }

        }
    }

    return \%MappedData;
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
