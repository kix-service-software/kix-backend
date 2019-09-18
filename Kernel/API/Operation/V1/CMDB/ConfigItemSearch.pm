# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::CMDB::ConfigItemSearch - API CMDB Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform ConfigItemSearch Operation. This will return a class list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            ConfigItem => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my @ConfigItemList;

    # prepare search if given
    my %SearchParam;
    if ( IsHashRefWithData($Self->{Search}->{ConfigItem}) ) {
        foreach my $SearchType ( keys %{$Self->{Search}->{ConfigItem}} ) {
            my @SearchTypeResult;
            foreach my $SearchItem ( @{$Self->{Search}->{ConfigItem}->{$SearchType}} ) {
                my $Value = $SearchItem->{Value};
                my $Field = $SearchItem->{Field};

                # prepare field in case of sub-structure search
                if ( $Field =~ /\./ ) {
                    $Field = ( split(/\./, $Field) )[-1];
                }

                # prepare value
                if ( $SearchItem->{Operator} eq 'CONTAINS' ) {
                   $Value = '*' . $Value . '*';
                }
                elsif ( $SearchItem->{Operator} eq 'STARTSWITH' ) {
                   $Value = $Value . '*';
                }
                if ( $SearchItem->{Operator} eq 'ENDSWITH' ) {
                   $Value = '*' . $Value;
                }

                # do some special handling if field is an XML attribute
                if ( $SearchItem->{Field} =~ /Data\./ ) {
                    my %OperatorMapping = (
                        'EQ'  => '=',
                        'LT'  => '<',
                        'LTE' => '<=',
                        'GT'  => '>',
                        'GTE' => '>=',
                    );

                    # build search key of given field
                    my $SearchKey = "[1]{'Version'}[1]";
                    my @Parts = split(/\./, $SearchItem->{Field});
                    foreach my $Part ( @Parts[2..$#Parts] ) {
                        $SearchKey .= "{'" . $Part . "\'}[%]";
                    }

                    $Value =~ s/\*/%/g;

                    my @What = IsArrayRefWithData($SearchParam{What}) ? @{$SearchParam{What}} : (); 
                    if ( $OperatorMapping{$SearchItem->{Operator}} ) {
                        push(@What, { $SearchKey."{'Content'}" => { $OperatorMapping{$SearchItem->{Operator}}, $Value } });
                    }
                    else {
                        push(@What, { $SearchKey."{'Content'}" => $Value });
                    }
                    $SearchParam{What} = \@What;
                } 
                else {
                    $SearchParam{$Field} = $Value;
                }

                if ( $SearchType eq 'OR' ) {
                    # perform search for every attribute
                    my $SearchResult = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemSearchExtended(
                        %SearchParam,
                        UserID  => $Self->{Authorization}->{UserID},
                    );

                    # merge results
                    my @MergeResult = keys %{{map {($_ => 1)} (@SearchTypeResult, @{$SearchResult})}};
                    @SearchTypeResult = @MergeResult;

                    # clear SearchParam
                    %SearchParam = ();
                }
            }

            if ( $SearchType eq 'AND' ) {
                # perform ConfigItem search
                my $SearchResult = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemSearchExtended(
                    %SearchParam,
                    UserID  => $Self->{Authorization}->{UserID},
                );
                @SearchTypeResult = @{$SearchResult};
            }

            if ( !@ConfigItemList ) {
                @ConfigItemList = @SearchTypeResult;
            }
            else {
                # combine both results by AND
                # remove all IDs from type result that we don't have in this search
                my %SearchTypeResultHash = map { $_ => 1 } @SearchTypeResult;
                my @Result;
                foreach my $ConfigItemID ( @ConfigItemList ) {
                    push(@Result, $ConfigItemID) if !exists $SearchTypeResultHash{$ConfigItemID};
                }
                @ConfigItemList = @Result;
            }
        }
    }
    else {
        # perform ConfigItem search
        my $SearchResult = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->ConfigItemSearchExtended(
            UserID  => $Self->{Authorization}->{UserID},
        );
        @ConfigItemList = @{$SearchResult};
    }

	# get already prepared CI data from ConfigItemGet operation
    if ( IsArrayRefWithData(\@ConfigItemList) ) {  	  
        my $GetResult = $Self->ExecOperation(
            OperationType => 'V1::CMDB::ConfigItemGet',
            Data      => {
                ConfigItemID => join(',', sort @ConfigItemList),
            }
        );    

        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @DataList = IsArrayRefWithData($GetResult->{Data}->{ConfigItem}) ? @{$GetResult->{Data}->{ConfigItem}} : ( $GetResult->{Data}->{ConfigItem} );

        if ( IsArrayRefWithData(\@DataList) ) {
            return $Self->_Success(
                ConfigItem => \@DataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        ConfigItem => [],
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
