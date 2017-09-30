# A debhelper build system class for Qt projects
# (based on the makefile class).
#
# Copyright: © 2010 Kelvin Modderman
# License: GPL-2+

package Debian::Debhelper::Buildsystem::qmake;

use strict;
use warnings;
use Debian::Debhelper::Dh_Lib qw(dpkg_architecture_value error is_cross_compiling);
use parent qw(Debian::Debhelper::Buildsystem::makefile);

our $qmake="qmake";

sub DESCRIPTION {
	"qmake (*.pro)";
}

sub check_auto_buildable {
	my $this=shift;
	my @projects=glob($this->get_sourcepath('*.pro'));
	my $ret=0;

	if (@projects > 0) {
		$ret=1;
		# Existence of a Makefile generated by qmake indicates qmake
		# class has already been used by a prior build step, so should
		# be used instead of the parent makefile class.
		my $mf=$this->get_buildpath("Makefile");
		if (-e $mf) {
			$ret = $this->SUPER::check_auto_buildable(@_);
			open(my $fh, '<', $mf)
				or error("unable to open Makefile: $mf");
			while(<$fh>) {
				if (m/^# Generated by qmake/i) {
					$ret++;
					last;
				}
			}
			close($fh);
		}
	}

	return $ret;
}

sub configure {
	my $this=shift;
	my @options;
	my @flags;

	push @options, '-makefile';
	push @options, '-nocache';
	if (is_cross_compiling()) {
		my $host_os = dpkg_architecture_value("DEB_HOST_ARCH_OS");
		my %os_mkspec_mapping = (
			'linux'    => 'linux-g++',
			'kfreebsd' => 'gnukfreebsd-g++',
			'hurd'     => 'hurd-g++',
		);
		push @options, ("-spec", $os_mkspec_mapping{$host_os});
	}

	if ($ENV{CFLAGS}) {
		push @flags, "QMAKE_CFLAGS_RELEASE=$ENV{CFLAGS} $ENV{CPPFLAGS}";
		push @flags, "QMAKE_CFLAGS_DEBUG=$ENV{CFLAGS} $ENV{CPPFLAGS}";
	}
	if ($ENV{CXXFLAGS}) {
		push @flags, "QMAKE_CXXFLAGS_RELEASE=$ENV{CXXFLAGS} $ENV{CPPFLAGS}";
		push @flags, "QMAKE_CXXFLAGS_DEBUG=$ENV{CXXFLAGS} $ENV{CPPFLAGS}";
	}
	if ($ENV{LDFLAGS}) {
		push @flags, "QMAKE_LFLAGS_RELEASE=$ENV{LDFLAGS}";
		push @flags, "QMAKE_LFLAGS_DEBUG=$ENV{LDFLAGS}";
	}
	push @flags, "QMAKE_STRIP=:";
	push @flags, "PREFIX=/usr";

	if (is_cross_compiling()) {
		if ($ENV{CC}) {
			push @flags, "QMAKE_CC=" . $ENV{CC};
		} else {
			push @flags, "QMAKE_CC=" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-gcc";
		}
		if ($ENV{CXX}) {
			push @flags, "QMAKE_CXX=" . $ENV{CXX};
		} else {
			push @flags, "QMAKE_CXX=" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-g++";
		}
		push @flags, "QMAKE_LINK=\$(CXX)";
		push @flags, "PKG_CONFIG=" . dpkg_architecture_value("DEB_HOST_GNU_TYPE") . "-pkg-config";
	}

	$this->mkdir_builddir();
	$this->doit_in_builddir($qmake, @options, @flags, @_);
}

sub install {
	my $this=shift;
	my $destdir=shift;

	# qmake generated Makefiles use INSTALL_ROOT in install target
	# where one would expect DESTDIR to be used.
	$this->SUPER::install($destdir, "INSTALL_ROOT=$destdir", @_);
}

1
