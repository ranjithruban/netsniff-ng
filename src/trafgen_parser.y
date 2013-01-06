/*
 * netsniff-ng - the packet sniffing beast
 * By Daniel Borkmann <daniel@netsniff-ng.org>
 * Copyright 2012 Daniel Borkmann <dborkma@tik.ee.ethz.ch>,
 * Swiss federal institute of technology (ETH Zurich)
 * Subject to the GPL, version 2.
 */

/* yaac-func-prefix: yy */

%{

#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <stdint.h>
#include <errno.h>

#include "xmalloc.h"
#include "trafgen_parser.tab.h"
#include "trafgen_conf.h"
#include "built_in.h"
#include "die.h"

#define YYERROR_VERBOSE		0
#define YYDEBUG			0
#define YYENABLE_NLS		1
#define YYLTYPE_IS_TRIVIAL	1
#define ENABLE_NLS		1

extern FILE *yyin;
extern int yylex(void);
extern void yyerror(const char *);
extern int yylineno;
extern char *yytext;

extern struct packet *packets;
extern size_t plen;
#define packet_last		(plen - 1)
#define payload_last		(packets[packet_last].len - 1)

extern struct packet_dyn *packet_dyn;
extern size_t dlen;
#define packetd_last		(dlen - 1)
#define packetdc_last		(packet_dyn[packetd_last].clen - 1)
#define packetdr_last		(packet_dyn[packetd_last].rlen - 1)

static int dfunc_note_flag = 0;

static void give_note_dynamic(void)
{
	if (!dfunc_note_flag) {
		printf("Note: dynamic elements like drnd, dinc, ddec and "
		       "others make trafgen slower!\n");
		dfunc_note_flag = 1;
	}
}

static inline void init_new_packet_slot(struct packet *slot)
{
	slot->payload = NULL;
	slot->len = 0;
}

static inline void init_new_counter_slot(struct packet_dyn *slot)
{
	slot->cnt = NULL;
	slot->clen = 0;
}

static inline void init_new_randomizer_slot(struct packet_dyn *slot)
{
	slot->rnd = NULL;
	slot->rlen = 0;
}

static void realloc_packet(void)
{
	plen++;
	packets = xrealloc(packets, 1, plen * sizeof(*packets));
	init_new_packet_slot(&packets[packet_last]);

	dlen++;
	packet_dyn = xrealloc(packet_dyn, 1, dlen * sizeof(*packet_dyn));
	init_new_counter_slot(&packet_dyn[packetd_last]);
	init_new_randomizer_slot(&packet_dyn[packetd_last]);
}

static void set_byte(uint8_t val)
{
	struct packet *pkt = &packets[packet_last];

	pkt->len++;
	pkt->payload = xrealloc(pkt->payload, 1, pkt->len);
	pkt->payload[payload_last] = val;
}

static void set_fill(uint8_t val, size_t len)
{
	int i;
	struct packet *pkt = &packets[packet_last];

	pkt->len += len;
	pkt->payload = xrealloc(pkt->payload, 1, pkt->len);
	for (i = 0; i < len; ++i)
		pkt->payload[payload_last - i] = val;
}

static void set_rnd(size_t len)
{
	int i;
	struct packet *pkt = &packets[packet_last];

	pkt->len += len;
	pkt->payload = xrealloc(pkt->payload, 1, pkt->len);
	for (i = 0; i < len; ++i)
		pkt->payload[payload_last - i] = (uint8_t) rand();
}

static void set_seqinc(uint8_t start, size_t len, uint8_t stepping)
{
	int i;
	struct packet *pkt = &packets[packet_last];

	pkt->len += len;
	pkt->payload = xrealloc(pkt->payload, 1, pkt->len);
	for (i = 0; i < len; ++i) {
		off_t off = len - 1 - i;

		pkt->payload[payload_last - off] = start;
		start += stepping;
	}
}

static void set_seqdec(uint8_t start, size_t len, uint8_t stepping)
{
	int i;
	struct packet *pkt = &packets[packet_last];

	pkt->len += len;
	pkt->payload = xrealloc(pkt->payload, 1, pkt->len);
	for (i = 0; i < len; ++i) {
		int off = len - 1 - i;

		pkt->payload[payload_last - off] = start;
		start -= stepping;
	}
}

static inline void setup_new_counter(struct counter *c, uint8_t start, uint8_t stop,
				     uint8_t stepping, int type)
{
	c->min = start;
	c->max = stop;
	c->inc = stepping;
	c->val = (type == TYPE_INC) ? start : stop;
	c->off = payload_last;
	c->type = type;
}

static inline void setup_new_randomizer(struct randomizer *r)
{
	r->val = (uint8_t) rand();
	r->off = payload_last;
}

static void set_drnd(void)
{
	struct packet *pkt = &packets[packet_last];
	struct packet_dyn *pktd = &packet_dyn[packetd_last];

	give_note_dynamic();

	pkt->len++;
	pkt->payload = xrealloc(pkt->payload, 1, pkt->len);

	pktd->rlen++;
	pktd->rnd = xrealloc(pktd->rnd, 1, pktd->rlen *	sizeof(struct randomizer));

	setup_new_randomizer(&pktd->rnd[packetdr_last]);
}

static void set_dincdec(uint8_t start, uint8_t stop, uint8_t stepping, int type)
{
	struct packet *pkt = &packets[packet_last];
	struct packet_dyn *pktd = &packet_dyn[packetd_last];

	give_note_dynamic();

	pkt->len++;
	pkt->payload = xrealloc(pkt->payload, 1, pkt->len);

	pktd->clen++;
	pktd->cnt =xrealloc(pktd->cnt, 1, pktd->clen * sizeof(struct counter));

	setup_new_counter(&pktd->cnt[packetdc_last], start, stop, stepping, type);
}

%}

%union {
	long int number;
}

%token K_COMMENT K_FILL K_RND K_SEQINC K_SEQDEC K_DRND K_DINC K_DDEC K_WHITE
%token K_NEWL

%token ',' '{' '}' '(' ')' '[' ']'

%token number

%type <number> number

%%

packets
	: { }
	| packets packet { }
	| packets inline_comment { }
	| packets white { }
	;

inline_comment
	: K_COMMENT { }
	;

packet
	: '{' delimiter payload delimiter '}' { realloc_packet(); }
	;

payload
	: elem { }
	| payload elem_delimiter { }
	;

white
	: white K_WHITE { }
	| white K_NEWL { }
	| K_WHITE { }
	| K_NEWL { }
	;

delimiter
	: ',' { }
	| white { }
	| ',' white { }
	;

elem_delimiter
	: delimiter elem { }
	;

fill
	: K_FILL '(' number delimiter number ')'
		{ set_fill($3, $5); }
	;

rnd
	: K_RND '(' number ')'
		{ set_rnd($3); }
	;

seqinc
	: K_SEQINC '(' number delimiter number ')'
		{ set_seqinc($3, $5, 1); }
	| K_SEQINC '(' number delimiter number delimiter number ')'
		{ set_seqinc($3, $5, $7); }
	;

seqdec
	: K_SEQDEC '(' number delimiter number ')'
		{ set_seqdec($3, $5, 1); }
	| K_SEQDEC '(' number delimiter number delimiter number ')'
		{ set_seqdec($3, $5, $7); }
	;

drnd
	: K_DRND '(' ')'
		{ set_drnd(); }
	| K_DRND '(' number ')'
		{
			int i, max = $3;
			for (i = 0; i < max; ++i)
				set_drnd();
		}
	;

dinc
	: K_DINC '(' number delimiter number ')'
		{ set_dincdec($3, $5, 1, TYPE_INC); }
	| K_DINC '(' number delimiter number delimiter number ')'
		{ set_dincdec($3, $5, $7, TYPE_INC); }
	;

ddec
	: K_DDEC '(' number delimiter number ')'
		{ set_dincdec($3, $5, 1, TYPE_DEC); }
	| K_DDEC '(' number delimiter number delimiter number ')'
		{ set_dincdec($3, $5, $7, TYPE_DEC); }
	;

elem
	: number { set_byte((uint8_t) $1); }
	| fill { }
	| rnd { }
	| drnd { }
	| seqinc { }
	| seqdec { }
	| dinc { }
	| ddec { }
	| inline_comment { }
	;

%%

static void finalize_packet(void)
{
	/* XXX hack ... we allocated one packet pointer too much */
	plen--;
	dlen--;
}

static void dump_conf(void)
{
	size_t i, j;

	for (i = 0; i < plen; ++i) {
		printf("[%zu] pkt\n", i);
		printf(" len %zu cnts %zu rnds %zu\n",
		       packets[i].len,
		       packet_dyn[i].clen,
		       packet_dyn[i].rlen);

		printf(" payload ");
		for (j = 0; j < packets[i].len; ++j)
			printf("%02x ", packets[i].payload[j]);
		printf("\n");

		for (j = 0; j < packet_dyn[i].clen; ++j)
			printf(" cnt%zu [%u,%u], inc %u, off %ld type %s\n", j,
			       packet_dyn[i].cnt[j].min,
			       packet_dyn[i].cnt[j].max,
			       packet_dyn[i].cnt[j].inc,
			       packet_dyn[i].cnt[j].off,
			       packet_dyn[i].cnt[j].type == TYPE_INC ?
			       "inc" : "dec");

		for (j = 0; j < packet_dyn[i].rlen; ++j)
			printf(" rnd%zu off %ld\n", j,
			       packet_dyn[i].rnd[j].off);
	}
}

void cleanup_packets(void)
{
	int i;

	for (i = 0; i < plen; ++i) {
		if (packets[i].len > 0)
			xfree(packets[i].payload);
	}

	free(packets);

	for (i = 0; i < dlen; ++i) {
		free(packet_dyn[i].cnt);
		free(packet_dyn[i].rnd);
	}

	free(packet_dyn);
}

int compile_packets(char *file, int verbose, int cpu)
{
	yyin = fopen(file, "r");
	if (!yyin)
		panic("Cannot open file!\n");

	realloc_packet();
	yyparse();
	finalize_packet();

	if (cpu == 0) {
		if (verbose) {
			dump_conf();
		} else {
			int i;
			size_t total_len = 0;

			printf("%6zu packets to schedule\n", plen);
			for (i = 0; i < plen; ++i)
				total_len += packets[i].len;
			printf("%6zu bytes in total\n", total_len);
		}
	}

	fclose(yyin);
	return 0;
}

void yyerror(const char *err)
{
	panic("Syntax error at line %d: '%s'! %s!\n", yylineno, yytext, err);
}
