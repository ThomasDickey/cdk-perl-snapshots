# Created by: Chia-liang Kao <clkao@clkao.org>
# $FreeBSD: devel/p5-Cdk/Makefile 315974 2013-04-17 15:33:37Z miwi $

PORTNAME=	Cdk
PORTVERSION=	5.0.20150928
PORTREVISION=	1
CATEGORIES=	devel perl5
MASTER_SITES=	ftp://invisible-island.net/cdk/
PKGNAMEPREFIX=	p5-
DISTNAME=	cdk-perl-20130816
EXTRACT_SUFX=	.tgz

MAINTAINER=	ports@FreeBSD.org
COMMENT=	Perl5 module for Curses Development Kit

LIB_DEPENDS=	cdk.5:${PORTSDIR}/devel/cdk

GNU_CONFIGURE=	yes
CONFIGURE_ENV+=	CPPFLAGS="-I${LOCALBASE}/include" LIBS="-L${LOCALBASE}/lib"

#PERL_CONFIGURE=	no
#
#post-patch:
#	${REINPLACE_CMD} 's,%%LOCALBASE%%,${LOCALBASE},g' ${WRKSRC}/Makefile.PL

.include <bsd.port.mk>
