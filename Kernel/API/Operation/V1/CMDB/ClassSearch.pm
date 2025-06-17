# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
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
