.SUFFIXES: .F .o

#
# To build a dycore-only MPAS-Atmosphere model, comment-out or delete
# the definition of PHYSICS, below
#
# If MPAS_CAM_DYCORE is found in CPPFLAGS, PHYSICS will become undefined automatically
#
ifeq ($(findstring MPAS_CAM_DYCORE,$(CPPFLAGS)),)
    PHYSICS = -DDO_PHYSICS
endif

ifdef PHYSICS
    PHYSCORE = physcore
    PHYS_OBJS = libphys/*.o
endif

OBJS = mpas_atm_core.o \
       mpas_atm_core_interface.o \
       mpas_atm_dimensions.o \
       mpas_atm_threading.o \
       mpas_atm_halos.o

all: $(PHYSCORE) dycore diagcore atmcore utilities

core_reg:
	$(CPP) $(CPPFLAGS) $(CPPINCLUDES) $(PHYSICS) Registry.xml > Registry_processed.xml

core_input_gen:
	if [ ! -e default_inputs ]; then  mkdir default_inputs; fi
	( cd default_inputs; $(NL_GEN) ../Registry_processed.xml namelist.atmosphere in_defaults=true )
	( cd default_inputs; $(ST_GEN) ../Registry_processed.xml streams.atmosphere stream_list.atmosphere. listed in_defaults=true)

gen_includes: core_reg
	(if [ ! -d inc ]; then mkdir -p inc; fi) # To generate *.inc files
	(cd inc; $(REG_PARSE) ../Registry_processed.xml $(CPPFLAGS) )

post_build:
	if [ ! -e $(ROOT_DIR)/default_inputs ]; then mkdir $(ROOT_DIR)/default_inputs; fi
	cp default_inputs/* $(ROOT_DIR)/default_inputs/.
	( cd $(ROOT_DIR)/default_inputs; for FILE in `ls -1`; do if [ ! -e ../$$FILE ]; then cp $$FILE ../.; fi; done )

physcore: mpas_atm_dimensions.o
	( cd physics; $(MAKE) all )
	( mkdir libphys; cd libphys; ar -x ../physics/libphys.a )
	( cd ../..; ln -sf ./src/core_atmosphere/physics/physics_wrf/files/*TBL .)
	( cd ../..; ln -sf ./src/core_atmosphere/physics/physics_wrf/files/*DATA* .)
	( cd ../..; ln -sf ./src/core_atmosphere/physics/physics_noahmp/parameters/*TBL .)

dycore: mpas_atm_dimensions.o $(PHYSCORE)
	( cd dynamics; $(MAKE) all PHYSICS="$(PHYSICS)" )

diagcore: $(PHYSCORE) dycore
	( cd diagnostics; $(MAKE) all PHYSICS="$(PHYSICS)" )

utilities: $(PHYSCORE)
	( cd utils; $(MAKE) all PHYSICS="$(PHYSICS)" )

atmcore: $(PHYSCORE) dycore diagcore $(OBJS)
	ar -ru libdycore.a $(OBJS) dynamics/*.o $(PHYS_OBJS) diagnostics/*.o

mpas_atm_core_interface.o: mpas_atm_core.o

mpas_atm_core.o: dycore diagcore mpas_atm_threading.o mpas_atm_halos.o

mpas_atm_dimensions.o:

clean:
	( cd physics; $(MAKE) clean )
	( cd dynamics; $(MAKE) clean )
	( cd diagnostics; $(MAKE) clean )
	( cd utils; $(MAKE) clean )
	( cd ../..; rm -f *TBL )
	( cd ../..; rm -f *DATA* )
	$(RM) -r libphys
	$(RM) *.o *.mod *.f90 libdycore.a
	$(RM) Registry_processed.xml
	@# Certain systems with intel compilers generate *.i files
	@# This removes them during the clean process
	$(RM) *.i
	$(RM) -r default_inputs

.F.o:
	$(RM) $@ $*.mod
ifeq "$(GEN_F90)" "true"
	$(CPP) $(CPPFLAGS) $(PHYSICS) $(CPPINCLUDES) -I./inc $< > $*.f90
	$(FC) $(FFLAGS) -c $*.f90 $(FCINCLUDES) -I../framework -I../operators -I./physics -I./dynamics -I./diagnostics -I./physics/physics_wrf -I./physics/physics_mmm -I./physics/physics_noaa/UGWP -I../external/esmf_time_f90
else
	$(FC) $(CPPFLAGS) $(PHYSICS) $(FFLAGS) -c $*.F $(CPPINCLUDES) $(FCINCLUDES) -I./inc -I../framework -I../operators -I./physics -I./dynamics -I./diagnostics -I./physics/physics_wrf -I./physics/physics_mmm -I./physics/physics_noaa/UGWP -I../external/esmf_time_f90
endif
