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

/* FIXME: there's gotta be a saner way to do this. */
static void make_unfreeable(SV* sv) {
	sv_magic(SvRV(sv), NULL, '~', 1, 0 );
}
static int is_unfreeable(SV* sv) {
	MAGIC* m = mg_find(SvRV(sv),'~');
	return m && m->mg_ptr;
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

BOOT:
{
    MY_CXT_INIT;
    /* If any of the fields in the my_cxt_t struct need
       to be initialised, do it here.
     */

	 bufr_begin_api();
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
	
void
DESTROY(tables)
		Geo::BUFR::EC::Tables tables
	CODE:
		if( tables ) bufr_free_tables( tables );

=head2 $tables->cmc()

Loads the default set of CMC BUFR tables into C<$tables> as found by
the C<BUFR_TABLES> environment variable. If missing falls back to the
LibECBUFR default location.

=cut

void
cmc(tables)
		Geo::BUFR::EC::Tables tables
	CODE:
		bufr_load_cmc_tables( tables );

=head2 $tables->lookup($desc)

Looks up bufr descriptor C<$desc> in the loaded <$tables>. Depending on the type
of descriptor it may return a C<Geo::BUFR::EC::Tables::Entry::B> or
C<Geo::BUFR::EC::Tables::Entry::D> object, or C<undef> on failure.

C<$desc> may be an integer value or a C<Geo::BUFR::EC::DescValue> object.

=cut

void
lookup(tables,desc)
		Geo::BUFR::EC::Tables tables
		SV* desc
	PREINIT:
		int d = 0;
	PPCODE:
		/* FIXME: we _could_ break this into separate functions */
		if( sv_isobject(desc) && sv_derived_from(desc, "Geo::BUFR::EC::DescValue") ) {
			BufrDescValue* myd = INT2PTR(BufrDescValue*,SvIV((SV*)SvRV(desc)));
			if( myd ) d = myd->descriptor;
		} else {
			d = SvIV(desc);
		}
		if( !bufr_is_descriptor(d) ) {
			XSRETURN_UNDEF;
		} else if( bufr_is_table_b(d) ) {
			EntryTableB* tb = bufr_fetch_tableB( tables, d);
			if( tb == NULL ) XSRETURN_UNDEF;
			ST(0) = sv_newmortal();
			sv_setref_pv(ST(0), "Geo::BUFR::EC::Tables::Entry::B", (void*)tb);
			/* FIXME: might be better to just make a copy? */
			make_unfreeable(ST(0));
		} else {
			EntryTableD* td = bufr_fetch_tableD( tables, d);
			if( td == NULL ) XSRETURN_UNDEF;
			ST(0) = sv_newmortal();
			sv_setref_pv(ST(0), "Geo::BUFR::EC::Tables::Entry::D", (void*)td);
			/* FIXME: might be better to just make a copy? */
			make_unfreeable(ST(0));
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
		if( !is_unfreeable(ST(0)) ) bufr_free_EntryTableB( eb );

=head2 $eb->description()

Returns the description text for Table B entry C<$eb>.

=head2 $eb->unit()

Returns the units text for Table B entry C<$eb>.

=cut

char*
description(eb)
		Geo::BUFR::EC::Tables::Entry::B eb
	ALIAS:
		Geo::BUFR::EC::Tables::Entry::B::unit = 1
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
		Geo::BUFR::EC::Tables::Entry::B::scale = 1
		Geo::BUFR::EC::Tables::Entry::B::reference = 2
		Geo::BUFR::EC::Tables::Entry::B::nbits = 3
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
		if( !is_unfreeable(ST(0)) ) bufr_free_EntryTableD( ed );

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

=cut

Geo::BUFR::EC::Template
new(packname="Geo::BUFR::EC::Template",tables,edition=4,...)
		char* packname
		Geo::BUFR::EC::Tables tables
		int edition
	PREINIT:
		int i;
	CODE:
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

void
finalize(tmpl,...)
		Geo::BUFR::EC::Template tmpl
	CODE:
		bufr_finalize_template( tmpl );

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
		RETVAL = bufr_create_dataset(tmpl);
		if( RETVAL == NULL ) XSRETURN_UNDEF;
	OUTPUT:
		RETVAL

void
DESTROY(dts)
		Geo::BUFR::EC::Dataset dts
	CODE:
		if( dts ) bufr_free_dataset(dts);

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Dataset     PREFIX = bufr_

int
bufr_count_datasubset(dts)
		Geo::BUFR::EC::Dataset dts

Geo::BUFR::EC::DataSubset
bufr_get_datasubset(dts,pos)
		Geo::BUFR::EC::Dataset dts
		int pos

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Message

=head1 Geo::BUFR::EC::Message

A BUFR message used either for encoding or decoding.

=cut

Geo::BUFR::EC::Message
encode(packname="Geo::BUFR::EC::Message",dts,compress=1)
		char *packname
		Geo::BUFR::EC::Dataset dts
		int compress
	CODE:
		RETVAL = bufr_encode_message(dts,compress);
		if( RETVAL == NULL ) XSRETURN_UNDEF;
	OUTPUT:
		RETVAL

Geo::BUFR::EC::Dataset
decode(msg,tables)
		Geo::BUFR::EC::Message msg
		Geo::BUFR::EC::Tables tables
	CODE:
		RETVAL = bufr_decode_message(msg,tables);
		if( RETVAL == NULL ) XSRETURN_UNDEF;
	OUTPUT:
		RETVAL

SV*
toString(msg)
		Geo::BUFR::EC::Message msg
	CODE:
		RETVAL = newSV(0);
		if( bufr_callback_write_message( appendsv, (void*)RETVAL, msg ) ) {
			XSRETURN_UNDEF;
		}
	OUTPUT:
		RETVAL

Geo::BUFR::EC::Message
fromString(packname="Geo::BUFR::EC::Message",s)
		char *packname
		SV* s
	PREINIT:
		STRLEN l;
		const char* ps;
	CODE:
		ps = SvPV(s,l);
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

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::DataSubset

=head1 Geo::BUFR::EC::DataSubset

A set of descriptor/value pairs.

=cut

void
DESTROY(ds)
		Geo::BUFR::EC::DataSubset ds
	CODE:
		/* empty - tied to the DataSet */
		/* FIXME: come up with some way to take a ref to the
		 * corresponding DataSet so it doesn't get destroyed until all subset
		 * refs are dropped.
		 */
		{
		}

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::DataSubset  PREFIX = bufr_datasubset_

int
bufr_datasubset_count_descriptor(ds)
		Geo::BUFR::EC::DataSubset ds

Geo::BUFR::EC::Descriptor
bufr_datasubset_get_descriptor(ds,pos)
		Geo::BUFR::EC::DataSubset ds
		int pos

Geo::BUFR::EC::Descriptor
bufr_datasubset_next_descriptor(ds,pos)
		Geo::BUFR::EC::DataSubset ds
		int &pos

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Descriptor

=head1 Geo::BUFR::EC::Descriptor

BUFR descriptor object. May or may not have an associated value depending on the
kind of descriptor.

=cut

void
DESTROY(d)
		Geo::BUFR::EC::Descriptor d
	CODE:
		{
			/* empty; we look right into the DataSubset array */
			/* FIXME: same problem as the DataSubset destructor */
		}

int
descriptor(d)
		Geo::BUFR::EC::Descriptor d
	CODE:
		RETVAL = d->descriptor;
	OUTPUT:
		RETVAL

Geo::BUFR::EC::Value
value(d)
		Geo::BUFR::EC::Descriptor d
	CODE:
		RETVAL = d->value;
	OUTPUT:
		RETVAL

SV*
set_value(d, sv=0)
		Geo::BUFR::EC::Descriptor d
		SV* sv
	ALIAS:
		Geo::BUFR::EC::Descriptor::get = 1
		Geo::BUFR::EC::Descriptor::set = 2
	INIT:
		BufrValue* bv = d->value;
	CODE:
		if( bv == NULL ) XSRETURN_UNDEF;

		if( ix == 2 && sv ) {
			/* assign second param to value */
			switch( bv->type ) {
				case VALTYPE_INT64:
					if( sv == &PL_sv_undef ) {
						bufr_value_set_int64(bv,bufr_missing_int());
					} else {
						bufr_value_set_int64(bv,SvIV(sv));
					}
					break;
				case VALTYPE_INT8:
				case VALTYPE_INT32:
					if( sv == &PL_sv_undef ) {
						bufr_value_set_int32(bv,bufr_missing_int());
					} else {
						bufr_value_set_int32(bv,SvIV(sv));
					}
					break;
				case VALTYPE_FLT32:
					if( sv == &PL_sv_undef ) {
						bufr_value_set_float(bv,bufr_missing_float());
					} else {
						bufr_value_set_float(bv,SvNV(sv));
					}
					break;
				case VALTYPE_FLT64:
					if( sv == &PL_sv_undef ) {
						bufr_value_set_double(bv,bufr_missing_double());
					} else {
						bufr_value_set_double(bv,SvNV(sv));
					}
					break;
				case VALTYPE_STRING: {
					STRLEN l;
					const char* s = SvPV(sv,l);
					if( sv == &PL_sv_undef || s==NULL ) {
                  int len=d->encoding.nbits/8;
                  char *tmpbuf = (char *)malloc( (len+1)*sizeof(char) );
						if( tmpbuf == NULL ) croak("malloc failed!");
                  bufr_missing_string( tmpbuf, len );
                  bufr_descriptor_set_svalue( d, tmpbuf );
                  free( tmpbuf );
					} else {
						bufr_value_set_string(bv,s,l);
					}
					break;
				}
				default:
					croak("Unknown/unhandled BUFR value type");
					break;
			}
		}

		/* return appropriate value */
		if( bufr_value_is_missing(bv) ) {
			XSRETURN_UNDEF;
		}
		switch( bv->type ) {
			case VALTYPE_INT8:
			case VALTYPE_INT32:
			case VALTYPE_INT64:
				RETVAL = newSViv(bufr_descriptor_get_ivalue(d));
				break;
			case VALTYPE_FLT32:
				RETVAL = newSVnv(bufr_descriptor_get_fvalue(d));
				break;
			case VALTYPE_FLT64:
				RETVAL = newSVnv(bufr_descriptor_get_dvalue(d));
				break;
			case VALTYPE_STRING: {
				int len;
				const char* s = bufr_descriptor_get_svalue(d,&len);
				RETVAL = newSVpvn(s,len);
				break;
			}
			default:
				croak("Unknown/unhandled BUFR value type");
				break;
		}
	OUTPUT:
		RETVAL

int
is_descriptor(d)
		Geo::BUFR::EC::Descriptor d
	CODE:
		RETVAL = bufr_is_descriptor(d->descriptor);
	OUTPUT:
		RETVAL

int
is_local(d)
		Geo::BUFR::EC::Descriptor d
	CODE:
		RETVAL = bufr_is_local_descriptor(d->descriptor);
	OUTPUT:
		RETVAL

int
is_table_d(d)
		Geo::BUFR::EC::Descriptor d
	ALIAS:
		Geo::BUFR::EC::Descriptor::is_qualifier = 1
		Geo::BUFR::EC::Descriptor::is_table_b = 2
	CODE:
		if( !bufr_is_descriptor(d->descriptor) ) {
			RETVAL = 0;
		} else {
			int f, x, y;
			bufr_descriptor_to_fxy(d->descriptor,&f,&x,&y);
			if( ix == 0 ) {
				RETVAL = (f == 3);
			} else if( ix == 1 ) {
				RETVAL = (f==0 && x>=1 && x<=0);
			} else if( ix == 2 ) {
				/* NOTE: we _could_ use bufr_is_table_b(),
				 * but it's handy to have all these related functions
				 * in one place...
				 */
				RETVAL = (f == 0);
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
		Geo::BUFR::EC::Descriptor::is_class31 = FLAG_CLASS31
		Geo::BUFR::EC::Descriptor::is_expanded = FLAG_EXPANDED
		Geo::BUFR::EC::Descriptor::is_skipped = FLAG_SKIPPED
		Geo::BUFR::EC::Descriptor::is_class33 = FLAG_CLASS33
		Geo::BUFR::EC::Descriptor::is_ignored = FLAG_IGNORED
	CODE:
		RETVAL = ix ? (d->flags & ix) : d->flags;
	OUTPUT:
		RETVAL

void
to_fxy(d)
		Geo::BUFR::EC::Descriptor d
	PREINIT:
		int f, x, y;
	PPCODE:
		if( !bufr_is_descriptor(d->descriptor) ) {
			XSRETURN_EMPTY;
		}
		bufr_descriptor_to_fxy(d->descriptor,&f,&x,&y);
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
length of the string requires additional informaiton.

=cut

void
DESTROY(bv)
		Geo::BUFR::EC::Value bv
	CODE:
		{
			/* empty; we look right into the DataSubset array */
			/* FIXME: same problem as the DataSubset destructor */
		}


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

char*
bufr_value_get_string(IN Geo::BUFR::EC::Value bv, OUTLIST int len)

