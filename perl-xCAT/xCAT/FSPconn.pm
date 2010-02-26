# IBM(c) 2007 EPL license http://www.eclipse.org/legal/epl-v10.html

package xCAT::FSPconn;
use strict;
use Getopt::Long;
use xCAT::PPCcli qw(SUCCESS EXPECT_ERROR RC_ERROR NR_ERROR);
use xCAT::Usage;
use Data::Dumper;
use xCAT::Utils;

##############################################
# Globals
##############################################
my %method = (
    mkhwconn => \&mkhwconn_parse_args,
#   lshwconn => \&lshwconn_parse_args,
    rmhwconn => \&rmhwconn_parse_args,
);
##########################################################################
# Parse the command line for options and operands
##########################################################################
sub parse_args {

    my $request = shift;
    my $cmd = $request->{command};
    ###############################
    # Invoke correct parse_args
    ###############################

    my $result = $method{$cmd}( $request, $request->{arg});
    return( $result );
}

##########################################################################
# Parse arguments for mkhwconn
##########################################################################
sub mkhwconn_parse_args
{
    my $request = shift;
    my $args    = shift;
    my %opt = ();

    local *usage = sub {
        my $usage_string = xCAT::Usage->getUsage("mkhwconn");
        return( [ $_[0], $usage_string] );
    };
    #############################################
    # Process command-line arguments
    #############################################
    if ( !defined( $args )) {
        return(usage( "No command specified" ));
    }

    local @ARGV = ref($args) eq 'ARRAY'? @$args:();
    $Getopt::Long::ignorecase = 0;
    Getopt::Long::Configure( "bundling" );

    if ( !GetOptions( \%opt, qw(V|verbose h|help t T=i p=s P=s) )) {
        return( usage() );
    }
    return usage() if ( exists $opt{h});

    if ( exists $opt{t} and exists $opt{p})
    {
        return( usage('Flags -t and -p cannot be used together.'));
    }

    if ( exists $opt{P} and ! exists $opt{p})
    {
        return( usage('Flags -P can only be used when flag -p is specified.'));
    }

    ##########################################
    # Check if CECs are controlled by a frame
    ##########################################
    my $nodes = $request->{node};
    my $ppctab  = xCAT::Table->new( 'ppc' );
    my $nodetypetab = xCAT::Table->new( 'nodetype');
    my $vpdtab = xCAT::Table->new( 'vpd');
    my @bpa_ctrled_nodes = ();
    my @no_type_nodes    = ();
    my @frame_members    = ();
    if ( $ppctab)
    {
        for my $node ( @$nodes)
        {
            my $node_parent = undef;
            my $nodetype    = undef;
            my $nodetype_hash    = $nodetypetab->getNodeAttribs( $node,[qw(nodetype)]);
            my $node_parent_hash = $ppctab->getNodeAttribs( $node,[qw(parent)]);
            $nodetype    = $nodetype_hash->{nodetype};
            $node_parent = $node_parent_hash->{parent};
            if ( !$nodetype)
            {
                push @no_type_nodes, $node;
                next;
            }
            
            if ( $nodetype eq 'fsp' and 
                $node_parent and 
                $node_parent ne $node)
            {
                push @bpa_ctrled_nodes, $node;
            }
            
            if ( $nodetype eq 'bpa')
            {
                my $my_frame_bpa_cec = getFrameMembers( $node, $vpdtab, $ppctab);
                push @frame_members, @$my_frame_bpa_cec;
            }
        }
    }

    if (scalar(@no_type_nodes))
    {
        my $tmp_nodelist = join ',', @no_type_nodes;
        return ( usage("Attribute nodetype.nodetype cannot be found for node(s) $tmp_nodelist"));
    }

    if (scalar(@bpa_ctrled_nodes))
    {
        my $tmp_nodelist = join ',', @bpa_ctrled_nodes;
        return ( usage("Node(s) $tmp_nodelist is(are) controlled by BPA."));
    }
    
    if ( scalar( @frame_members))
    {
        my @all_nodes = xCAT::Utils::get_unique_members( @$nodes, @frame_members);
        $request->{node} = \@all_nodes;
    }
    # Set HW type to 'hmc' anyway, so that this command will not going to 
    # PPCfsp.pm
    # $request->{ 'hwtype'} = 'hmc';
    $request->{method} = 'mkhwconn';
    return( \%opt);
}

####################################################
# Get frame members
####################################################
#ppc/vpd nodes cache
my @all_ppc_nodes;
my @all_vpd_nodes;
sub getFrameMembers
{
    my $node = shift; #this a BPA node
    my $vpdtab = shift;
    my $ppctab = shift;
    my @frame_members = ();
    my @bpa_nodes     = ();
    my $vpdhash = $vpdtab->getNodeAttribs( $node, [qw(mtm serial)]);
    my $mtm = $vpdhash->{mtm};
    my $serial = $vpdhash->{serial};
    if ( scalar( @all_vpd_nodes) == 0)
    {
        @all_vpd_nodes = $vpdtab->getAllNodeAttribs( ['node', 'mtm', 'serial']);
    }
    for my $vpd_node (@all_vpd_nodes)
    {
        if ( $vpd_node->{'mtm'} eq $mtm and $vpd_node->{'serial'} eq $serial)
        {
            push @frame_members, $vpd_node->{'node'};
            push @bpa_nodes, $vpd_node->{'node'};
        }
    }

    if ( scalar( @all_ppc_nodes) == 0)
    {
        @all_ppc_nodes = $ppctab->getAllNodeAttribs( ['node', 'parent']);
    }
    for my $bpa_node (@bpa_nodes)
    {
        for my $ppc_node (@all_ppc_nodes)
        {
            if ( $ppc_node->{parent} eq $bpa_node)
            {
                push @frame_members, $ppc_node->{'node'};
            }
        }
    }
    return \@frame_members;
}

##########################################################################
# Parse arguments for lshwconn  ---  This function isn't implemented and used.
##########################################################################
sub lshwconn_parse_args
{
    my $request = shift;
    my $args    = shift;
    my %opt = ();

    local *usage = sub {
        my $usage_string = xCAT::Usage->getUsage("lshwconn");
        return( [ $_[0], $usage_string] );
    };
#############################################
# Get options in command line
#############################################
    local @ARGV = ref($args) eq 'ARRAY'? @$args:();
    $Getopt::Long::ignorecase = 0;
    Getopt::Long::Configure( "bundling" );

    if ( !GetOptions( \%opt, qw(V|verbose h|help) )) {
        return( usage() );
    }
    return usage() if ( exists $opt{h});

    #############################################
    # Process command-line arguments
    #############################################
    if ( scalar( @ARGV)) {
        return(usage( "No additional flag is support by this command" ));
    }
    my $nodetypetab = xCAT::Table->new('nodetype');
    if (! $nodetypetab)
    {
        return( ["Failed to open table 'nodetype'.\n"]);
    }
    my $nodehmtab = xCAT::Table->new('nodehm');
    if (! $nodehmtab)
    {
        return( ["Failed to open table 'nodehm'.\n"]);
    }

    my $nodetype;
    for my $node ( @{$request->{node}})
    {
        my $ent = $nodetypetab->getNodeAttribs( $node, [qw(nodetype)]);
        my $nodehm = $nodehmtab->getNodeAttribs( $node, [qw(mgt)]);
        if ( ! $ent) 
        {
            return( ["Failed to get node type for node $node.\n"]);
        }
        if ( ! $nodehm)
        {
            return( ["Failed to get nodehm.mgt value for node $node.\n"]);
        }
        if ( $ent->{nodetype} ne 'hmc' 
                and $ent->{nodetype} ne 'fsp' 
                and $ent->{nodetype} ne 'bpa')
        {
            return( ["Node type $ent->{nodetype} is not supported for this command.\n"]);
        }
        if ( ! $nodetype)
        {
            $nodetype = $ent->{nodetype};
        }
        else
        {
            if ( $nodetype ne $ent->{nodetype})
            {
                return( ["Cannot support multiple node types in this command line.\n"]);
            }
        }
    }

    $request->{nodetype} = $nodetype;

    $request->{method} = 'lshwconn';
    return( \%opt);
}

##########################################################################
# Parse arguments for rmhwconn
##########################################################################
sub rmhwconn_parse_args
{
    my $request = shift;
    my $args    = shift;
    my %opt = ();

    local *usage = sub {
        my $usage_string = xCAT::Usage->getUsage("rmhwconn");
        return( [ $_[0], $usage_string] );
    };
    #############################################
    # Get options in command line
    #############################################
    local @ARGV = ref($args) eq 'ARRAY'? @$args:();
    $Getopt::Long::ignorecase = 0;
    Getopt::Long::Configure( "bundling" );

    if ( !GetOptions( \%opt, qw(V|verbose h|help T=i) )) {
        return( usage() );
    }
    return usage() if ( exists $opt{h});

    #############################################
    # Process command-line arguments
    #############################################
    if ( scalar (@ARGV)) {
        return(usage( "No additional flag is support by this command" ));
    }
    ##########################################
    # Check if CECs are controlled by a frame
    ##########################################
    my $nodes = $request->{node};
    my $ppctab  = xCAT::Table->new( 'ppc' );
    return( ["Failed to open table 'ppc'.\n"]) if ( ! $ppctab);
    my $nodetypetab = xCAT::Table->new( 'nodetype');
    return( ["Failed to open table 'nodetype'.\n"]) if ( ! $nodetypetab);
    my $vpdtab = xCAT::Table->new( 'vpd');
    return( ["Failed to open table 'vpd'.\n"]) if ( ! $vpdtab);
    my $nodehmtab = xCAT::Table->new('nodehm');
    return( ["Failed to open table 'nodehm'.\n"]) if (! $nodehmtab);
    my @bpa_ctrled_nodes = ();
    my @no_type_nodes    = ();
    my @frame_members    = ();
    for my $node ( @$nodes)
    {
        my $nodehm = $nodehmtab->getNodeAttribs( $node, [qw(mgt)]);
        if ( ! $nodehm)
        {
            return( ["Failed to get nodehm.mgt value for node $node.\n"]);
        }
        
	my $node_parent = undef;
        my $nodetype    = undef;
        my $nodetype_hash    = $nodetypetab->getNodeAttribs( $node,[qw(nodetype)]);
        my $node_parent_hash = $ppctab->getNodeAttribs( $node,[qw(parent)]);
        $nodetype    = $nodetype_hash->{nodetype};
        $node_parent = $node_parent_hash->{parent};
        if ( !$nodetype)
        {
            push @no_type_nodes, $node;
            next;
        }

        if ( $nodetype eq 'fsp' and 
                $node_parent and 
                $node_parent ne $node)
        {
            push @bpa_ctrled_nodes, $node;
        }

        if ( $nodetype eq 'bpa')
        {
            my $my_frame_bpa_cec = getFrameMembers( $node, $vpdtab, $ppctab);
            push @frame_members, @$my_frame_bpa_cec;
        }
    }

    if (scalar(@no_type_nodes))
    {
        my $tmp_nodelist = join ',', @no_type_nodes;
        return ( usage("Attribute nodetype.nodetype cannot be found for node(s) $tmp_nodelist"));
    }

    if (scalar(@bpa_ctrled_nodes))
    {
        my $tmp_nodelist = join ',', @bpa_ctrled_nodes;
        return ( usage("Node(s) $tmp_nodelist is(are) controlled by BPA."));
    }
    
    if ( scalar( @frame_members))
    {
        my @all_nodes = xCAT::Utils::get_unique_members( @$nodes, @frame_members);
        $request->{node} = \@all_nodes;
    }
    $request->{method} = 'rmhwconn';
    return( \%opt);
}


##########################################################################
# Create connection for CECs/BPAs
##########################################################################
sub mkhwconn
{
    my $request = shift;
    my $hash    = shift;
    #my $exp     = shift;
    #my $hwtype  = @$exp[2];
    my $opt     = $request->{opt};
    my @value   = ();
    my $Rc      = undef;
    my $tooltype = $opt->{T};
    
    for my $cec_bpa ( keys %$hash)
    {
        my $node_hash = $hash->{$cec_bpa};
        for my $node_name ( keys %$node_hash)
        {
            my $d = $node_hash->{$node_name};

            my ( undef,undef,$mtms,undef,$type) = @$d;
            my ($user, $passwd);
            if ( exists $opt->{P})
            {
                ($user, $passwd) = ('HMC', $opt->{P});
            }
            else
            {
                ($user, $passwd) = xCAT::PPCdb::credentials( $node_name, $type,'HMC');
                if ( !$passwd)
                {
                    push @value, [$node_name, "Cannot get password of userid 'HMC'. Please check table 'passwd' or 'ppcdirect'.",1];
                    next;
                }

            }

            my $res = xCAT::Utils::fsp_api_action( $node_name, $d, "add_connection", $tooltype );
            $Rc = @$res[2];
	    if( @$res[1] ne "") {
                push @value, [$node_name, @$res[1], $Rc];
            }

        }
    }
    return \@value;
}
##########################################################################
# List connection status for CECs/BPAs -- This function isn't impletmented and used.
##########################################################################
sub lshwconn
{
    my $request = shift;
    my $hash    = shift;
    my $exp     = shift;
    my $hwtype  = @$exp[2];
    my $opt     = $request->{opt};
    my @value   = ();
    my $Rc      = undef;


    my $hosttab  = xCAT::Table->new( 'hosts' );
    my $res = xCAT::PPCcli::lssysconn( $exp, "all" );
    $Rc = shift @$res;
    if ( $request->{nodetype} eq 'hmc')
    {
        if ( $Rc)
        {
            push @value, [$exp->[3], $res->[0], $Rc];
            return \@value;
        }
        my $vpdtab = xCAT::Table->new('vpd');
        my @vpdentries = $vpdtab->getAllAttribs(qw(node serial mtm));
        my %node_vpd_hash;
        for my $vpdent ( @vpdentries)
        {
            if ( $vpdent->{node} and $vpdent->{serial} and $vpdent->{mtm})
            {
                $node_vpd_hash{"$vpdent->{mtm}*$vpdent->{serial}"} = $vpdent->{node};
            }
        }
        my %node_ppc_hash;
        my $ppctab =  xCAT::Table->new('ppc');
        for my $node ( values %node_vpd_hash)
        {
            my $node_parent_hash = $ppctab->getNodeAttribs( $node, [qw(parent)]);
            $node_ppc_hash{$node} = $node_parent_hash->{parent};
        }

        for my $r ( @$res)
        {
            $r =~ s/type_model_serial_num=([^,]*),//;
            my $mtms = $1;
            $r =~ s/resource_type=([^,]*),//;
            $r =~ s/sp=.*?,//;
            $r =~ s/sp_phys_loc=.*?,//;
            my $node_name;
            if ( exists $node_vpd_hash{$mtms})
            {
                $node_name = $node_vpd_hash{$mtms};
                $r = "hcp=$exp->[3],parent=$node_ppc_hash{$node_name}," . $r;
            }
            else
            {
                $node_name = $mtms;
                $r = "hcp=$exp->[3],parent=," . $r;
            }
            push @value, [ $node_name, $r, $Rc];
        }
    }
    else
    {
        for my $cec_bpa ( keys %$hash)
        {
            my $node_hash = $hash->{$cec_bpa};
            for my $node_name (keys %$node_hash)
            {
                ############################################
                # If lssysconn failed, put error into all
                # nodes' return values
                ############################################
                if ( $Rc ) 
                {
                    push @value, [$node_name, @$res[0], $Rc];
                    next;
                }

                ############################
                # Get IP address
                ############################
                my $node_ip = undef;
                if ( $hosttab)
                {
                    my $node_ip_hash = $hosttab->getNodeAttribs( $node_name,[qw(ip)]);
                    $node_ip = $node_ip_hash->{ip};
                }
                if (!$node_ip)
                {
                    push @value, [$node_name, $node_ip, $Rc];
                    next;
                }

                if ( my @res_matched = grep /\Qipaddr=$node_ip,\E/, @$res)
                {
                    for my $r ( @res_matched)
                    {
                        $r =~ s/\Qtype_model_serial_num=$cec_bpa,\E//;
#                        $r =~ s/\Qresource_type=$type,\E//;
                        $r =~ s/sp=.*?,//;
                            $r =~ s/sp_phys_loc=.*?,//;
                            push @value, [$node_name, $r, $Rc];
                    }
                }
                else
                {
                    push @value, [$node_name, 'Connection not found', 1];
                }
            }
        }
    }
    return \@value;
}

##########################################################################
# Remove connection for CECs/BPAs to Hardware servers
##########################################################################
sub rmhwconn
{
    my $request = shift;
    my $hash    = shift;
    #my $exp     = shift;
    #my $hwtype  = @$exp[2];
    my $opt     = $request->{opt};
    my @value   = ();
    my $Rc      = undef;
    my $tooltype = $opt->{T};

    for my $cec_bpa ( keys %$hash)
    {
        my $node_hash = $hash->{$cec_bpa};
        for my $node_name (keys %$node_hash)
        {
            my $d = $node_hash->{$node_name};

            my ( undef,undef,undef,undef,$type) = @$d;

	    my $res = xCAT::Utils::fsp_api_action( $node_name, $d, "rm_connection", $tooltype );
            $Rc = @$res[2];
	    if( @$res[1] ne "") {
                push @value, [$node_name, @$res[1], $Rc];
            }
 
        }
    }
    return \@value;
}

1;
