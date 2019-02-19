# $Revision: 1.22 $, $Date: 2019/02/19 02:17:27 $
#
# Conditional build:
# _without_tests - do not perform "make test"
#
%include %{_rpmconfigdir}/macros.perl
Summary:	Perl extensions for CDK
Summary(pl):	Rozszerzenie Perla dla CDK
Name:		cdk-perl
Version:	5.0
Release:	20190218
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
dystrybucji Cdk dotycz± tak¿e tego rozszerzenia.

%prep
%define debug_package %{nil}

%define doc_dir       %{_defaultdocdir}/%{name}-%{version}
%define demos_dir     %{doc_dir}/demos
%define examples_dir  %{doc_dir}/examples

%setup -q -n cdk-perl-%{release}

%build

# echo "perl_sitelib  %{perl_sitelib}"
# echo "perl_sitearch %{perl_sitearch}"
# echo "perl_archlib  %{perl_archlib}"
# echo "perl_privlib  %{perl_privlib}"

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

install -d         %{buildroot}%{doc_dir}
install CHANGES    %{buildroot}%{doc_dir}
install COPYING    %{buildroot}%{doc_dir}
install README     %{buildroot}%{doc_dir}

install -d         %{buildroot}%{demos_dir}
install demos/*    %{buildroot}%{demos_dir}

install -d         %{buildroot}%{examples_dir}
install examples/* %{buildroot}%{examples_dir}

%clean
rm -rf %{buildroot}

%files 
%{perl_archlib}/auto/Cdk
%{perl_archlib}/perllocal.pod
%{perl_archlib}/Cdk.pm
%{perl_archlib}/Cdk
%{doc_dir}

%changelog

* Sun Jul 14 2013 Thomas Dickey
- adapted from spec-file from pld.org dated 2002/09/28
