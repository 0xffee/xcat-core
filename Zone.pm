#!/usr/bin/env perl
# IBM(c) 2007 EPL license http://www.eclipse.org/legal/epl-v10.html
package xCAT::Zone;

BEGIN
{
    $::XCATROOT = $ENV{'XCATROOT'} ? $ENV{'XCATROOT'} : '/opt/xcat';
}

# if AIX - make sure we include perl 5.8.2 in INC path.
#       Needed to find perl dependencies shipped in deps tarball.
if ($^O =~ /^aix/i) {
	unshift(@INC, qw(/usr/opt/perl5/lib/5.8.2/aix-thread-multi /usr/opt/perl5/lib/5.8.2 /usr/opt/perl5/lib/site_perl/5.8.2/aix-thread-multi /usr/opt/perl5/lib/site_perl/5.8.2));
}

use lib "$::XCATROOT/lib/perl";
# do not put a use or require for  xCAT::Table here. Add to each new routine
# needing it to avoid reprocessing of user tables ( ExtTab.pm) for each command call 
use POSIX qw(ceil);
use File::Path;
use Socket;
use strict;
use Symbol;
use warnings "all";

#--------------------------------------------------------------------------------

=head1    xCAT::Zone

=head2    Package Description

This program module file, is a set of Zone utilities used by xCAT *zone commands.

=cut


#--------------------------------------------------------------------------------

=head3    genSSHRootKeys 
    Arguments:
      callback for error messages 
      directory in which to put the ssh RSA keys 
      zonename 
      rsa private key to use for generation ( optional)
    Returns:
    Error:  1 - key generation failure.
    Example:
     $rc =xCAT::Zone->genSSHRootKeys($callback,$keydir,$rsakey); 
=cut

#--------------------------------------------------------------------------------
sub  genSSHRootKeys 
{
    my ($class, $callback, $keydir,$zonename,$rsakey) = @_;
    
    #
    # create /keydir if needed
    #
    if (!-d $keydir)
    {
        my $cmd = "/bin/mkdir -m 700 -p $keydir";
        my $output = xCAT::Utils->runcmd("$cmd", 0);
        if ($::RUNCMD_RC != 0)
        {
           my $rsp = {};
           $rsp->{error}->[0] =
             "Could not create $keydir directory";
           xCAT::MsgUtils->message("E", $rsp, $callback);
           return 1;

        }
    }

    #
    #  create /install/postscripts/_ssh/zonename if needed
    #
    my $installdir = xCAT::TableUtils->getInstallDir();  # get installdir
    if (!-d "$installdir/postscripts/_ssh/$zonename")
    {
        my $cmd = "/bin/mkdir -m 755 -p $installdir/postscripts/_ssh/$zonename";
        my $output = xCAT::Utils->runcmd("$cmd", 0);
        if ($::RUNCMD_RC != 0)
        {
            my $rsp = {};
            $rsp->{error}->[0] = "Could not create $installdir/postscripts/_ssh/$zonename directory.";
            xCAT::MsgUtils->message("E", $rsp, $callback);
           return 1;
        }
    }

    #need to gen a new rsa key for root for the zone 
    my $pubfile = "$keydir/id_rsa.pub";
    my $pvtfile = "$keydir/id_rsa";

    # if exists, remove the old files 
    if (-r $pubfile)
    {

        my $cmd = "/bin/rm $keydir/id_rsa*";
        my $output = xCAT::Utils->runcmd("$cmd", 0);
        if ($::RUNCMD_RC != 0)
        {
            my $rsp = {};
            $rsp->{error}->[0] = "Could not remove id_rsa files from $keydir directory.";
            xCAT::MsgUtils->message("E", $rsp, $callback);
            return 1;
        }
    }

    # gen new RSA keys 
    my $cmd;
    my $output;
    # if private key was input use it
    if (defined ($rsakey))  {
      $cmd="/usr/bin/ssh-keygen -y -f $rsakey > $pubfile";
      $output = xCAT::Utils->runcmd("$cmd", 0);
      if ($::RUNCMD_RC != 0)
      {
            my $rsp = {};
            $rsp->{error}->[0] = "Could not generate $pubfile from $rsakey";
            xCAT::MsgUtils->message("E", $rsp, $callback);
            return 1;
      }
      # now copy the private key into the directory
      $cmd="cp $rsakey  $keydir";
      $output = xCAT::Utils->runcmd("$cmd", 0);
      if ($::RUNCMD_RC != 0)
      {
            my $rsp = {};
            $rsp->{error}->[0] = "Could not run $cmd";
            xCAT::MsgUtils->message("E", $rsp, $callback);
            return 1;
      }
    } else {  # generate all new keys
      $cmd = "/usr/bin/ssh-keygen -t rsa -q -b 2048 -N '' -f $pvtfile";
      $output = xCAT::Utils->runcmd("$cmd", 0);
      if ($::RUNCMD_RC != 0)
     {
            my $rsp = {};
            $rsp->{error}->[0] = "Could not generate $pubfile";
            xCAT::MsgUtils->message("E", $rsp, $callback);
            return 1;
     }
    }
    #make sure permissions are correct
    $cmd = "chmod 644 $pubfile;chown root $pubfile";
    $output = xCAT::Utils->runcmd("$cmd", 0);
    if ($::RUNCMD_RC != 0)
    {
            my $rsp = {};
            $rsp->{error}->[0] = "Could set permission and owner on  $pubfile";
            xCAT::MsgUtils->message("E", $rsp, $callback);
            return 1;
    }
    # copy authorized_keys for install on node
    if (-r $pubfile)
    {
        my $cmd =
          "/bin/cp -p $pubfile $installdir/postscripts/_ssh/$zonename ";
        my $output = xCAT::Utils->runcmd("$cmd", 0);
        if ($::RUNCMD_RC != 0)
        {
            my $rsp = {};
            $rsp->{error}->[0] = 
           "Could not copy $pubfile to $installdir/postscripts/_ssh/$zonename";
            xCAT::MsgUtils->message("E", $rsp, $callback);
            return 1;

        }
    }
    else
    {
            my $rsp = {};
            $rsp->{error}->[0] = 
           "Could not copy $pubfile to $installdir/postscripts/_ssh/$zonename, because $pubfile does not exist.";
            xCAT::MsgUtils->message("E", $rsp, $callback);
    }
}
#--------------------------------------------------------------------------------

=head3    getdefaultzone 
    Arguments:
      None 
    Returns:
    Name of the current default  zone from the zone table
    Example:
     my $defaultzone =xCAT::Zone->getdefaultzone(); 
=cut

#--------------------------------------------------------------------------------
sub  getdefaultzone 
{
 my $defaultzone;
 # read all the zone table and find the defaultzone, if it exists
 my $tab = xCAT::Table->new("zone");
 my @zones = $tab->getAllAttribs('zonename','defaultzone');
 foreach my $zone (@zones) {
  # Look for the  defaultzone=yes/1 entry
  if ((defined($zone->{defaultzone})) && ($zone->{defaultzone} =~ "yes")) {
     $defaultzone = $zone->{zonename};
  }
 }
 $tab->close();
 return $defaultzone;
}
#--------------------------------------------------------------------------------

=head3    iszonedefined 
    Arguments:
      zonename 
    Returns:
     1 if the zone is already in the zone table.
    Example:
     xCAT::Zone->iszonedefined($zonename); 
=cut

#--------------------------------------------------------------------------------
sub iszonedefined 
{
 my ($class,$zonename) = @_;
 # checks the zone table to see if input zonename already in the table 
 my $tab = xCAT::Table->new("zone");
 my $zone = $tab->getAttribs({zonename => $zonename},'sshkeydir');
 $tab->close();
 if (defined($zone)) {
    return 1;
 }else{
    return 0;
 }
}
1;
