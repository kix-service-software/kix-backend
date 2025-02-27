# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Object::ConfigItem;

use strict;
use warnings;

use base qw(
    Kernel::System::HTMLToPDF::Object::Common
);

our @ObjectDependencies = qw(
    ConfigItem
);

use Kernel::System::VariableCheck qw(:all);

sub GetParams {
    my ( $Self, %Param) = @_;

    return {
        IDKey     => 'ConfigItemID',
        NumberKey => 'Number'
    };
}

sub GetPossibleExpands {
    my ( $Self, %Param) = @_;

    return [
        'Version',
        'XMLAttributes',
        'XMLStructure',
        'XMLContents'
    ];
}

sub CheckParams {
    my ( $Self, %Param) = @_;

    if (
        !$Param{ConfigItemID}
        && !$Param{Number}
    ) {
        return {
            error => "No given ConfigItemID or Number!"
        }
    }

    return 1;
}

sub DataGet {
    my ($Self, %Param) = @_;

    my $ConfigItem;
    my %Filters;
    my %Expands;

    if ( IsArrayRefWithData($Param{Expands}) ) {
        %Expands = map { $_ => 1 } @{$Param{Expands}};
    }
    elsif( $Param{Expands} ) {
        %Expands = map { $_ => 1 } split( /[,]/sm, $Param{Expands});
    }

    my %ExpendFunc = (
        Version       => '_GetVersion',
        XMLStructure  => '_GetStructure',
        XMLAttributes => '_GetAttributes',
        XMLContents   => '_GetContents',
    );

    if (
        $Param{Filters}
        && $Param{Filters}->{ConfigItem}
        && IsHashRefWithData($Param{Filters}->{ConfigItem})
    ) {
        %Filters = %{$Param{Filters}->{ConfigItem}};
    }

    my $ConfigItemID = $Param{ConfigItemID};
    if ( !$Param{Data} ) {
        if ( $Param{Number} ) {
            $ConfigItemID = $Kernel::OM->Get('ConfigItem')->ConfigItemLookup(
                ConfigItemNumber => $Param{Number},
            );

            if ( !$ConfigItemID ) {
                return {
                    error=> "ConfigItem '$Param{Number}' not found!"
                };
            }
        }

        $ConfigItem = $Kernel::OM->Get('ConfigItem')->ConfigItemGet(
            ConfigItemID => $ConfigItemID
        );

        if ( !IsHashRefWithData( $ConfigItem ) ) {
            return {
                error=> "ConfigItem '$ConfigItemID' not found!"
            };
        }
    }
    else {
        $ConfigItem = $Param{Data};
    }

    # copied CreateBy and ChangeBy before replacing
    $ConfigItem->{CreateByID} = $ConfigItem->{CreateBy};
    $ConfigItem->{ChangeByID} = $ConfigItem->{ChangeBy};

    # replaces by fullname
    for my $Key ( qw(CreateBy ChangeBy) ) {
        my $ID = $ConfigItem->{$Key};
        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            UserID => $ID
        );

        if ( %Contact ) {
            $ConfigItem->{$Key} = $Contact{Fullname};
        }
    }

    if ( %Expands ) {
        for my $Expand ( keys %Expands ) {
            my $Function = $ExpendFunc{$Expand};

            next if !$Function;

            $Self->$Function(
                Expands  => $Expands{$Expand} || 0,
                ObjectID => $ConfigItem->{ConfigItemID},
                UserID   => $Param{UserID},
                Data     => $ConfigItem,
                Type     => 'Asset'
            );
        }
    }

    if ( %Filters ) {
        my $Match = $Self->_Filter(
            Data   => {
                %{$ConfigItem}
            },
            Filter => \%Filters
        );

        return if !$Match;
    }

    return $ConfigItem;
}

sub ReplaceableLabel {
    my ( $Self, %Param ) = @_;

    return {
        CurDeplState  => 'Deployment State',
        CurInciState  => 'Incident State',
        ConfigItemID  => 'Asset ID',
        VersionNumber => 'Version No.',
        VersionID     => 'Version ID'
    };
}

sub _GetVersion {
    my ( $Self, %Param ) = @_;

    return 1 if !$Param{Expands};
    return 1 if IsHashRefWithData($Param{Data}->{Expands}->{Version});

    my $VersionRef = $Kernel::OM->Get('ConfigItem')->VersionGet(
        ConfigItemID => $Param{ObjectID},
        XMLDataGet   => 0
    );

    delete $VersionRef->{XMLDefinition};
    delete $VersionRef->{XMLData};
    $VersionRef->{VersionNumber} = $Kernel::OM->Get('ConfigItem')->VersionCount(
        ConfigItemID => $Param{ObjectID}
    );
    $VersionRef->{CreateByID} = $VersionRef->{CreateBy};

    for my $Key ( qw(CreateBy) ) {
        next if !$VersionRef->{$Key};
        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            UserID => $VersionRef->{$Key}
        );

        if ( %Contact ) {
            $VersionRef->{$Key} = $Contact{Fullname};
        }
    }

    $Param{Data}->{Expands}->{Version} = $VersionRef;

    return 1;
}

sub _GetAttributes {
    my ( $Self, %Param ) = @_;

    return 1 if !$Param{Expands};
    return 1 if IsHashRefWithData($Param{Data}->{Expands}->{XMLAttributes});

    my $VersionRef = $Kernel::OM->Get('ConfigItem')->VersionGet(
        ConfigItemID => $Param{ObjectID},
        XMLDataGet   => 1
    );

    my %XMLAttr;
    my @XMLStructure;
    $Self->_XMLDataGet(
        XMLDefinition  => $VersionRef->{XMLDefinition},
        XMLData        => $VersionRef->{XMLData}->[1]->{Version}->[1],
        Result         => \%XMLAttr,
        OnlyAttributes => 1
    );

    $Param{Data}->{Expands}->{XMLAttributes} = \%XMLAttr;

    return 1;
}

sub _GetContents {
    my ( $Self, %Param ) = @_;

    return 1 if !$Param{Expands};
    return 1 if IsHashRefWithData($Param{Data}->{Expands}->{XMLContents});

    my $VersionRef = $Kernel::OM->Get('ConfigItem')->VersionGet(
        ConfigItemID => $Param{ObjectID},
        XMLDataGet   => 1
    );

    my %XMLAttr;
    my @XMLStructure;
    $Self->_XMLDataGet(
        XMLDefinition  => $VersionRef->{XMLDefinition},
        XMLData        => $VersionRef->{XMLData}->[1]->{Version}->[1],
        Result         => \%XMLAttr,
        OnlyContents   => 1
    );

    $Param{Data}->{Expands}->{XMLContents} = \%XMLAttr;

    return 1;
}

sub _GetStructure {
    my ( $Self, %Param ) = @_;

    return 1 if !$Param{Expands};
    return 1 if IsArrayRefWithData($Param{Data}->{Expands}->{XMLStructure});

    my $VersionRef = $Kernel::OM->Get('ConfigItem')->VersionGet(
        ConfigItemID => $Param{ObjectID},
        XMLDataGet   => 1
    );

    my @XMLStructure;
    $Self->_XMLDataGet(
        XMLDefinition => $VersionRef->{XMLDefinition},
        XMLData       => $VersionRef->{XMLData}->[1]->{Version}->[1],
        Result        => \@XMLStructure,
        OnlyStructure => 1
    );

    $Param{Data}->{Expands}->{XMLStructure} = \@XMLStructure;

    return 1;
}

sub _XMLDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if !$Param{XMLData};
    return if ref $Param{XMLData} ne 'HASH';
    return if !$Param{XMLDefinition};
    return if ref $Param{XMLDefinition} ne 'ARRAY';

    if ( $Param{Prefix} ) {
        $Param{Prefix} .= q{::};
    }
    $Param{Prefix} ||= q{};
    $Param{Level}  ||= 0;

    ITEM:
    for my $Item ( @{ $Param{XMLDefinition} } ) {
        COUNTER:
        for my $Counter ( 1 .. $Item->{CountMax} ) {

            # create key
            my $Key        = $Param{Prefix} . $Item->{Key} . q{::} . $Counter;
            my $ContentKey = $Param{Prefix} . $Item->{Key};

            # prepare value
            if (defined $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}) {

                my %ResultOpt;
                if ( $Item->{Input}->{Type} eq 'CIClassReference' ) {
                    %ResultOpt = (
                        Result => 'DisplayValue'
                    );
                }

                my $Value = $Kernel::OM->Get('ITSMConfigItem')->XMLExportValuePrepare(
                    Item   => $Item,
                    Value  => $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content},
                    Result => 'DisplayValue'    # returns a prepared value of reference objects, but not all can handle this
                                                # currently only CIClassReference, Contact and Organisation
                );

                if ( $Param{OnlyStructure} ) {
                    my %Additional;
                    if ( $Item->{Input}->{Type} eq 'DateTime' ) {
                        $Additional{IsDateTime} = 1;
                    }
                    elsif ( $Item->{Input}->{Type} eq 'Date' ) {
                        $Additional{IsDate} = 1;
                    }

                    push (
                        @{ $Param{Result} },
                        {
                            Key   => $Item->{Name},
                            Value => $Value,
                            Class => 'PL' . $Param{Level},
                            %Additional
                        }
                    );
                }
                elsif ( $Param{OnlyAttributes} ) {
                    $Param{Result}->{$Key} = $Value;
                }
                elsif ( $Param{OnlyContents} ) {
                    push(
                        @{$Param{Result}->{$ContentKey}},
                        $Param{XMLData}->{ $Item->{Key} }->[$Counter]->{Content}
                    );
                }
            }

            next COUNTER if !$Item->{Sub};

            my @SubStructure;
            # start recursion, if "Sub" was found
            $Self->_XMLDataGet(
                %Param,
                XMLDefinition => $Item->{Sub},
                XMLData       => $Param{XMLData}->{ $Item->{Key} }->[$Counter],
                Result        => $Param{OnlyStructure} ? \@SubStructure : $Param{Result},
                Prefix        => $Key,
                Level         => $Param{Level} + 1
            );

            if (
                $Param{OnlyStructure}
                && @SubStructure
            ) {
                if ( $Item->{Input}->{Type} eq 'Dummy' ) {
                    push (
                        @{ $Param{Result} },
                        {
                            Key     => $Item->{Name},
                            FullRow => 1,
                            Class   => 'DL' . $Param{Level}
                        }
                    );
                }
                push (
                    @{ $Param{Result} },
                    @SubStructure
                );
            }
        }
    }

    return 1;
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