# Copyright 2021-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( pypy3 python3_{10..13} )

inherit distutils-r1 pypi

DESCRIPTION="Run-time type checker for Python"
HOMEPAGE="
	https://pypi.org/project/typeguard/
	https://github.com/agronholm/typeguard/
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~alpha amd64 arm arm64 hppa ~ia64 ~loong ~mips ppc ppc64 ~riscv ~s390 sparc x86"

RDEPEND="
	>=dev-python/typing-extensions-4.10.0[${PYTHON_USEDEP}]
"
BDEPEND="
	>=dev-python/setuptools-scm-6.4[${PYTHON_USEDEP}]
"

distutils_enable_tests pytest

python_test() {
	# mypy changes results from version to version
	# (we can't use EPYTEST_IGNORE because pytest_ignore_collect breaks it)
	rm -rf tests/mypy || die

	local -x PYTHONDONTWRITEBYTECODE=
	local -x PYTEST_DISABLE_PLUGIN_AUTOLOAD=1
	# the XFAIL test pass due to some package being installed
	epytest -o xfail_strict=False -p typeguard
}
