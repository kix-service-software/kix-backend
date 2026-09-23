# --
# Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ClassSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::CMDB::ClassSearch - API CMDB Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'requiredPermission' => {
            Type     => 'HASH',
        }
    }
}

=item Run()

perform ClassSearch Operation. This will return a class list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ConfigItemClass => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $ClassIDList;

    # if UserType is Customer, than search all customer ConfigItems and retrieve classes from their
    my $IsCustomer = $Self->{Authorization}->{UserType} eq 'Customer';
    if ( $IsCustomer ) {
        my $ConfigItemSearchResult = $Self->ExecOperation(
            OperationType            => 'V1::CMDB::ConfigItemSearch',
            SuppressPermissionErrors => 1
        );

        if ( defined $ConfigItemSearchResult->{Data}->{ConfigItem} ) {
            my @ConfigItemClassIds = ();
            foreach my $ConfigItem ( @{ $ConfigItemSearchResult->{Data}->{ConfigItem} } ) {
                push(@ConfigItemClassIds, $ConfigItem->{ClassID}) unless grep{$_ == $ConfigItem->{ClassID}} @ConfigItemClassIds;
            }

            $ClassIDList = join(',', @ConfigItemClassIds);
        }

    } else {
        # get IDs of CI classes from General Catalog
        my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
            Class   => 'ITSM::ConfigItem::Class',
            Valid   => 0
        );

        if ( IsHashRefWithData($ItemList) ) {
            $ClassIDList = join(',', sort { $a <=> $b } keys %{$ItemList});
        }
    }

    # check for base permissions
    if (
        $ClassIDList
        && IsHashRefWithData($Param{Data}->{requiredPermission})
        && $Param{Data}->{requiredPermission}->{Permission}
    ) {
        my %BasePermissionClassIDs;

        my $UserID = $Self->{Authorization}->{UserID};
        if (
            $Param{Data}->{requiredPermission}->{Object}
            && $Param{Data}->{requiredPermission}->{Object} eq 'User'
        ) {
            # return empty list, when no user id is given for permission
            if ( !$Param{Data}->{requiredPermission}->{ObjectID} ) {
                return $Self->_Success(
                    ConfigItemClass => [],
                );
            }
            $UserID = $Param{Data}->{requiredPermission}->{ObjectID};
        }

        my $Result = $Kernel::OM->Get('ITSMConfigItem')->BasePermissionRelevantObjectIDList(
            UserID       => $UserID,
            UsageContext => $Self->{Authorization}->{UserType},
            Permission   => $Param{Data}->{requiredPermission}->{Permission},
        );

        if ( IsArrayRefWithData($Result) ) {
            # get intersection of avaiable ConfigItemClass list and base permission list
            my @ClassIDs = split(',', $ClassIDList);

            my @CombinedList = $Kernel::OM->Get('Main')->GetCombinedList(
                ListA => $Result,
                ListB => \@ClassIDs,
                Union => 0,
            );            

            %BasePermissionClassIDs = (
                %BasePermissionClassIDs,
                map { $_ => 1 } @CombinedList,
            );
        }

        if ( %BasePermissionClassIDs ) {
            $ClassIDList = join(',', sort { $a <=> $b } keys %BasePermissionClassIDs);
        } elsif ( $Result ne 1 ) {
            $ClassIDList = '';
        }
        else {
            my $HasPermission = $Kernel::OM->Get('User')->CheckResourcePermission(
                UserID              => $UserID,
                UsageContext        => $Self->{Authorization}->{UserType},
                Target              => '/system/cmdb/classes',
                RequestedPermission => $Param{Data}->{requiredPermission}->{Permission},
            );

            if ( !$HasPermission ) {
                $ClassIDList = '';
            }
        }

        $Self->AddCacheKeyExtension(
            Extension => ['requiredPermission']
        );
    }

	# get already prepared CI Class data from ClassGet operation
    if ( $ClassIDList ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::CMDB::ClassGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ClassID => $ClassIDList
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{ConfigItemClass} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{ConfigItemClass}) ? @{$GetResult->{Data}->{ConfigItemClass}} : ( $GetResult->{Data}->{ConfigItemClass} );
        }

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                ConfigItemClass => \@ResultList,
            )
        }

        $Self->AddCacheKeyExtension(
            Extension => ['requiredPermission']
        );
    }

    # return result
    return $Self->_Success(
        ConfigItemClass => [],
    );
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
