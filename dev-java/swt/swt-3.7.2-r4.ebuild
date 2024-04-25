# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

JAVA_PKG_IUSE="doc source"

inherit java-pkg-2 java-pkg-simple java-osgi toolchain-funcs

MY_PV="${PV/_rc/RC}"
MY_DMF="https://archive.eclipse.org/eclipse/downloads/drops/R-${MY_PV}-201202080800"
MY_P="${PN}-${MY_PV}"

DESCRIPTION="GTK based SWT Library"
HOMEPAGE="https://www.eclipse.org/swt/"
SRC_URI="
	amd64? ( ${MY_DMF}/${MY_P}-gtk-linux-x86_64.zip )
	ppc? ( ${MY_DMF}/${MY_P}-gtk-linux-x86.zip )
	ppc64? ( ${MY_DMF}/${MY_P}-gtk-linux-ppc64.zip )
	x86? ( ${MY_DMF}/${MY_P}-gtk-linux-x86.zip )"

LICENSE="CPL-1.0 LGPL-2.1 MPL-1.1"
SLOT="3.7"
KEYWORDS="~amd64 ~ppc64 ~x86"
IUSE="cairo opengl"

BDEPEND="
	app-arch/unzip
	virtual/pkgconfig
"
COMMON_DEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/glib
	>=x11-libs/gtk+-2.6.8:2
	x11-libs/libXtst
	cairo? ( x11-libs/cairo )
	opengl? (
		virtual/glu
		virtual/opengl
	)"
DEPEND="${COMMON_DEPEND}
	>=virtual/jdk-1.8:*[-headless-awt]
	x11-base/xorg-proto
	x11-libs/libX11
	x11-libs/libXrender
	x11-libs/libXt
	x11-libs/libXtst"
RDEPEND="${COMMON_DEPEND}
	>=virtual/jre-1.8:*"

# JNI libraries don't need SONAME, bug #253756
QA_SONAME="usr/lib.*/libswt-.*.so"

JAVA_RESOURCE_DIRS="resources"
JAVA_SRC_DIR="src"

PATCHES=(
	# Fix Makefiles to respect flags and work with --as-needed
	"${FILESDIR}"/as-needed-and-flag-fixes-3.6.patch
)

src_unpack() {
	default
	unpack "./src.zip"
}

src_prepare() {
	default #780585
	java-pkg-2_src_prepare
	java-pkg_clean

	mkdir resources src || die "mkdir failed"
	mv org src || die "moving java sources failed"

	case ${ARCH} in
		ppc|x86) eapply "${FILESDIR}"/${P}-gio_launch-URI-x86.patch ;;
		*)       eapply "${FILESDIR}"/${P}-gio_launch-URI.patch ;;
	esac

	pushd src > /dev/null || die
		find -type f ! -name '*.java' \
			| xargs \
			cp --parent -t ../resources -v \
			|| die "copying resources failed"
	popd > /dev/null || die
	cp version.txt resources || die "adding version.txt failed"
}

src_compile() {
	local AWT_ARCH
	local JAWTSO="libjawt.so"
#	if [[ $(tc-arch) == 'x86' ]] ; then
#		AWT_ARCH="i386"
#	elif [[ $(tc-arch) == 'ppc' ]] ; then
#		AWT_ARCH="ppc"
#	elif [[ $(tc-arch) == 'ppc64' ]] ; then
#		AWT_ARCH="ppc64"
#	else
#		AWT_ARCH="amd64"
#	fi
#	if [[ -f "${JAVA_HOME}/jre/lib/${AWT_ARCH}/${JAWTSO}" ]]; then
#		export AWT_LIB_PATH="${JAVA_HOME}/jre/lib/${AWT_ARCH}"
#	elif [[ -f "${JAVA_HOME}/jre/bin/${JAWTSO}" ]]; then
#		export AWT_LIB_PATH="${JAVA_HOME}/jre/bin"
#	elif [[ -f "${JAVA_HOME}/$(get_libdir)/${JAWTSO}" ]] ; then
#		export AWT_LIB_PATH="${JAVA_HOME}/$(get_libdir)"
#	else
	IFS=":" read -r -a ldpaths <<< $(java-config -g LDPATH)

	for libpath in "${ldpaths[@]}"; do
		if [[ -f "${libpath}/${JAWTSO}" ]]; then
			export AWT_LIB_PATH="${libpath}"
			break
		# this is a workaround for broken LDPATH in <=openjdk-8.292_p10 and <=dev-java/openjdk-bin-8.292_p10
		elif [[ -f "${libpath}/$(tc-arch)/${JAWTSO}" ]]; then
			export AWT_LIB_PATH="${libpath}/$(tc-arch)"
			break
		fi
	done

	if [[ -z "${AWT_LIB_PATH}" ]]; then
		eerror "${JAWTSO} not found in the JDK being used for compilation!"
		die "cannot build AWT library"
	fi

	# Fix the pointer size for AMD64
	[[ ${ARCH} == "amd64" || ${ARCH} == "ppc64" ]] && export SWT_PTR_CFLAGS=-DJNI64

	local make="emake -f make_linux.mak NO_STRIP=y CC=$(tc-getCC) CXX=$(tc-getCXX)"

	einfo "Building AWT library"
	${make} make_awt

	einfo "Building SWT library"
	${make} make_swt

	einfo "Building JAVA-AT-SPI bridge"
	${make} make_atk

	if use cairo ; then
		einfo "Building CAIRO support"
		${make} make_cairo
	fi

	if use opengl ; then
		einfo "Building OpenGL component"
		${make} make_glx
	fi

	java-pkg-simple_src_compile
}

src_install() {
	swtArch=${ARCH}
	use amd64 && swtArch=x86_64

	sed "s/SWT_ARCH/${swtArch}/" "${FILESDIR}/${PN}-${SLOT}-manifest" > "MANIFEST_TMP.MF" || die
	use cairo || sed -i -e "/ org.eclipse.swt.internal.cairo; x-internal:=true,/d" "MANIFEST_TMP.MF"
	sed -i -e "/ org.eclipse.swt.internal.gnome; x-internal:=true,/d" "MANIFEST_TMP.MF" || die
	use opengl || sed -i -e "/ org.eclipse.swt.internal.opengl.glx; x-internal:=true,/d" "MANIFEST_TMP.MF"
	sed -i -e "/ org.eclipse.swt.internal.webkit; x-internal:=true,/d" "MANIFEST_TMP.MF" || die
	java-osgi_newjar-fromfile "swt.jar" "MANIFEST_TMP.MF" "Standard Widget Toolkit for GTK 2.0"

	java-pkg_sointo /usr/$(get_libdir)
	java-pkg_doso *.so

	docinto html
	dodoc about.html
}
