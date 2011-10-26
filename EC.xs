#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <bufr_api.h>

typedef BUFR_Message* Geo__BUFR__EC__Message;
typedef BUFR_Dataset* Geo__BUFR__EC__Dataset;
typedef DataSubset* Geo__BUFR__EC__DataSubset;
typedef BUFR_Tables* Geo__BUFR__EC__Tables;
typedef EntryTableB* Geo__BUFR__EC__Tables__Entry__B;
typedef EntryTableD* Geo__BUFR__EC__Tables__Entry__D;
typedef BufrDescValue* Geo__BUFR__EC__DescValue;
typedef BufrDescriptor* Geo__BUFR__EC__Descriptor;
typedef BufrValue* Geo__BUFR__EC__Value;
typedef BUFR_Sequence* Geo__BUFR__EC__Sequence;
typedef BUFR_Template* Geo__BUFR__EC__Template;

static ssize_t appendsv( void *dsv, size_t len, const char *buffer ) {
	sv_catpvn((SV*)dsv, buffer, len);
}

/**********************************************************************/
/* We need to create objects which point into memory "owned" by other SV's.
 * We don't want those other SV's to get freed and leave us pointing at junk
 * memory so we increment the related count as well. In some cases, we may
 * not even want to free our own structure so we ensure the release
 * indicates whether or not a related object exists. In some cases, of course,
 * we may release both a related object and our own memory.
 * NOTE: some care may be needed to prevent circular references.
 */
static void hold_related(SV* sv, SV* related) {
	SvREFCNT_inc( related );
	sv_magic(SvRV(sv), NULL, '~', (void*)related, 0 );
}
static SV* release_related(SV* sv) {
	MAGIC* m = mg_find(SvRV(sv),'~');
	if( m && m->mg_ptr ) {
		SvREFCNT_dec( (SV*)(m->mg_ptr) );
		return (SV*)(m->mg_ptr);
	}
	return NULL;	/* no related */
}

/**********************************************************************/
/*
	Section 1 is best represented to the user as a hash table. However
	the data is embedded in a dataset or message. Hence we have a hash tied to
	a C structure with all the appropriate magic in between.
*/
typedef struct {
	const char* key;
	int keylen;
	int len;
	int offset;
} BufrSection1_key_t;

static BufrSection1_key_t s1keys[]= {
	{"orig_centre",sizeof("orig_centre")-1,4,offsetof(BufrSection1,orig_centre)},
	{"bufr_master_table",sizeof("bufr_master_table")-1,2,offsetof(BufrSection1,bufr_master_table)},
	{"orig_sub_centre",sizeof("orig_sub_centre")-1,2,offsetof(BufrSection1,orig_sub_centre)},
	{"upd_seq_no",sizeof("upd_seq_no")-1,2,offsetof(BufrSection1,upd_seq_no)},
	{"flag",sizeof("flag")-1,2,offsetof(BufrSection1,flag)},
	{"msg_type",sizeof("msg_type")-1,2,offsetof(BufrSection1,msg_type)},
	{"msg_inter_subtype",sizeof("msg_inter_subtype")-1,2,offsetof(BufrSection1,msg_inter_subtype)},
	{"msg_local_subtype",sizeof("msg_local_subtype")-1,2,offsetof(BufrSection1,msg_local_subtype)},
	{"master_table_version",sizeof("master_table_version")-1,2,offsetof(BufrSection1,master_table_version)},
	{"local_table_version",sizeof("local_table_version")-1,2,offsetof(BufrSection1,local_table_version)},
	{"year",sizeof("year")-1,2,offsetof(BufrSection1,year)},
	{"month",sizeof("month")-1,2,offsetof(BufrSection1,month)},
	{"day",sizeof("day")-1,2,offsetof(BufrSection1,day)},
	{"hour",sizeof("hour")-1,2,offsetof(BufrSection1,hour)},
	{"minute",sizeof("minute")-1,2,offsetof(BufrSection1,minute)},
	{"second",sizeof("second")-1,2,offsetof(BufrSection1,second)},
	{NULL,0,0,0},
};

typedef struct {
	SV* relatedsv;
	BufrSection1* s1;
} mg_section1;

static SV* new_section1(BufrSection1* s1, SV* relatedsv) {
	HV *hash;
	HV *stash;
	SV *tie;
	mg_section1* mgs1;
	int i;

	mgs1 = malloc(sizeof(mg_section1));
	mgs1->relatedsv = relatedsv;
	SvREFCNT_inc(relatedsv);
	mgs1->s1 = s1;

	hash = newHV();

	tie = newRV_noinc((SV*)newHV());
	stash = gv_stashpv("Geo::BUFR::EC::Section1", GV_ADD);
	sv_bless(tie, stash);
	hv_magic(hash, (GV*)tie, PERL_MAGIC_tied);

	sv_magic((SV*)SvRV(tie), NULL, '~', (void*)mgs1, 0 );

	for( i = 0; s1keys[i].key; i ++ ) {
		/* be lazy... put the keys in and we don't have to write
		 * our own iterator...
		 */
		hv_store((HV*)SvRV(tie), s1keys[i].key, s1keys[i].keylen, &PL_sv_undef, 0);
	}

	return newRV_noinc((SV*)hash);
}

static void free_section1(SV* hash) {
	MAGIC* m = mg_find(hash,'~');
	if( m && m->mg_ptr ) {
		mg_section1* mgs1 = (mg_section1*) m->mg_ptr;
		SvREFCNT_dec( mgs1->relatedsv );
		free( mgs1 );
	}
}

static BufrSection1* get_section1(SV* hash) {
	MAGIC* m = mg_find(hash,'~');
	if( m && m->mg_ptr ) {
		mg_section1* mgs1 = (mg_section1*) m->mg_ptr;
		if( mgs1 ) return mgs1->s1;
	}
	return NULL;
}

/**********************************************************************/
static SV* bufr_value_getset(BufrValue* bv, SV* setsv) {
	SV* rv = NULL;

	/* we always return a value... */
	if( bufr_value_is_missing(bv) ) {
		rv = &PL_sv_undef;
	} else {
		switch( bv->type ) {
			case VALTYPE_INT8:
			case VALTYPE_INT32:
			case VALTYPE_INT64:
				rv = newSViv(bufr_value_get_int64(bv));
				break;
			case VALTYPE_FLT32:
			case VALTYPE_FLT64:
				rv = newSVnv(bufr_value_get_double(bv));
				break;
			case VALTYPE_STRING: {
				int len;
				const char* s = bufr_value_get_string(bv,&len);
				rv = newSVpvn(s,len);
				break;
			}
			default:
				rv = NULL;
				break;
		}
	}
	if( setsv ) {
		/* assign second param to value */
		switch( bv->type ) {
			case VALTYPE_INT64:
				if( setsv == &PL_sv_undef ) {
					bufr_value_set_int64(bv,bufr_missing_int());
				} else {
					bufr_value_set_int64(bv,SvIV(setsv));
				}
				break;
			case VALTYPE_INT8:
			case VALTYPE_INT32:
				if( setsv == &PL_sv_undef ) {
					bufr_value_set_int32(bv,bufr_missing_int());
				} else {
					bufr_value_set_int32(bv,SvIV(setsv));
				}
				break;
			case VALTYPE_FLT32:
				if( setsv == &PL_sv_undef ) {
					bufr_value_set_float(bv,bufr_missing_float());
				} else {
					bufr_value_set_float(bv,SvNV(setsv));
				}
				break;
			case VALTYPE_FLT64:
				if( setsv == &PL_sv_undef ) {
					bufr_value_set_double(bv,bufr_missing_double());
				} else {
					bufr_value_set_double(bv,SvNV(setsv));
				}
				break;
			case VALTYPE_STRING: {
				STRLEN l;
				const char* s = SvPV(setsv,l);
				if( setsv == &PL_sv_undef || s==NULL ) {
					/* This assumes the value of the string is going to have
					 * a length which is meaningful for a missing value.
					 */
					char *tmpbuf;
					int len;
					const char* s = bufr_value_get_string(bv,&len);
					tmpbuf = (char *)malloc( (len+1)*sizeof(char) );
					if( tmpbuf == NULL ) croak("malloc failed!");
					bufr_missing_string( tmpbuf, len );
					bufr_value_set_string(bv,tmpbuf,len);
					free( tmpbuf );
				} else {
					bufr_value_set_string(bv,s,l);
				}
				break;
			}
			default:
				/* the return code from this function will indicate failure... */
				assert( rv == NULL );
				break;
		}
	}

	return rv;
}

/**********************************************************************/
static int compare_tableb_description(const void *p1, const void *p2) {
   EntryTableB *r1 = *(EntryTableB **)p1;
   EntryTableB *r2 = *(EntryTableB **)p2;
	return strcmp(r1->description, r2->description);
}


/*
Convert a perl SV to a numeric descriptor value. Inputs can be:
 * Geo::BUFR::EC::DescValue
 * Geo::BUFR::EC::Descriptor
 * Geo::BUFR::EC::Tables::Entry::B
 * Geo::BUFR::EC::Tables::Entry::D
 * integer
 * F-X-Y string
 * just a name, in which case a table lookup is done
*/
static int sv2desc( SV* sv, BUFR_Tables* tables ) {
	int f, x, y;

	if( sv_isobject(sv) ) {
		if( sv_derived_from(sv, "Geo::BUFR::EC::DescValue") ) {
			const BufrDescValue* myd = INT2PTR(BufrDescValue*,SvIV((SV*)SvRV(sv)));
			if( myd ) return myd->descriptor;
		} else if( sv_derived_from(sv, "Geo::BUFR::EC::Descriptor") ) {
			const BufrDescriptor* myd
				= INT2PTR(BufrDescriptor*,SvIV((SV*)SvRV(sv)));
			if( myd ) return myd->descriptor;
		} else if( sv_derived_from(sv, "Geo::BUFR::EC::Tables::Entry::B") ) {
			const EntryTableB* myd = INT2PTR(EntryTableB*,SvIV((SV*)SvRV(sv)));
			if( myd ) return myd->descriptor;
		} else if( sv_derived_from(sv, "Geo::BUFR::EC::Tables::Entry::D") ) {
			const EntryTableD* myd = INT2PTR(EntryTableD*,SvIV((SV*)SvRV(sv)));
			if( myd ) return myd->descriptor;
		}
	} else if( looks_like_number(sv) ) {
		return SvIV(sv);
	} else if( 3==sscanf(SvPV_nolen(sv),"%d-%d-%d",&f,&x,&y) ) {
		return bufr_fxy_to_descriptor(f,x,y);
	} else if( tables ) {
		/* do a name-based lookup */
		EntryTableB *ptr1, tb, **p;
		tb.description = SvPV_nolen(sv);
		ptr1 = &tb;

		if( tables->local.tableB ) {
			p = (EntryTableB **)arr_find( tables->local.tableB,
				(char *)&ptr1, compare_tableb_description );
			if( p ) return (*p)->descriptor;
		}
		if( tables->master.tableB ) {
			p = (EntryTableB **)arr_find( tables->master.tableB,
				(char *)&ptr1, compare_tableb_description );
			if( p ) return (*p)->descriptor;
		}
	}
	return 0;
}
/**********************************************************************/
static void my_output_handler( const char* msg ) {
	/* FIXME: might be excessive */
	warn("%s",msg);
}

static void my_debug_handler( const char* msg ) {
}

/**********************************************************************/
/* Global Data */

#define MY_CXT_KEY "Geo::BUFR::EC::_guts" XS_VERSION

typedef struct {
    /* Put Global Data in here */
    int dummy;		/* you can access this elsewhere as MY_CXT.dummy */
} my_cxt_t;

START_MY_CXT

MODULE = Geo::BUFR::EC		PACKAGE = Geo::BUFR::EC		

=head1 NAME

Geo::BUFR::EC - Perl extension for the LibECBUFR library

=head1 SYNOPSIS

  use Geo::BUFR::EC;

=head1 DESCRIPTION

Geo::BUFR::EC is an object-oriented perl interface to the LibECBUFR
library. It can be used to read and write editions 2 through 5 of
the WMO FM-94 specification, although some of the more advanced features
of LibECBUFR are still missing.

=head2 EXPORT

None by default.

=head1 SEE ALSO

L<http://launchpad.net/libecbufr>

L<http://www.wmo.int/pages/prog/www/WMOCodes.html>

=head1 AUTHOR

Christophe Beauregard, E<lt>chris.beauregard@ec.gc.caE<gt>,
E<lt>cpb@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Licence:
Copyright Her Majesty The Queen in Right of Canada, Environment Canada, 2009-2010.
Copyright Sa Majeste la Reine du Chef du Canada, Environnement Canada, 2009-2010.

    libECBUFR is free software: you can redistribute it and/or modify
    it under the terms of the Lesser GNU General Public License,
    version 3, as published by the Free Software Foundation.

    libECBUFR is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    Lesser GNU General Public License for more details.

    You should have received a copy of the Lesser GNU General Public
    License along with libECBUFR.  If not, see <http://www.gnu.org/licenses/>.

=cut

BOOT:
{
    MY_CXT_INIT;
    /* If any of the fields in the my_cxt_t struct need
       to be initialised, do it here.
     */

	bufr_begin_api();

	bufr_set_output_handler( my_output_handler );
	bufr_set_debug_handler( my_debug_handler );
}

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Tables

=head1 Geo::BUFR::EC::Tables

A BUFR tables holder. Contains both Table B and D entries.

=cut

Geo::BUFR::EC::Tables
new(packname="Geo::BUFR::EC::Tables")
		char* packname
	CODE:
		RETVAL = bufr_create_tables();
		if( RETVAL == NULL ) XSRETURN_UNDEF;
	OUTPUT:
		RETVAL

=head2 $tables->master_version([$value])

Returns the version number of the master tables. May be C<undef> if
the master table hasn't been loaded or couldn't be determined from the
loaded file. The value may be set to a new C<$value>, as well, in which
case it returns the old value.

=head2 $tables->local_version([$value])

Returns the version number of the local tables. May be C<undef> if the
local table hasn't been loaded or couldn't be determined from the loaded
file. The value may be set to a new C<$value>, as well, in which case
it returns the old value.

=head2 $tables->data_cat([$value,$desc])

Returns the data category of the tables. May be C<undef> if it hasn't
already been determined. The value may be set to a new C<$value>
(with text description C<$desc>), as well, in which case it returns the
old value.

=cut

int master_version(tables,newval=0,desc=NULL)
		Geo::BUFR::EC::Tables tables
		int newval
		char* desc
	ALIAS:
		local_version = 1
		data_cat = 2
	CODE:
		switch(ix) {
			case 0:
				RETVAL = tables->master.version;
				if( items == 2 && newval ) tables->master.version = newval;
				break;
			case 1:
				RETVAL = tables->local.version;
				if( items == 2 && newval ) tables->local.version = newval;
				break;
			case 2:
				RETVAL = tables->data_cat;
				if( items >= 2 && newval ) {
					bufr_set_tables_category( tables, newval, desc );
				}

				break;
		}
		if(RETVAL==0) XSRETURN_UNDEF;
	OUTPUT:
		RETVAL
	
=head2 $tables->data_cat_desc()

Returns the textual data category description of the tables.
May be C<undef> if it hasn't already been determined.

=cut

char*
data_cat_desc(tables)
		Geo::BUFR::EC::Tables tables
	CODE:
		RETVAL = tables->data_cat_desc;
		if( strlen(RETVAL)==0
			|| strspn(RETVAL," ")==sizeof(tables->data_cat_desc)-1
		) {
			/* bufr_set_tables_category() fills with spaces... */
			XSRETURN_UNDEF;
		}
	OUTPUT:
		RETVAL

void
DESTROY(tables)
		Geo::BUFR::EC::Tables tables
	CODE:
		if( tables ) bufr_free_tables( tables );

=head2 $tables->cmc([$tabled,$tableb])

Loads the default set of CMC BUFR tables into C<$tables> as found by
the C<BUFR_TABLES> environment variable. If missing falls back to the
LibECBUFR default location. If files C<$tabled> or C<$tableb> are provided,
CMC-formatted tables will be read from those (both local and master, as per CMC
practice).

=cut

void
cmc(tables,tabled=NULL,tableb=NULL)
		Geo::BUFR::EC::Tables tables
		char* tabled
		char* tableb
	CODE:
		if( tabled || tableb ) {
			if( tabled ) {
				if( bufr_load_m_tableD( tables, tabled ) ) {
					warn("Failed to load Table D master %s", tabled);
				}
				if( bufr_load_l_tableD( tables, tabled ) ) {
					warn("Failed to load Table D local %s", tabled);
				}
			}
			if( tableb ) {
				if( bufr_load_m_tableB( tables, tableb ) ) {
					warn("Failed to load Table B master %s", tableb);
				}
				if( bufr_load_l_tableB( tables, tableb ) ) {
					warn("Failed to load Table B local %s", tableb);
				}
			}
		} else {
			bufr_load_cmc_tables( tables );
		}

=head2 $tables->lookup($desc)

Looks up bufr descriptor C<$desc> in the loaded <$tables>. Depending on the type
of descriptor it may return a C<Geo::BUFR::EC::Tables::Entry::B> or
C<Geo::BUFR::EC::Tables::Entry::D> object, or C<undef> on failure.

C<$desc> may be an integer value, a C<Geo::BUFR::EC::DescValue> object,
a string of the form F-X-Y, or a BUFR element description, in which case
a search through the table B for that name will be performed.
C<Geo::BUFR::EC::Tables::Entry::B> and C<Geo::BUFR::EC::Tables::Entry::D>
objects are also accepted, which might be a useful way to compare different
tables.

=cut

void
lookup(tables,desc)
		Geo::BUFR::EC::Tables tables
		SV* desc
	PREINIT:
		int d = 0;
		SV* tablessv = ST(0);
	PPCODE:
		d = sv2desc( desc, tables );
		if( !bufr_is_descriptor(d) ) {
			XSRETURN_UNDEF;
		} else if( bufr_is_table_b(d) ) {
			EntryTableB* tb = bufr_fetch_tableB( tables, d);
			if( tb == NULL ) XSRETURN_UNDEF;
			ST(0) = sv_newmortal();
			sv_setref_pv(ST(0), "Geo::BUFR::EC::Tables::Entry::B", (void*)tb);
			hold_related(ST(0), tablessv);
		} else {
			EntryTableD* td = bufr_fetch_tableD( tables, d);
			if( td == NULL ) XSRETURN_UNDEF;
			ST(0) = sv_newmortal();
			sv_setref_pv(ST(0), "Geo::BUFR::EC::Tables::Entry::D", (void*)td);
			hold_related(ST(0), tablessv);
		}
		XSRETURN(1);

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Tables::Entry::B

=head1 Geo::BUFR::EC::Tables::Entry::B

Table B entry.

=cut

Geo::BUFR::EC::Tables::Entry::B
new(packname="Geo::BUFR::EC::Tables::Entry::B")
		char* packname
	CODE:
		/* empty for now */
	OUTPUT:
		RETVAL
	
void
DESTROY(eb)
		Geo::BUFR::EC::Tables::Entry::B eb
	CODE:
		if( !release_related(ST(0)) ) bufr_free_EntryTableB( eb );

=head2 $eb->description()

Returns the description text for Table B entry C<$eb>.

=head2 $eb->unit()

Returns the units text for Table B entry C<$eb>.

=cut

char*
description(eb)
		Geo::BUFR::EC::Tables::Entry::B eb
	ALIAS:
		unit = 1
	CODE:
		if( ix == 1 ) {
			RETVAL = eb->unit;
		} else {
			RETVAL = eb->description;
		}
	OUTPUT:
		RETVAL

=head2 $eb->descriptor()

Returns the BUFR descriptor value for C<$eb>.

=head2 $eb->scale()

Returns the scale value for C<$eb>.

=head2 $eb->reference()

Returns the reference value for C<$eb>.

=head2 $eb->nbits()

Returns the number of bits used for C<$eb>.

=cut

int
descriptor(eb)
		Geo::BUFR::EC::Tables::Entry::B eb
	ALIAS:
		scale = 1
		reference = 2
		nbits = 3
	CODE:
		/* NOTE: af_nbits not implemented here... doesn't seem right to have that
		 * in a table entry.
		 */
		switch(ix) {
			case 1:
				RETVAL = eb->encoding.scale;
				break;
			case 2:
				RETVAL = eb->encoding.reference;
				break;
			case 3:
				RETVAL = eb->encoding.nbits;
				break;
			default:
				RETVAL = eb->descriptor;
				break;
		}
	OUTPUT:
		RETVAL

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Tables::Entry::D

=head1 Geo::BUFR::EC::Tables::Entry::D

Table D entry.

=cut

Geo::BUFR::EC::Tables::Entry::D
new(packname="Geo::BUFR::EC::Tables::Entry::D")
		char* packname
	CODE:
		/* empty for now */
	OUTPUT:
		RETVAL
	
void
DESTROY(ed)
		Geo::BUFR::EC::Tables::Entry::D ed
	CODE:
		if( !release_related(ST(0)) ) bufr_free_EntryTableD( ed );

=head2 $ed->descriptor()

Returns the BUFR descriptor value for C<$ed>.

=cut

int
descriptor(ed)
		Geo::BUFR::EC::Tables::Entry::D ed
	CODE:
		RETVAL = ed->descriptor;
	OUTPUT:
		RETVAL

=head2 $ed->description()

Returns the plain text description for C<$ed>, if any.

=cut

char*
description(ed)
		Geo::BUFR::EC::Tables::Entry::D ed
	CODE:
		RETVAL = ed->description;
	OUTPUT:
		RETVAL

=head2 $ed->descriptors()

Returns the ordered list of descriptors associated with the BUFR
template/sequence C<$ed>.

=cut

void
descriptors(ed)
		Geo::BUFR::EC::Tables::Entry::D ed
	PREINIT:
		int count, i;
	PPCODE:
		count = ed->count;
		if( count <= 0 ) XSRETURN_EMPTY;	/* should never happen */
		EXTEND(SP,count);
		for( i = 0; i < count; i ++ ) {
			ST(i) = sv_2mortal(newSViv(ed->descriptors[i]));
		}
		XSRETURN(count);

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Template

=head1 Geo::BUFR::EC::Template

A BUFR Template. Primarily used to generate new messages

=head2 Geo::BUFR::EC::Template->new($tables,edition=4,...)

Instantiate a new template using the specified C<$tables> and (optional)
edition. A list of L<Geo::BUFR::EC::DescValue> objects may be passed in
as a list, and more can be added later via the C<add_DescValue> method.

Note that the template must be finalized before being used.

=cut

Geo::BUFR::EC::Template
new(packname="Geo::BUFR::EC::Template",tables,edition=4,...)
		char* packname
		Geo::BUFR::EC::Tables tables
		int edition
	PREINIT:
		int i;
	CODE:
		/* NOTE: this copies the tables so we don't have to hold them as
		 * being related */
		RETVAL = bufr_create_template( NULL, 0, tables, edition);
		if( RETVAL == NULL ) XSRETURN_UNDEF;

		/* not the most efficient, but easier than building a temp
		 * descval array
		 */
		for( i = 3; i < items; i ++ ) {
			if( sv_isobject(ST(i)) && sv_derived_from(ST(i), "Geo::BUFR::EC::DescValue") ) {
				BufrDescValue* d = INT2PTR(BufrDescValue*,SvIV((SV*)SvRV(ST(i))));
				bufr_template_add_DescValue( RETVAL, d, 1 );
			} else {
				croak("Expecting a Geo::BUFR::EC::DescValue");
			}
		}
	OUTPUT:
		RETVAL
	
void
DESTROY(tmpl)
		Geo::BUFR::EC::Template tmpl
	CODE:
		if( tmpl ) bufr_free_template(tmpl);

=head2 $template->add_DescValue(@values)

Add a list of L<Geo::BUFR::EC::DescValue> objects to an unfinalized
C<$template>.

=cut

void
add_DescValue(tmpl,...)
		Geo::BUFR::EC::Template tmpl
	PREINIT:
		int i;
	CODE:
		for( i = 1; i < items; i ++ ) {
			if( sv_isobject(ST(i)) && sv_derived_from(ST(i), "Geo::BUFR::EC::DescValue") ) {
				BufrDescValue* d = INT2PTR(BufrDescValue*,SvIV((SV*)SvRV(ST(i))));
				bufr_template_add_DescValue( tmpl, d, 1 );
			} else {
				croak("Expecting a Geo::BUFR::EC::DescValue");
			}
		}

=head2 $template->finalize()

Finalize the template. This allows it to be used to build a message.

=cut

void
finalize(tmpl,...)
		Geo::BUFR::EC::Template tmpl
	CODE:
		bufr_finalize_template( tmpl );

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::DescValue

=head1 Geo::BUFR::EC::DescValue

This object is a descriptor with a (possibly empty) list of associated values.
Mainly used in template building where a sequence needs a set of values. Value
may, of course, be "missing".

=head2 Geo::BUFR::EC::DescValue->new($desc,[@values]);

Creates a new L<Geo::BUFR::EC::DescValue> object. By default the values
will be undefined/missing. The C<@values> list is expected to contain
L<Geo::BUFR::EC::Value> objects.

Note that L<Geo::BUFR::EC::Value> is never instantiated directly; a descriptor
of some sort is needed to determine type information for a value, and hence some
association with a table is necessary along the way (with the exception of some
Table C descriptors like 2-05-YYY).  Hence the following
approaches would be valid to create a L<Geo::BUFR::EC::DescValue> for
a Table B descriptor with a non-missing value:

	my $d = Geo::BUFR::EC::Descriptor->new($tables,$desc);
	$d->set( $value );
	my $dv = Geo::BUFR::EC::DescValue->new( $desc, $d->value() );

	my $dv2 = Geo::BUFR::EC::DescValue->new( $desc2 );
	$dv2->add_Value($tables->lookup($dv2->descriptor()))->set($value2);

However, in some cases a L<Geo::BUFR::EC::Descriptor> can't be
instantiated for a particular BUFR descriptor (i.e. Table C or Table
B/D descriptors not yet in the tables), in which case it's necessary
to manually create a value for the L<Geo::BUFR::EC::DescValue> object
using the L<Geo::BUFR::EC::DescValue::add_Value()> method.

	my $dv = Geo::BUFR::EC::DescValue->new( $desc );
	...
	$dv->add_Value()->set($value);

L<Geo::BUFR::EC::DescValue> value sequences are also used for searching. More on
that later.

=cut

Geo::BUFR::EC::DescValue
new(packname="Geo::BUFR::EC::DescValue",desc,...)
      char* packname
		SV* desc
	CODE:
		RETVAL = malloc(sizeof(BufrDescValue));
		if( RETVAL == NULL ) XSRETURN_UNDEF;
		bufr_init_DescValue( RETVAL );

		RETVAL->descriptor = sv2desc(desc,NULL);
		if( !bufr_is_descriptor(RETVAL->descriptor) ) {
			XSRETURN_UNDEF;
		}

		if( items > 2 ) {
			int i;
			bufr_valloc_DescValue(RETVAL, items-2);
			for( i = 2; i < items; i ++ ) {
				if (sv_derived_from(ST(i), "Geo::BUFR::EC::Value")) {
					IV tmp = SvIV((SV*)SvRV(ST(i)));
					BufrValue* d = INT2PTR(BufrValue*,tmp);
					RETVAL->values[i-2] = bufr_duplicate_value(d);
				} else {
					croak("Expecting a Geo::BUFR::EC::Value");
				}
			}
		}
	OUTPUT:
		RETVAL

void
DESTROY(dv)
		Geo::BUFR::EC::DescValue dv
	CODE:
		bufr_vfree_DescValue(dv);
		free( dv );

=head2 $dv->descriptor($newval=0)

Returns the descriptor for the C<$dv>. Optionally, the caller
can provide a new descriptor C<$newval>, in which case the old value will be
returned.

=cut 

int
descriptor(dv,newval=0)
		Geo::BUFR::EC::DescValue dv
		int newval
	CODE:
		RETVAL = dv->descriptor;
		if( newval ) dv->descriptor = newval;
	OUTPUT:
		RETVAL

=head2 $dv->value($pos=0)

Returns a L<Geo::BUFR::EC::Value> value for C<$dv>. Since more than
one value is possible, an optional C<$pos> parameter is provided.

Note that positions are indexed from zero.

=cut 

Geo::BUFR::EC::Value
value(dv,pos=0)
		Geo::BUFR::EC::DescValue dv
		int pos
	PREINIT:
		SV* relatedsv = ST(0);
	CODE:
		if( dv->values == NULL ) XSRETURN_UNDEF;
		if( pos < 0 || pos >= dv->nbval ) XSRETURN_UNDEF;
		RETVAL = dv->values[pos];
	OUTPUT:
		RETVAL
	CLEANUP:
		hold_related(ST(0),relatedsv);

=head2 $dv->count_values()

Returns the number of values for a given L<Geo::BUFR::EC::DescValue>. Note that
there's a difference between having a value and having the right kind of value
for a descriptor, or having a usable value.

=cut

int
count_values(dv)
		Geo::BUFR::EC::DescValue dv
	CODE:
		RETVAL = dv->nbval;
	OUTPUT:
		RETVAL

=head2 $dv->add_Value($desc=0)

Creates a new L<Geo::BUFR::EC::Value> at the end of the list and returns it.
The descriptor C<$desc> can be either a L<Geo::BUFR::EC::Tables::Entry::B> object or
a Table C operator. If not provided, the existing C<$dv> descriptor will be
used, if possible. Only _very_ rarely would the descriptor argument be provided
which would not match that of the L<Geo::BUFR::EC::DescValue> descriptor itself.

Note that the only usable Table C operator is presently 2-05-YYY.

=cut

Geo::BUFR::EC::Value
add_Value(dv,desc=NULL)
		Geo::BUFR::EC::DescValue dv
		SV* desc
	PREINIT:
		SV* relatedsv = ST(0);
		int pos;
		int          vlen;
		ValueType    vtype;
		BufrValue*   bv = NULL;
	CODE:
		if( items == 2 ) {
			if( sv_isobject(desc) && sv_derived_from(desc, "Geo::BUFR::EC::Tables::Entry::B") ) {
				EntryTableB* e = INT2PTR(EntryTableB*,SvIV((SV*)SvRV(desc)));
				vtype = bufr_encoding_to_valtype( &(e->encoding) );
				vlen = e->encoding.nbits / 8;
			} else {
				int idesc = SvIV(desc);
				vtype = bufr_datatype_to_valtype(
					bufr_descriptor_to_datatype( NULL, NULL, idesc, &vlen ), 32, 0 );
			}
		} else {
			vtype = bufr_datatype_to_valtype(
				bufr_descriptor_to_datatype( NULL, NULL, dv->descriptor, &vlen ), 32, 0 );
		}

		/* try to create a value. Note that depending on the type/len, we might
		 * create something useless. Rather than trying to guess which combos
		 * give us junk (i.e. deep knowledge of library internals), just try it
		 * and toss anything we can't use.
		 */
		bv = bufr_create_value( vtype );
		if( bv == NULL ) XSRETURN_UNDEF;
		if( bv->type == VALTYPE_UNDEFINE ) {
			bufr_free_value( bv );
			XSRETURN_UNDEF;
		}

		/* Got a value, add it to the list and pass it back */
		pos = dv->nbval;
		if( 0!=bufr_vgrow_DescValue(dv,dv->nbval+1) ) {
			bufr_free_value( bv );
			XSRETURN_UNDEF;
		}
		RETVAL = dv->values[pos] = bv;
	OUTPUT:
		RETVAL
	CLEANUP:
		hold_related(ST(0),relatedsv);

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Dataset

=head1 Geo::BUFR::EC::Dataset

Essentially, this is the content of BUFR section 4. Data subsets are extracted
from this object.

=cut

Geo::BUFR::EC::Dataset
new(packname="Geo::BUFR::EC::Dataset",tmpl)
      char* packname
		Geo::BUFR::EC::Template tmpl
	CODE:
		/* NOTE: this implicitly makes a copy of the template */
		RETVAL = bufr_create_dataset(tmpl);
		if( RETVAL == NULL ) XSRETURN_UNDEF;
	OUTPUT:
		RETVAL

void
DESTROY(dts)
		Geo::BUFR::EC::Dataset dts
	CODE:
		if( dts ) bufr_free_dataset(dts);

=head2 $dts->section1()

Get the L<Geo::BUFR::EC::Section1> from the dataset. Note that this I<is>
the DataSet's section 1, not just a copy, and changing it will change the
dataset. It's expected the user will do this for encoding purposes.

=cut

SV*
section1(dts)
		Geo::BUFR::EC::Dataset dts
	PREINIT:
		SV* relatedsv = ST(0);
	CODE:
		RETVAL = new_section1(&(dts->s1), relatedsv);
	OUTPUT:
		RETVAL

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Dataset     PREFIX = bufr_

=head2 $dataset->expand_datasubset($pos=0)

Expands a descriptors sequence of a datasubset by resolving any Table D,
replications or delayed replications once the delayed replication 
counter has been set (value of descriptor 31001 that follows).

	my $dts = Geo::BUFR::EC::Dataset->new($tmpl);
	my $ds = Geo::BUFR::EC::DataSubset->new($dts);

	my $pos = $ds->find_descriptor(31001);
	my $desc = $ds->get_descriptor($pos);
	$desc->set(8);
	$dts->expand_datasubset();

	# now we'll see eight copies in $ds of whatever was being
	# replicated

=cut

int
bufr_expand_datasubset(dts,pos=0)
		Geo::BUFR::EC::Dataset dts
		int pos

=head2 $dataset->count_datasubset()

Returns the number of datasubsets in the C<$dataset>.

=cut

int
bufr_count_datasubset(dts)
		Geo::BUFR::EC::Dataset dts

=head2 $dataset->get_datasubset($pos=0)

Get the L<Geo::BUFR::EC::DataSubset> object in the specified position C<$pos>.
Note that this is not a copy, and changing the values in the subset will change
the message. Obviously, this is expected while encoding. Positions are indexed
from zero.

=cut

Geo::BUFR::EC::DataSubset
bufr_get_datasubset(dts,pos=0)
		Geo::BUFR::EC::Dataset dts
		int pos
	PREINIT:
		SV* dtssv = ST(0);
	CLEANUP:
		hold_related(ST(0), dtssv);

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Section1

=head1 Geo::BUFR::EC::Section1

Section 1 of a BUFR message. Can only be referenced from a dataset or
(decoded) message object.

This object is a hash containing the following fields: hour,
master_table_version, month, flag, upd_seq_no, bufr_master_table, day,
orig_centre, msg_inter_subtype, msg_type, second, orig_sub_centre, msg_local_subtype,
local_table_version, minute, year.

All fields are integers. Years are absolute values (not relative to 1900
as per L<gmtime> convention), although century may be omitted for older editions.
Month is indexed from 1 rather than zero.

=cut

void
DESTROY(s1)
		SV* s1
	PPCODE:
		free_section1( SvRV(ST(0)) );

SV*
FETCH(self, key)
		SV* self;
		SV* key;
	PREINIT:
		char   *k;
		STRLEN klen;
		BufrSection1* s1;
		int i, val;
	CODE:
		s1 = get_section1(SvRV(self));
		k = SvPV(key, klen);
		for( i = 0; s1keys[i].key; i ++ ) {
			if( klen==s1keys[i].keylen && !strncmp(k,s1keys[i].key,klen) ) {
				char* p = (char*)(((char*)s1) + s1keys[i].offset);
				if( s1keys[i].len == 2 ) {
					val = *(short*)p;
				} else if( s1keys[i].len == 4 ) {
					val = *(int*)p;
				} else {
					croak("unhandled data length");
				}
				break;
			}
		}
		if( s1keys[i].key==NULL ) RETVAL = &PL_sv_undef;
		else RETVAL = newSViv(val);
	OUTPUT:
		RETVAL

SV*
STORE(self, key, value)
		SV* self;
		SV* key;
		SV* value;
	PREINIT:
		char   *k;
		STRLEN klen;
		BufrSection1* s1;
		int val;
		int i;
	CODE:
		s1 = get_section1(SvRV(self));
		k = SvPV(key, klen);
		for( i = 0; s1keys[i].key; i ++ ) {
			if( klen==s1keys[i].keylen && strEQ(k,s1keys[i].key) ) {
				char* p = (char*)(((char*)s1) + s1keys[i].offset);
				if( s1keys[i].len == 2 ) {
					short* d = (short*)p;
					val = *d;
					*d = SvIV(value);
				} else if( s1keys[i].len == 4 ) {
					int* d = (int*)p;
					val = *d;
					*d = SvIV(value);
				} else {
					croak("unhandled data length");
				}
				break;
			}
		}
		if( s1keys[i].key==NULL ) RETVAL = &PL_sv_undef;
		else RETVAL = newSViv(val);
	OUTPUT:
		RETVAL

bool
EXISTS(self, key)
   SV* self;
   SV* key;
CODE:
	RETVAL = hv_exists_ent((HV*)SvRV(self), key, 0);
OUTPUT:
   RETVAL

SV*
FIRSTKEY(self)
   SV* self;
PREINIT:
   HE *he;
PPCODE:
   self = SvRV(self);
   hv_iterinit((HV*)self);
   if (he = hv_iternext((HV*)self))
      {
      EXTEND(sp, 1);
      PUSHs(hv_iterkeysv(he));
      }

SV*
NEXTKEY(self, lastkey)
   SV* self;
   SV* lastkey;
PREINIT:
   HE *he;
PPCODE:
   self = SvRV(self);
   if (he = hv_iternext((HV*)self))
      {
      EXTEND(sp, 1);
      PUSHs(hv_iterkeysv(he));
      }

################################################################################
MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Message

=head1 Geo::BUFR::EC::Message

A BUFR message used either for encoding or decoding.

For encoding, the caller will have gone through the process of loading tables,
building a template, creating a dataset, filling out the datasubsets, and the
resulting dataset will then be passed to the L<Geo::BUFR::EC::Message::encode>
contructor.

For decoding, the caller will have the message in memory as a string and will
call the L<Geo::BUFR::EC::Message::fromString> constructor, use the section 1
information to find and load the most appropriate tables, then the
L<Geo::BUFR::EC::Message::decode> method to get a dataset.

=head2 Geo::BUFR::EC::Message->encode($dts,$compress=1)

Encode a L<Geo::BUFR::EC::Dataset> to get a BUFR message. Compression is
optional. The resulting message would normally then be converted to a string and
output.

=cut

Geo::BUFR::EC::Message
encode(packname="Geo::BUFR::EC::Message",dts,compress=1)
		char *packname
		Geo::BUFR::EC::Dataset dts
		int compress
	CODE:
		RETVAL = bufr_encode_message(dts,compress);
	OUTPUT:
		RETVAL

=head2 $msg->decode($tables)

Decode the message using the provided C<$tables>, returning a
L<Geo::BUFR::EC::Dataset>.

=cut

Geo::BUFR::EC::Dataset
decode(msg,tables)
		Geo::BUFR::EC::Message msg
		Geo::BUFR::EC::Tables tables
	CODE:
		RETVAL = bufr_decode_message(msg,tables);
		if( RETVAL == NULL ) XSRETURN_UNDEF;
	OUTPUT:
		RETVAL

=head2 $msg->toString()

Returns the encoded message as a binary string.

Note: see the section in "Implicit upgrading for byte strings" in the
L<encoding> man page if you're planning on combining the BUFR string with, say,
a WMO header string.

=cut

SV*
toString(msg)
		Geo::BUFR::EC::Message msg
	CODE:
		RETVAL = newSVpvn("",0);
		if( bufr_callback_write_message( appendsv, (void*)RETVAL, msg ) ) {
			XSRETURN_UNDEF;
		}
	OUTPUT:
		RETVAL

=head2 $msg->fromString($string)

Reads in a string containing a BUFR message and returns a
L<Geo::BUFR::EC::Message> object. The string may contain a certain amount of
pre-amble (i.e. a WMO message header). The is the first step in a message
decode.

=cut

Geo::BUFR::EC::Message
fromString(packname="Geo::BUFR::EC::Message",s)
		char *packname
		SV* s
	PREINIT:
		STRLEN l;
		const char* ps;
	CODE:
		ps = SvPVbyte(s,l);
		if(bufr_memread_message(ps,l,&RETVAL)<=0) {
			XSRETURN_UNDEF;
		}
	OUTPUT:
		RETVAL

void
DESTROY(msg)
		Geo::BUFR::EC::Message msg
	CODE:
		if( msg ) bufr_free_message(msg);

=head2 $message->section1()

Get the L<Geo::BUFR::EC::Section1> from the C<$message>.

=cut

SV*
section1(msg)
		Geo::BUFR::EC::Message msg
	PREINIT:
		SV* relatedsv = ST(0);
	CODE:
		RETVAL = new_section1(&(msg->s1), relatedsv);
	OUTPUT:
		RETVAL

=head2 $message->section2([$newval])

Get/set the contents of (optional) BUFR section 2 of the message. Returns undef
if there is no content in section 2. If a new value is provided, it returns the
previous content.

=cut

SV*
section2(msg,newval=NULL)
		Geo::BUFR::EC::Message msg
		SV* newval
	CODE:
		if( msg->s2.data != NULL && msg->s2.data_len>0 ) {
			RETVAL = newSVpvn(msg->s2.data, msg->s2.data_len);
		} else {
			RETVAL = &PL_sv_undef;
		}
		if( items > 1 ) {
			STRLEN l;
			char* s = SvPV(ST(1), l);
			bufr_sect2_set_data(msg, s, l);
		}
	OUTPUT:
		RETVAL


=head2 $message->edition()

Get the BUFR edition value from the C<$message>.

=cut

int
edition(msg)
		Geo::BUFR::EC::Message msg
	CODE:
		RETVAL = msg->edition;
	OUTPUT:
		RETVAL

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::DataSubset

=head1 Geo::BUFR::EC::DataSubset

A set of descriptor/value pairs.

=head2 Geo::BUFR::EC::DataSubset->new($dts)

Create a new datasubset in the specified dataset C<$dts>. Note that the
datasubset will be initialized according to the dataset template used for
encoding. The datasubset is added as the last element in the dataset, so one
can use C<$dts->count_datasubset()-1> if necessary to calculate the index.

=cut

Geo::BUFR::EC::DataSubset
new(packname="Geo::BUFR::EC::DataSubset",dts)
		char* packname
		Geo::BUFR::EC::Dataset dts
	PREINIT:
		int n;
		SV* dtssv = ST(1);
	CODE:
		n = bufr_create_datasubset(dts);
		if( n < 0 ) XSRETURN_UNDEF;
		RETVAL = bufr_get_datasubset( dts, n );
	OUTPUT:
		RETVAL
	CLEANUP:
		hold_related(ST(0), dtssv);

void
DESTROY(ds)
		Geo::BUFR::EC::DataSubset ds
	CODE:
		/* Note that datasubsets can't existing independent on a dataset, so we'll
		 * never need to actually free one. We will, however, probably hold a ref
		 * to the dataset object.
		 */ 
		release_related(ST(0));

=head2 $subset->find_descriptor($desc,$startpos=0)

Finds a descriptor C<$desc>, returning the position in the datasubset (for
retrieval via L<Geo::BUFR::EC::DataSubset::get_descriptor>) or C<undef> on
failure.

=cut

int
find_descriptor(ds,desc,startpos=0)
		Geo::BUFR::EC::DataSubset ds
		int desc
		int startpos
	CODE:
		RETVAL = bufr_subset_find_descriptor(ds,desc,startpos);
		if( RETVAL < 0 ) XSRETURN_UNDEF;
	OUTPUT:
		RETVAL

MODULE = Geo::BUFR::EC PACKAGE = Geo::BUFR::EC::DataSubset PREFIX = bufr_datasubset_

int
bufr_datasubset_count_descriptor(ds)
		Geo::BUFR::EC::DataSubset ds

Geo::BUFR::EC::Descriptor
bufr_datasubset_get_descriptor(ds,pos)
		Geo::BUFR::EC::DataSubset ds
		int pos
	PREINIT:
		SV* relatedsv = ST(0);
	CLEANUP:
		hold_related(ST(0),relatedsv);

Geo::BUFR::EC::Descriptor
bufr_datasubset_next_descriptor(ds,pos)
		Geo::BUFR::EC::DataSubset ds
		int &pos
	PREINIT:
		SV* relatedsv = ST(0);
	CLEANUP:
		hold_related(ST(0),relatedsv);

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Descriptor

=head1 Geo::BUFR::EC::Descriptor

BUFR descriptor object. May or may not have an associated value depending on the
kind of descriptor.

=head2 Geo::BUFR::EC::Descriptor->new($tables,$desc)

Creates a new L<Geo::BUFR::EC::Descriptor> for a given descriptor C<$desc>.
The desired descriptor must exist in the C<$tables>.

=cut

Geo::BUFR::EC::Descriptor
new(packname="Geo::BUFR::EC::Descriptor",tables,desc)
		char* packname
		Geo::BUFR::EC::Tables tables
		SV* desc
	CODE:
		RETVAL = bufr_create_descriptor(tables,
			sv2desc(desc, tables) );
	OUTPUT:
		RETVAL

void
DESTROY(d)
		Geo::BUFR::EC::Descriptor d
	CODE:
		if( !release_related(ST(0)) ) bufr_free_descriptor(d);

=head2 $desc->descriptor()

Returns the numeric descriptor value for C<$desc>.

=cut 

int
descriptor(d)
		Geo::BUFR::EC::Descriptor d
	CODE:
		RETVAL = d->descriptor;
	OUTPUT:
		RETVAL

=head2 $desc->value()

Returns the L<Geo::BUFR::EC::Value> value for C<$desc>.

=cut 

Geo::BUFR::EC::Value
value(d)
		Geo::BUFR::EC::Descriptor d
	PREINIT:
		SV* relatedsv = ST(0);
	CODE:
		if( d->value == NULL ) XSRETURN_UNDEF;
		RETVAL = d->value;
	OUTPUT:
		RETVAL
	CLEANUP:
		hold_related(ST(0),relatedsv);

=head2 $desc->get()

Returns scalar value for the descriptor C<$desc>. The resulting scalar will
match the type of the object as closely as possible. Missing BUFR values will be
returned as C<undef>. Note that BUFR strings are space-filled on the right
to the descriptor data width. The caller is responsible for removing whitespace.

Note that a L<Geo::BUFR::EC::Descriptor> object may not have a value
(i.e. Table D descriptors), in which case this function will also return
C<undef>. C<< $desc->is_missing() >> can be used to determine the difference.

=head2 $desc->set($val)

Set the value of C<$desc> to the scalar C<$val>. The scalar value will be mapped
to the descriptor type as closely as possible. To store a missing value, use
C<undef>. Returns the old value.

Note that BUFR strings are space-filled on the right to the descriptor data
width. This will be done auto-magically during encoding, and what you right to
the message isn't necessary what comes back.

=cut 

SV*
set_value(d, sv=&PL_sv_undef)
		Geo::BUFR::EC::Descriptor d
		SV* sv
	ALIAS:
		get = 1
		set = 2
	INIT:
		BufrValue* bv = d->value;
	CODE:
		if( bv == NULL ) {
			d->value = bv = bufr_mkval_for_descriptor(d);
		}
		if( bv == NULL ) XSRETURN_UNDEF;
		RETVAL = bufr_value_getset(bv,(ix==2) ? sv : NULL);
		if( RETVAL == NULL ) croak("unhandled value type");
	OUTPUT:
		RETVAL

=head2 $desc->is_descriptor()

Returns non-zero is C<$desc> has a proper BUFR descriptor value. This should
always be the case unless a user manually instantiates an invalid one for some
reason. This method can be called either as a class or object method:

	my $d = Geo::BUFR::EC::Descriptor->new($tables,1099);
	print $d->is_descriptor();
	print Geo::BUFR::EC::Descriptor::is_descriptor(1099);
	print Geo::BUFR::EC::Descriptor::is_descriptor('0-01-099' );

=head2 $desc->is_qualifier()

Returns non-zero if C<$desc> is a BUFR qualifier. This method can be called
either as a class or object method.

=head2 $desc->is_table_b()

Returns non-zero if C<$desc> is a Table B descriptor. This method can be called
either as a class or object method.

=head2 $desc->is_table_c()

Returns non-zero if C<$desc> is a Table C descriptor. This method can be called
either as a class or object method.

=head2 $desc->is_table_d()

Returns non-zero if C<$desc> is a Table D descriptor. This method can be called
either as a class or object method.

=head2 $desc->is_local()

Returns non-zero if C<$desc> is a local replicator. This method can be called
either as a class or object method.

=head2 $desc->is_replicator()

Returns non-zero if C<$desc> is a BUFR replicator. This method can be called
either as a class or object method.

=head2 $desc->is_missing()

Returns non-zero if C<$desc> contains a missing value, zero if the value isn't
missing, and C<undef> if no value is associated with the descriptor.

=cut

int
is_descriptor(sv)
		SV* sv
	ALIAS:
		is_qualifier = 1
		is_table_b = 2
		is_table_d = 3
		is_local = 4
		is_missing = 5
		is_table_c = 6
		is_replicator = 7
	PREINIT:
		int desc = 0;
	CODE:
		if( ix == 5 && sv_isobject(sv) &&
			sv_derived_from(sv, "Geo::BUFR::EC::DescValue")
		) {
			const BufrDescriptor* d
				= INT2PTR(BufrDescriptor*,SvIV((SV*)SvRV(sv)));
			if( d->value ) {
				RETVAL = bufr_value_is_missing(d->value);
			} else {
				XSRETURN_UNDEF;
			}
		}
		desc = sv2desc( sv, NULL );
		if( desc == 0 ) {
			/* obviously, it's not going to be any of those... */
			RETVAL = 0;
		} else if( !bufr_is_descriptor(desc) ) {
			RETVAL = 0;
		} else if( ix == 0 ) {
			RETVAL = 1;
		} else if( ix == 4 ) {
			RETVAL = bufr_is_local_descriptor(desc);
		} else {
			int f, x, y;
			bufr_descriptor_to_fxy(desc,&f,&x,&y);
			if( ix == 3 ) {
				RETVAL = (f == 3);
			} else if( ix == 6 ) {
				RETVAL = (f == 2);
			} else if( ix == 7 ) {
				RETVAL = (f == 1);
			} else if( ix == 1 ) {
				RETVAL = (f==0 && x>=1 && x<=9);
			} else if( ix == 2 ) {
				/* NOTE: we _could_ use bufr_is_table_b() */
				RETVAL = (f == 0);
			} else {
				croak("Unknown alias");
			}
		}
	OUTPUT:
		RETVAL

=head2 $d->flags()

Returns the C<flags> field of the descriptor.

=head2 $d->is_class31()

Returns non-zero if the descriptor is flagged as FLAG_CLASS31.

=head2 $d->is_expanded()

Returns non-zero if the descriptor is flagged as FLAG_EXPANDED.

=head2 $d->is_skipped()

Returns non-zero if the descriptor is flagged as FLAG_SKIPPED.

=head2 $d->is_class33()

Returns non-zero if the descriptor is flagged as FLAG_CLASS33.

=head2 $d->is_ignored()

Returns non-zero if the descriptor is flagged as FLAG_IGNORED.

=cut

int
flags(d)
		Geo::BUFR::EC::Descriptor d
	ALIAS:
		is_class31 = FLAG_CLASS31
		is_expanded = FLAG_EXPANDED
		is_skipped = FLAG_SKIPPED
		is_class33 = FLAG_CLASS33
		is_ignored = FLAG_IGNORED
	CODE:
		RETVAL = ix ? (d->flags & ix) : d->flags;
	OUTPUT:
		RETVAL

=head2 $desc->to_fxy()

Returns the descriptor as list of F,X and Y values. May be used as either
an object or class method. i.e.

	my $d = Geo::BUFR::EC::Descriptor->new($tables,1099);
	print $d->to_fxy();
	print Geo::BUFR::EC::Descriptor::to_fxy(1099);
	print Geo::BUFR::EC::Descriptor::to_fxy('0-01-099' );

=cut

void
to_fxy(sv)
		SV* sv
	PREINIT:
		int f, x, y;
		int desc;
	PPCODE:
		desc = sv2desc( sv, NULL );
		if( !bufr_is_descriptor(desc) ) {
			XSRETURN_EMPTY;
		}
		bufr_descriptor_to_fxy(desc,&f,&x,&y);
		EXTEND(SP,3);
		ST(0) = sv_2mortal(newSViv(f));
		ST(1) = sv_2mortal(newSViv(x));
		ST(2) = sv_2mortal(newSViv(y));
		XSRETURN(3);

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Descriptor PREFIX = bufr_descriptor_

void
bufr_descriptor_get_range(IN Geo::BUFR::EC::Descriptor d, OUTLIST double mn, OUTLIST double mx)

float
bufr_descriptor_get_location(d,desc)
		Geo::BUFR::EC::Descriptor d
		int desc

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Value

=head1 Geo::BUFR::EC::Value

Low-level access to BUFR values. Most users should be fine with the
C<Geo::BUFR::EC::Descriptor> methods. Particularly for string access where the
length of the string requires additional information.

=cut

void
DESTROY(bv)
		Geo::BUFR::EC::Value bv
	CODE:
		if( !release_related(ST(0)) ) bufr_free_value(bv);

=head2 $bv->get()

Returns the scalar value of the C<$bv>. As per convention, C<undef> indicates a
"missing" bufr value.

=head2 $bv->set($value)

Sets a value. Equivalent to L<Geo::BUFR::EC::Descriptor::set>.

Returns the old value, if any (which may be C<undef>, indicating "missing").

=cut

SV*
set_value(bv, sv=&PL_sv_undef)
		Geo::BUFR::EC::Value bv
		SV* sv
	ALIAS:
		get = 1
		set = 2
	CODE:
		RETVAL = bufr_value_getset(bv,(ix==2) ? sv : NULL);
		if( RETVAL == NULL ) croak("unhandled value type");
	OUTPUT:
		RETVAL

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Value   PREFIX=bufr_value_

int
bufr_value_set_double(bv,val)
		Geo::BUFR::EC::Value bv
		double val

int
bufr_value_set_float(bv,val)
		Geo::BUFR::EC::Value bv
		float val

int
bufr_value_set_int32(bv,val)
		Geo::BUFR::EC::Value bv
		int32_t val

int
bufr_value_set_int64(bv,val)
		Geo::BUFR::EC::Value bv
		int64_t val

int
bufr_value_set_string(Geo::BUFR::EC::Value bv, char* s, int length(s))

double
bufr_value_get_double(bv)
		Geo::BUFR::EC::Value bv

float
bufr_value_get_float(bv)
		Geo::BUFR::EC::Value bv

int32_t
bufr_value_get_int32(bv)
		Geo::BUFR::EC::Value bv

int64_t
bufr_value_get_int64(bv)
		Geo::BUFR::EC::Value bv

const char*
bufr_value_get_string(IN Geo::BUFR::EC::Value bv, OUTLIST int len)

