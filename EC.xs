#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <bufr_api.h>

typedef BUFR_Message Geo__BUFR__EC__Message;
typedef BUFR_Dataset Geo__BUFR__EC__Dataset;
typedef DataSubset Geo__BUFR__EC__DataSubset;
typedef BUFR_Tables Geo__BUFR__EC__Tables;
typedef BufrDescValue Geo__BUFR__EC__DescValue;
typedef BUFR_Sequence Geo__BUFR__EC__Sequence;
typedef BUFR_Template Geo__BUFR__EC__Template;

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

SV*
new(packname="Geo::BUFR::EC::Tables")
		char* packname
	PREINIT:
		Geo__BUFR__EC__Tables* tables;
	CODE:
		tables = bufr_create_tables();
		if( tables == NULL ) XSRETURN_UNDEF;
		RETVAL = newSV();
		sv_setref_pv(RETVAL, packname, (void*)tables);
	OUTPUT:
		RETVAL
	
void
DESTROY(tables)
		Geo::BUFR::EC::Tables* tables
	CODE:
		if( tables ) bufr_free_tables( tables );

void
LoadCMC(tables)
		Geo::BUFR::EC::Tables* tables
	CODE:
		bufr_load_cmc_tables( tables );

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Template

SV*
new(packname="Geo::BUFR::EC::Template",tables,edition,...)
		char* packname
		Geo::BUFR::EC::Tables* tables
		int edition
	PREINIT:
		Geo__BUFR__EC__Template* tmpl;
	CODE:
		tmpl = bufr_create_template( NULL, 0, tables, edition);
		if( tmpl == NULL ) XSRETURN_UNDEF;

		/* not the most efficient, but easier than building a temp
		 * descval array
		 */
		for( i = 3; i < items; i ++ ) {
			if( sv_derived_from(sv, "Geo::BUFR::EC::DescValue") ) {
				BufrDescValue* d = INT2PTR(BufrDescValue*,SvIV((SV*)SvRV(ST(i))));
				bufr_template_add_DescValue( tmpl, d, 1 );
			} else {
				croak("Expecting a Geo::BUFR::EC::DescValue");
			}
		}

		RETVAL = newSV();
		sv_setref_pv(RETVAL, packname, (void*)tmpl);
	OUTPUT:
		RETVAL
	
void
DESTROY(tmpl)
		Geo::BUFR::EC::Template* tmpl
	CODE:
		if( tmpl ) bufr_free_template(tmpl)

void
addDescValue(tmpl,...)
		Geo::BUFR::EC::Template* tmpl
	CODE:
		for( i = 1; i < items; i ++ ) {
			if( sv_derived_from(sv, "Geo::BUFR::EC::DescValue") ) {
				BufrDescValue* d = INT2PTR(BufrDescValue*,SvIV((SV*)SvRV(ST(i))));
				bufr_template_add_DescValue( tmpl, d, 1 );
			} else {
				croak("Expecting a Geo::BUFR::EC::DescValue");
			}
		}

void
finalize(tmpl,...)
		Geo::BUFR::EC::Template* tmpl
	CODE:
		bufr_finalize_template( tmpl );

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Dataset

SV*
new(packname="Geo::BUFR::EC::Dataset",tmpl)
      char* packname
		Geo::BUFR::EC::Template* tmpl
	PREINIT:
		Geo__BUFR__EC__Dataset* dts;
	CODE:
		dts = bufr_create_dataset(tmpl);
		if( dts == NULL ) XSRETURN_UNDEF;
		RETVAL = newSV();
		sv_setref_pv(RETVAL, packname, (void*)dts);
	OUTPUT:
		RETVAL

void
DESTROY(dts)
		Geo::BUFR::EC::Dataset* dts
	CODE:
		if( dts ) bufr_free_dataset(dts)

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Message

SV*
encode(packname="Geo::BUFR::EC::Message",dts,compress=1)
		char *packname
		Geo::BUFR::EC::Dataset* dts
		int compress
	PREINIT:
		Geo__BUFR__EC__Message* msg;
	CODE:
		msg = bufr_encode_message(dts,compress);
		if( msg == NULL ) XSRETURN_UNDEF;
		RETVAL = newSV();
		sv_setref_pv(RETVAL, packname, (void*)msg);
	OUTPUT:
		RETVAL

SV*
decode(msg,tables)
		Geo::BUFR::EC::Message* msg
		Geo::BUFR::EC::Tables* tables
	PREINIT:
		Geo__BUFR__EC__Dataset* dts;
	CODE:
		dts = bufr_decode_message(msg,tables);
		if( dts == NULL ) XSRETURN_UNDEF;
		RETVAL = newSV();
		sv_setref_pv(RETVAL, "Geo::BUFR::EC::Dataset", (void*)dts);
	OUTPUT:
		RETVAL

void
DESTROY(msg)
		Geo::BUFR::EC::Message* msg
	CODE:
		if( msg ) bufr_free_message(msg)

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::DescValue

MODULE = Geo::BUFR::EC     PACKAGE = Geo::BUFR::EC::Sequence
