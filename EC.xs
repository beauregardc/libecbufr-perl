#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <bufr_api.h>

typedef BUFR_Message* Geo__BUFR__EC__Message;
typedef BUFR_Dataset* Geo__BUFR__EC__Dataset;
typedef DataSubset* Geo__BUFR__EC__DataSubset;
typedef BUFR_Tables* Geo__BUFR__EC__Tables;
typedef BufrDescValue* Geo__BUFR__EC__DescValue;
typedef BufrDescriptor* Geo__BUFR__EC__Descriptor;
typedef BufrValue* Geo__BUFR__EC__Value;
typedef BUFR_Sequence* Geo__BUFR__EC__Sequence;
typedef BUFR_Template* Geo__BUFR__EC__Template;

static ssize_t appendsv( void *dsv, size_t len, const char *buffer ) {
	sv_catpvn((SV*)dsv, buffer, len);
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

void
LoadCMC(tables)
		Geo::BUFR::EC::Tables tables
	CODE:
		bufr_load_cmc_tables( tables );

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Template

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
			if( sv_derived_from(ST(i), "Geo::BUFR::EC::DescValue") ) {
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
			if( sv_derived_from(ST(i), "Geo::BUFR::EC::DescValue") ) {
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
fromString(s)
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

void
DESTROY(d)
		Geo::BUFR::EC::Descriptor d
	CODE:
		{
			/* empty; we look right into the DataSubset array */
			/* FIXME: same problem as the DataSubset destructor */
		}

Geo::BUFR::EC::Value
value(d)
		Geo::BUFR::EC::Descriptor d
	CODE:
		RETVAL = d->value;
	OUTPUT:
		RETVAL

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Descriptor PREFIX = bufr_descriptor_

void
bufr_descriptor_get_range(IN Geo::BUFR::EC::Descriptor d, OUTLIST double mn, OUTLIST double mx)

float
bufr_descriptor_get_location(d,desc)
		Geo::BUFR::EC::Descriptor d
		int desc

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Value

void
DESTROY(bv)
		Geo::BUFR::EC::Value bv
	CODE:
		{
			/* presently from a descriptor */
			/* FIXME: same problem as the DataSubset destructor */
		}

SV*
set_value(bv, sv=0)
		Geo::BUFR::EC::Value bv
		SV* sv
	ALIAS:
		Geo::BUFR::EC::Value::get = 1
		Geo::BUFR::EC::Value::set = 2
	CODE:
		if( ix == 2 && sv ) {
			/* assign second param to value */
		}
		RETVAL = newSV(0);
		/* return appropriate value */
	OUTPUT:
		RETVAL
