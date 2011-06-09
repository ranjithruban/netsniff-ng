/*
 * netsniff-ng - the packet sniffing beast
 * By Daniel Borkmann <daniel@netsniff-ng.org>
 * Partial Copyright 2011 Daniel Borkmann <dborkma@tik.ee.ethz.ch>,
 * Swiss federal institute of technology (ETH Zurich)
 * Subject to the GPL.
 */

/*
 *  seccure  -  Copyright 2009 B. Poettering
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License as
 *  published by the Free Software Foundation; either version 2 of the
 *  License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
 *  02111-1307 USA
 */

/* 
 *   SECCURE Elliptic Curve Crypto Utility for Reliable Encryption
 *
 *              http://point-at-infinity.org/seccure/
 *
 *
 * seccure implements a selection of asymmetric algorithms based on  
 * elliptic curve cryptography (ECC). See the manpage or the project's  
 * homepage for further details.
 *
 * This code links against the GNU gcrypt library "libgcrypt" (which
 * is part of the GnuPG project). Use the included Makefile to build
 * the binary.
 * 
 * Report bugs to: seccure AT point-at-infinity.org
 *
 */

#ifndef ECC_H
#define ECC_H

#include <gcrypt.h>

struct affine_point {
	gcry_mpi_t x, y;
};

struct jacobian_point {
	gcry_mpi_t x, y, z;
};

struct domain_params {
	gcry_mpi_t a, b, m, order;
	struct affine_point base;
	int cofactor;
};

extern struct affine_point point_new(void);
extern void point_release(struct affine_point *p);
extern void point_set(struct affine_point *p1, const struct affine_point *p2);
extern void point_load_zero(struct affine_point *p);
extern int point_is_zero(const struct affine_point *p);
extern int point_on_curve(const struct affine_point *p,
			  const struct domain_params *dp);
extern int point_compress(const struct affine_point *p);
extern int point_decompress(struct affine_point *p, const gcry_mpi_t x,
			    int yflag, const struct domain_params *dp);
extern void point_double(struct affine_point *p,
			 const struct domain_params *dp);
extern void point_add(struct affine_point *p1, const struct affine_point *p2,
		      const struct domain_params *dp);
extern struct jacobian_point jacobian_new(void);
extern void jacobian_release(struct jacobian_point *p);
extern void jacobian_load_affine(struct jacobian_point *p1,
				 const struct affine_point *p2);
extern void jacobian_load_zero(struct jacobian_point *p);
extern int jacobian_is_zero(const struct jacobian_point *p);
extern void jacobian_double(struct jacobian_point *p,
			    const struct domain_params *dp);
extern void jacobian_affine_point_add(struct jacobian_point *p1,
				      const struct affine_point *p2,
				      const struct domain_params *dp);
extern struct affine_point jacobian_to_affine(const struct jacobian_point *p,
					      const struct domain_params *dp);
extern struct affine_point pointmul(const struct affine_point *p,
				    const gcry_mpi_t exp,
				    const struct domain_params *dp);
extern int embedded_key_validation(const struct affine_point *p,
				   const struct domain_params *dp);
extern int full_key_validation(const struct affine_point *p,
			       const struct domain_params *dp);

#endif /* ECC_H */
