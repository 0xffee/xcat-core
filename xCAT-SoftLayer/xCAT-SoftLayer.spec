Summary: Utilities to make xCAT work in a SoftLayer environment
Name: xCAT-SoftLayer
Version: %(cat Version)
Release: snap%(date +"%Y%m%d%H%M")
Epoch: 4
License: EPL
Group: Applications/System
Source: xCAT-SoftLayer-%(cat Version).tar.gz
Packager: IBM Corp.
Vendor: IBM Corp.
Distribution: %{?_distribution:%{_distribution}}%{!?_distribution:%{_vendor}}
Prefix: /opt/xcat
BuildRoot: /var/tmp/%{name}-%{version}-%{release}-root

BuildArch: noarch
Requires: xCAT-server
#Requires: xCAT-server  >= %{epoch}:%(cat Version|cut -d. -f 1,2)

Provides: xCAT-SoftLayer = %{epoch}:%{version}

%description
xCAT-SoftLayer provides Utilities to make xCAT work in a SoftLayer environment.  This package should be installed on your management server

# %define VERBOSE %(if [ "$VERBOSE" = "1" -o "$VERBOSE" = "yes" ];then echo 1; else echo 0; fi)
# %define NOVERBOSE %(if [ "$VERBOSE" = "1" -o "$VERBOSE" = "yes" ];then echo 0; else echo 1; fi)
# %define NOVERBOSE %{?VERBOSE:1}%{!?VERBOSE:0}

%prep
# %if %NOVERBOSE
# echo NOVERBOSE is on
# set +x
# %elseif
# set -x
# %endif

%setup -q -n xCAT-SoftLayer
%build
# Convert pods to man pages and html pages
./xpod2man

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/%{prefix}/bin
mkdir -p $RPM_BUILD_ROOT/%{prefix}/share/xcat/install
mkdir -p $RPM_BUILD_ROOT/install/postscripts

cp -a share/xcat/install/* $RPM_BUILD_ROOT/%{prefix}/share/xcat/install/

cp -d bin/* $RPM_BUILD_ROOT/%{prefix}/bin
chmod 755 $RPM_BUILD_ROOT/%{prefix}/bin/*

cp -d postscripts/* $RPM_BUILD_ROOT/install/postscripts
chmod 755 $RPM_BUILD_ROOT/install/postscripts/*

mkdir -p $RPM_BUILD_ROOT/%{prefix}/share/doc/packages/xCAT-SoftLayer
cp LICENSE.html $RPM_BUILD_ROOT/%{prefix}/share/doc/packages/xCAT-SoftLayer
chmod 644 $RPM_BUILD_ROOT/%{prefix}/share/doc/packages/xCAT-SoftLayer/*

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
#%doc LICENSE.html
%{prefix}
/install/postscripts
