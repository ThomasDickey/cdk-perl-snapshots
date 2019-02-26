# $Revision: 1.28 $, $Date: 2019/02/26 01:02:35 $
#
# Conditional build:
# _without_tests - do not perform "make test"
#
%include %{_rpmconfigdir}/macros.perl
Summary:	Perl extensions for CDK
Summary(pl):	Rozszerzenie Perla dla CDK
Name:		cdk-perl
Version:	5.0
Release:	20190225
License:	distributable 
Group:		Development/Languages/Perl
Source0:	ftp://ftp.invisible-island.net/cdk/cdk-perl-%{release}.tgz
#BuildRequires:	cdk-devel
#BuildRequires:	perl >= 5.005_03-10
#BuildRequires:	rpm-perlprov
#BuildRoot:	%{tmpdir}/%{name}-%{version}-root-%(id -u -n)

%description
This is the Perl5 extension to the Cdk library written by Mike Glover.
All the copyright notices from the Cdk C distribution also apply to
the extension.

%description -l pl
To jest rozszerzenie Perla do biblioteki Cdk. Wszystkie copyrighty z
dystrybucji Cdk dotyczą także tego rozszerzenia.

%prep
%define debug_package %{nil}

%global os_SUSE    %(test "%{_host_vendor}" = "suse"   && echo 1 || echo 0)
%global os_MAGEIA  %(test "%{_host_vendor}" = "mageia" && echo 1 || echo 0)
%global os_REDHAT  %(test "%{_host_vendor}" = "redhat" && echo 1 || echo 0)

%define doc_dir       %{_defaultdocdir}/%{name}-%{version}
%define full_dir      %{doc_dir}/fulldemo
%define demos_dir     %{doc_dir}/demos
%define examples_dir  %{doc_dir}/examples
%define fullhelp_dir  %{doc_dir}/fulldemo/help

%setup -q -n cdk-perl-%{release}

%build

: "_host_vendor  %{_host_vendor}"
: "perl_sitelib  %{perl_sitelib}"
: "perl_sitearch %{perl_sitearch}"
: "perl_archlib  %{perl_archlib}"
: "perl_privlib  %{perl_privlib}"

./configure

%{__make}

%{!?_without_tests:%{__make} test}

%install
rm -rf %{buildroot}

install -d %{buildroot}%{perl_archlib}

%{__make} install \
	BUILDDIR=%{buildroot} \
	DESTDIR=%{buildroot} 

chmod -R u+w %{buildroot} 

install -d                      %{buildroot}%{doc_dir}
install -m 644 CHANGES          %{buildroot}%{doc_dir}
install -m 644 COPYING          %{buildroot}%{doc_dir}
install -m 644 README           %{buildroot}%{doc_dir}

install -d                      %{buildroot}%{full_dir}
install fulldemo/cdkdemo        %{buildroot}%{full_dir}

install -d                      %{buildroot}%{fullhelp_dir}
install -m 644 fulldemo/help/*  %{buildroot}%{fullhelp_dir}

install -d                      %{buildroot}%{demos_dir}
install demos/*                 %{buildroot}%{demos_dir}

install -d                      %{buildroot}%{examples_dir}
install examples/*              %{buildroot}%{examples_dir}

%clean
rm -rf %{buildroot}

%files 
%if %{os_SUSE}%{os_REDHAT}
%{perl_archlib}/perllocal.pod
%endif
%if %{os_SUSE}%{os_MAGEIA}
%{perl_sitearch}/auto/Cdk
%{perl_sitearch}/Cdk.pm
%{perl_sitearch}/Cdk
%endif
%if %{os_REDHAT}
%{perl_archlib}/auto/Cdk
%{perl_archlib}/Cdk.pm
%{perl_archlib}/Cdk
%endif
%{doc_dir}

%dir

%changelog

* Fri Feb 22 2019 Thomas Dickey
- convert to UTF-8, port to OpenSUSE, Mageia
- add fulldemo

* Sun Jul 14 2013 Thomas Dickey
- adapted from spec-file from pld.org dated 2002/09/28
