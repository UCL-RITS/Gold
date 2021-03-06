# RPM Spec file for Gold

%define  name     gold
%define  ver      2.2.0.7
%define  rel      23
%define  basedir   %{name}-%{ver}
%define  prefix    /opt/gold
%define  profiled  /etc/profile.d
%define  cgi_bin   /var/www/cgi-bin/gold

Summary: An Accounting and Allocation Manager
Name: %{name}
Version: %{ver}
Release: %{rel}
License: BSD Open Source License. See LICENSE file.
Group: Applications
Source0: %{name}-%{ver}.tar.gz
URL: https://github.com/UCL-RITS/Gold/
Distribution: SSS
Vendor: UCL-RITS
Packager: UCL-RITS
BuildRoot: %{_tmppath}/%{name}-%{ver}-root
Prefix: %{prefix}

Requires: perl >= 5.10
Requires: sudo
Requires: libxml2 >= 2.4.25
Requires: perl(CGI::Session) >= 3.95
Requires: perl(CGI) >= 3.10
Requires: perl(Compress::Zlib) >= 1.33
Requires: perl(Crypt::CBC) >= 2.24
Requires: perl(Crypt::DES) >= 2.05
Requires: perl(Crypt::DES_EDE3) >= 0.01
Requires: perl(DBI) >= 1.53
Requires: perl(Data::Properties) >= 0.02
Requires: perl(Date::Manip) >= 5.48
Requires: perl(Digest) >= 1.05
Requires: perl(Digest::HMAC) >= 1.01
Requires: perl(Digest::MD5) >= 2.36
Requires: perl(Digest::SHA1) >= 2.07
Requires: perl(Error) >= 0.15
Requires: perl(Log::Dispatch) >= 2.21
Requires: perl(Log::Dispatch::FileRotate) >= 1.16
Requires: perl(Log::Log4perl) >= 1.14
Requires: perl(MIME::Base64) >= 3.01
Requires: perl(Module::Build) >= 0.2808
Requires: perl(Params::Validate) >= 0.89
Requires: perl(Term::ReadLine::Gnu) >= 1.15
Requires: perl(Time::HiRes) >= 1.65
Requires: perl(XML::LibXML) >= 1.58
Requires: perl(XML::LibXML::Common) >= 0.13
Requires: perl(XML::NamespaceSupport) >= 1.08
Requires: perl(XML::SAX) >= 0.12

#BuildPreReq: openssl-devel
AutoReqProv: no

%description
Gold is a unique open source dynamically customizable information service. It has built-in support to function as a dynamic reservation-based Accounting and Allocation Management System that manages the utilization of computational resources in a multi-project environment. It is used in conjunction with a resource management (batch) system allowing an organization to guarantee greater fairness and enforce mission priorities. It does this by associating a charge with the use of computational resources and allocating resource credits which limit how much of the resources may be used at what time and by whom. It tracks resource utilization and allows for insightful planning.


#############################################################################
#   The items marked 'profiled' are for the auxillary RPM that is gen'd
#    containing the profile.d/qbank.[csh,sh] scripts.  The stock
#    gold-<ver>.rpm doesn't depend on these, but the gold-profiled require
#    does require that gold-oscar is installed.  These setup the PATH and
#    any other necessary EnvVars for each interactive shell (i.e. don't work
#    for ssh/rsh shells).
#############################################################################
%package profiled
Summary: Gold Accounting and Allocation Manager - profile.d scripts
Group: Applications
Requires: gold-oscar

%description profiled
This rpm contains the Gold Accounting and Allocation Manager profile.d
entries necessary to establish the proper Gold environment.


#---------------------------------------------------------------------
# Prep install section
#---------------------------------------------------------------------

%prep
rm -rf $RPM_BUILD_ROOT

# Extract tarball
%setup -n gold-%{ver}


#---------------------------------------------------------------------
# Build section - Actually configure/build in BUILD_ROOT area
#---------------------------------------------------------------------
   
%build
./configure --prefix %{prefix} --with-db=SQLite 
mkdir -p scripts
make build_root=$RPM_BUILD_ROOT
make build_root=$RPM_BUILD_ROOT gui


#---------------------------------------------------------------------
# Install section - install things as they should be on target machine
#                   by placing them in the BUILD_ROOT area accordingly
#---------------------------------------------------------------------

%install
#mkdir -p $RPM_BUILD_ROOT/%{prefix}
make build_root=$RPM_BUILD_ROOT deps
make build_root=$RPM_BUILD_ROOT install
make build_root=$RPM_BUILD_ROOT install-gui
cp bank.gold base.sql bank.sql sssrmap3.xsd ${RPM_BUILD_ROOT}%{prefix}
cp src/gold_init.pl ${RPM_BUILD_ROOT}%{prefix}/sbin/gold_init
chmod +x ${RPM_BUILD_ROOT}%{prefix}/sbin/gold_init
mkdir -p $RPM_BUILD_ROOT/etc/init.d
cp etc/gold.d ${RPM_BUILD_ROOT}/etc/init.d/gold
mkdir -p ${RPM_BUILD_ROOT}/etc/sudoers.d/
cp etc/sudoers.d/gold ${RPM_BUILD_ROOT}/etc/sudoers.d/
mkdir -p ${RPM_BUILD_ROOT}/usr/local/bin
cp src/wrapper.sh ${RPM_BUILD_ROOT}/usr/local/bin
chmod 0755 ${RPM_BUILD_ROOT}/usr/local/bin/wrapper.sh
echo ${RPM_BUILD_ROOT}/%{prefix}/bin/*|xargs basename -a |sed -e "s:^:${RPM_BUILD_ROOT}/usr/local/bin/:"| xargs -n 1 ln ${RPM_BUILD_ROOT}/usr/local/bin/wrapper.sh 
touch ${RPM_BUILD_ROOT}%{prefix}/etc/auth_key
# Remove the docs so they can be installed in the defaultdocdir
rm -rf ${RPM_BUILD_ROOT}%{prefix}/doc

mkdir -p $RPM_BUILD_ROOT/%{profiled}
%__cp -f etc/gold.sh $RPM_BUILD_ROOT/%{profiled}/gold.sh
%__cp -f etc/gold.csh $RPM_BUILD_ROOT/%{profiled}/gold.csh


#---------------------------------------------------------------------
# Post section - Post install script runs on local system after install
#---------------------------------------------------------------------

#%post
#HOSTNAME=`hostname -s`
#sed "s/clay/$HOSTNAME/" $RPM_INSTALL_PREFIX/lib/qbank.ph >$RPM_INSTALL_PREFIX/lib/qbank.ph.mod
#%__mv $RPM_INSTALL_PREFIX/lib/qbank.ph.mod $RPM_INSTALL_PREFIX/lib/qbank.ph

#---------------------------------------------------------------------
# Clean section
#---------------------------------------------------------------------

#%clean
# Get rid of any tmp files in RPM land, ie. '/usr/src/redhat/BUILD/...', etc.
#%__rm -rf $RPM_BUILD_DIR/%{basedir}
#%__rm -rf $RPM_BUILD_ROOT


#---------------------------------------------------------------------
# Files section
#---------------------------------------------------------------------

#############################################################################
#   the %files area list the dirs to end up on target machine
#   and it looks in the BUILD_ROOT area and snags that dir & all sub-dirs
#   so all files don't have to be listed explicitly.
#############################################################################

%files
%defattr(-,root,root)
%{prefix}/bin
%{prefix}/lib
%{prefix}/sbin
%{prefix}/bank.gold
%{prefix}/base.sql
%{prefix}/bank.sql
%{prefix}/sssrmap3.xsd
%{cgi_bin}
/usr/local/bin/*
%config(noreplace) %{prefix}/etc/gold.conf
%config(noreplace) %{prefix}/etc/goldg.conf
%config(noreplace) %{prefix}/etc/goldd.conf
%attr(0755,root,root) /etc/init.d/gold
%attr(0600,root,root) /etc/sudoers.d/gold
%doc doc/userguide.pdf README INSTALL LICENSE CHANGES
%doc doc/userguide
%ghost %{prefix}/etc/auth_key

%files profiled
%defattr(0755,root,root)
%{profiled}/*


#---------------------------------------------------------------------
# ChangeLog section
#---------------------------------------------------------------------
%changelog
* Tue Jan 24 2017  02:19:00PM    William Hay <w.hay@ucl.ac.uk>
- Updated RPM for Use on RHEL7
* Thu Feb 17 2005  12:11:55AM    Scott Jackson <Scott.Jackson@pnl.gov>
- Updated RPM for Gold Second Beta Release
* Wed Sep 22 2004  12:01:22AM    Scott Jackson <Scott.Jackson@pnl.gov>
- Updated RPM for Gold Pre-Beta Release
* Mon Feb 23 2004  11:25:00AM    Scott Jackson <Scott.Jackson@pnl.gov>
- Updated RPM for Gold Alpha (Java) Release
* Mon Nov 03 2003  10:00:08AM    Scott Jackson <Scott.Jackson@pnl.gov>
- Created RPM for Gold Pre-Alpha Release

