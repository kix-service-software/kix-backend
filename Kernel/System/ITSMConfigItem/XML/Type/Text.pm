# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::Text;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Config
    GeneralCatalog
    Log
    Role
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::Text - xml backend module

=head1 SYNOPSIS

All xml functions of text objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeTextBackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::Text');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ValueLookup()

get the text data of a version

    my $Value = $BackendObject->ValueLookup(
        Value => 11,  # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    return $Param{Value};
}

=item InternalValuePrepare()

prepare "external" value to "internal"

    my $InternalValue = $BackendObject->InternalValuePrepare(
        ClassID      => '...',
        Item         => {...},
        Value        => '...',
        UserID       => '...',
        UsageContext => '...',
    );

=cut

sub InternalValuePrepare {
    my ( $Self, %Param ) = @_;

    # check for relevant data for special handling
    if (
        $Param{ClassID}
        && ref( $Param{Definition} ) eq 'HASH'
        && $Param{Definition}->{Key}
        && $Param{UserID}
        && $Param{UsageContext}
    ) {
        my $EncryptedTextAuthority = $Self->_CheckEncryptedTextAuthority(
            ClassID      => $Param{ClassID},
            Attribute    => $Param{Definition}->{Key},
            UserID       => $Param{UserID},
            UsageContext => $Param{UsageContext}
        );

        # handle encrypted text with authority
        if ( $EncryptedTextAuthority ) {
            # check for defined not empty string
            if (
                defined( $Param{Value} )
                && $Param{Value} ne ''
            ) {
                $Param{Value} = $Self->_Encrypt( $Param{Value} );
            }
        }
        # handle encrypted text without authority
        elsif ( defined( $EncryptedTextAuthority ) ) {
            $Param{Value} = { RestorePreviousValue => 1 };
        }
    }

    return $Param{Value};
}

=item ExternalValuePrepare()

prepare "internal" value to "external"

    my $ExternalValue = $BackendObject->ExternalValuePrepare(
        ClassID      => '...',
        Item         => {...},
        Value        => '...',
        UserID       => '...',
        UsageContext => '...',
    );

=cut

sub ExternalValuePrepare {
    my ( $Self, %Param ) = @_;

    # return undefined value if provided value is undefined
    return if ( !defined( $Param{Value} ) );

    # return empty string if provided value is an empty string
    return if ( $Param{Value} eq '' );

    # check for relevant data for special handling
    if (
        $Param{ClassID}
        && ref( $Param{Item} ) eq 'HASH'
        && $Param{Item}->{Key}
        && $Param{UserID}
        && $Param{UsageContext}
    ) {
        my $EncryptedTextAuthority = $Self->_CheckEncryptedTextAuthority(
            ClassID      => $Param{ClassID},
            Attribute    => $Param{Item}->{Key},
            UserID       => $Param{UserID},
            UsageContext => $Param{UsageContext}
        );

        # handle encrypted text with authority
        if ( $EncryptedTextAuthority ) {
            # check for hex code
            if ( $Param{Value} =~ m/^[a-f0-9]+$/ ) {
                $Param{Value} = $Self->_Decrypt( $Param{Value} );
            }
        }
        # handle encrypted text without authority
        elsif ( defined( $EncryptedTextAuthority ) ) {
            $Param{Value} = '******';
        }
    }

    return $Param{Value};
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    # return undefined value if provided value is undefined
    return if ( !defined( $Param{Value} ) );

    # return empty string if provided value is an empty string
    return if ( $Param{Value} eq '' );

    # check for relevant data for special handling
    if (
        $Param{ClassID}
        && ref( $Param{Item} ) eq 'HASH'
        && $Param{Item}->{Key}
        && $Param{UserID}
        && $Param{UsageContext}
    ) {
        my $EncryptedTextAuthority = $Self->_CheckEncryptedTextAuthority(
            ClassID      => $Param{ClassID},
            Attribute    => $Param{Item}->{Key},
            UserID       => $Param{UserID},
            UsageContext => $Param{UsageContext}
        );

        # handle encrypted text with authority
        if ( $EncryptedTextAuthority ) {
            # check for hex code
            if ( $Param{Value} =~ m/^[a-f0-9]+$/ ) {
                $Param{Value} = $Self->_Decrypt( $Param{Value} );
            }
        }
        # handle encrypted text without authority
        elsif ( defined( $EncryptedTextAuthority ) ) {
            $Param{Value} = '******';
        }
    }

    return $Param{Value};
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if ( !defined( $Param{Value} ) );
    return ( $Param{Value} );
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if ( !defined( $Param{Value} ) );

    # check for relevant data for special handling
    if (
        $Param{ClassID}
        && ref( $Param{Item} ) eq 'HASH'
        && $Param{Item}->{Key}
        && $Param{UserID}
        && $Param{UsageContext}
    ) {
        my $EncryptedTextAuthority = $Self->_CheckEncryptedTextAuthority(
            ClassID      => $Param{ClassID},
            Attribute    => $Param{Item}->{Key},
            UserID       => $Param{UserID},
            UsageContext => $Param{UsageContext},
        );

        # handle encrypted text with authority
        if ( $EncryptedTextAuthority ) {
            # check for defined not empty string
            if (
                defined( $Param{Value} )
                && $Param{Value} ne ''
            ) {
                $Param{Value} = $Self->_Encrypt( $Param{Value} );
            }
        }
        # handle encrypted text without authority
        elsif ( defined( $EncryptedTextAuthority ) ) {
            $Param{Value} = { RestorePreviousValue => 1 };
        }
    }

    return $Param{Value};
}

=item ValidateValue()

validate given value for this particular attribute type

    my $Value = $BackendObject->ValidateValue(
        Value => ..., # (optional)
    );

=cut

sub ValidateValue {
    my ( $Self, %Param ) = @_;

    # check length
    if (
        defined( $Param{Input}->{MaxLength} )
        && $Param{Input}->{MaxLength}
        && length( $Param{Value} ) > $Param{Input}->{MaxLength}
        )
    {
        return 'exceeds maximum length';
    }

    return 1;
}


sub _InitEncryptedTextConfig {
    my ( $Self, %Param ) = @_;

    # init encrypted text config
    $Self->{EncryptedText} = {};

    # get config
    my $XMLTypeRef = $Kernel::OM->Get('Config')->Get('ITSM::ConfigItem::XML::Type::Text');
    if (
        IsHashRefWithData( $XMLTypeRef )
        && IsHashRefWithData( $XMLTypeRef->{EncryptedText} )
    ) {
        # isolate encrypted text config
        my $EncryptedTextRef = $XMLTypeRef->{EncryptedText};

        # get classes for lookup
        my $ClassList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
            Class => 'ITSM::ConfigItem::Class',
            Valid => 0,
        ) || {};

        # invert the hash to have the classes names as keys
        my %ClassName2ID = reverse( %{ $ClassList } );

        my %RoleList = $Kernel::OM->Get('Role')->RoleList(
            Valid => 0,
        );

        # invert the hash to have the role names as keys
        my %RoleName2ID = reverse( %RoleList );

        # process config
        ENTRY:
        for my $Entry ( keys( %{ $EncryptedTextRef } ) ) {
            # skip empty entries
            next ENTRY if ( !$EncryptedTextRef->{ $Entry } );

            # get class and attribute
            my ( $Class, $Attribute ) = split( ':::', $Entry );
            next ENTRY if (
                !$Class
                || !$ClassName2ID{ $Class }
                || !$Attribute
            );

            # get role array
            my @Roles = split( /\s*,\s*/, $EncryptedTextRef->{ $Entry } );

            # process roles
            ROLE:
            for my $Role ( @Roles ) {
                next ROLE if (
                    !$Role
                    || !$RoleName2ID{ $Role }
                );
            
                # set config
                $Self->{EncryptedText}->{ $ClassName2ID{ $Class } }->{ $Attribute }->{ $RoleName2ID{ $Role } } = 1;
            }
        }
    }

    return 1;
}

sub _CheckEncryptedTextAuthority {
    my ( $Self, %Param ) = @_;

    # check for previous check
    my $EncryptedTextAuthorityKey = $Param{ClassID} . '::' . $Param{Attribute} . '::' . $Param{UserID} . '::' . $Param{UsageContext};
    if ( exists( $Self->{EncryptedTextAuthority}->{ $EncryptedTextAuthorityKey } ) ) {
        return $Self->{EncryptedTextAuthority}->{ $EncryptedTextAuthorityKey };
    }

    # init check result with undefined result
    $Self->{EncryptedTextAuthority}->{ $EncryptedTextAuthorityKey } = undef;

    # check if we need to init the encrypted text config
    if ( ref( $Self->{EncryptedText} ) ne 'HASH' ) {
        $Self->_InitEncryptedTextConfig();
    }

    # check for relevant class and attribute
    if ( ref( $Self->{EncryptedText}->{ $Param{ClassID} }->{ $Param{Attribute} } ) eq 'HASH' ) {
        # user id 1 has always authority
        if ( $Param{UserID} == 1 ) {
            $Self->{EncryptedTextAuthority}->{ $EncryptedTextAuthorityKey } = 1;
        }
        # handle normal user
        else {
            # user has no authority without matching role
            $Self->{EncryptedTextAuthority}->{ $EncryptedTextAuthorityKey } = 0;

            # get assigned roles of user
            my @RoleIDs = $Kernel::OM->Get('Role')->UserRoleList(
                UserID       => $Param{UserID},
                UsageContext => $Param{UsageContext},
                Valid        => 0,
            );

            # check assigned roles
            ROLE:
            for my $RoleID ( @RoleIDs ) {
                # matching role, user has authority
                if ( $Self->{EncryptedText}->{ $Param{ClassID} }->{ $Param{Attribute} }->{ $RoleID } ) {
                    $Self->{EncryptedTextAuthority}->{ $EncryptedTextAuthorityKey } = 1;

                    last ROLE;
                }
            }
        }
    }

    # return authority
    return $Self->{EncryptedTextAuthority}->{ $EncryptedTextAuthorityKey };
}

sub _Decrypt {
    my ( $Self, $EncrptedText ) = @_;

    return '' if ( !$EncrptedText );

    my $Length = length( $EncrptedText ) * 4;

    # convert from hex code
    my $Transfer = pack( "h$Length", $EncrptedText );

    # get bit code
    $Transfer = unpack( "B$Length", $Transfer );

    # switch bits
    $Transfer =~ s/1/A/g;
    $Transfer =~ s/0/1/g;
    $Transfer =~ s/A/0/g;

    # get ascii code
    my $DecryptedText = pack( "B$Length", $Transfer );

    return $DecryptedText;
}

sub _Encrypt {
    my ( $Self, $DecryptedText ) = @_;

    return '' if ( !$DecryptedText );

    my $Length = length( $DecryptedText ) * 8;
    chomp $DecryptedText;

    # get bit code
    my $Transfer = unpack( "B$Length", $DecryptedText );

    # switch bits
    $Transfer =~ s/1/A/g;
    $Transfer =~ s/0/1/g;
    $Transfer =~ s/A/0/g;

    # get ascii code
    $Transfer = pack( "B$Length", $Transfer );

    # convert to hex code
    my $EncrptedText = unpack( "h$Length", $Transfer );

    return $EncrptedText;
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
