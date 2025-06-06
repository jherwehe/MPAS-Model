! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.com/license.html
!
!=================================================================================================================
 module mpas_atmphys_finalize
 use mpas_pool_routines

 use mpas_atmphys_lsm_noahmpfinalize,only: sf_noahmp_deallocate
 use module_mp_thompson
 use cires_ugwpv1_module

 implicit none
 private
 public:: atmphys_finalize

!mpas_atmphys_finalize contains subroutines that deallocate arrays used in physics parameterizations, i.e. arrays
!that need to remain allocated as long as MPAS runs and are not properly deallocated in the sourcecode itself.
!Laura D. Fowler (laura@ucar.edu) / 2016-03-22.

!add-ons and modifications to sourcecode:
!----------------------------------------
!   * added subroutine mp_thompson_deallocate which deallocate arrays used in the initialization of the Thompson
!     cloud microphysics scheme. these arrays contain coefficients for collection,collision,freezing, ...
!     Laura D. Fowler (laura@ucar.edu) / 2016-03-22.
!   * added subroutine ugwpv1_ngw_deallocate which deallocates arrays used in the initialization of the
!     non-stationary gravity wave (NGW) scheme
!     Michael D. toy (michael.toy@noaa.gov) / 2024-10-21

 contains


!=================================================================================================================
 subroutine atmphys_finalize(configs)
!=================================================================================================================

!input arguments:
 type(mpas_pool_type),intent(in):: configs

!local variables and pointers:
 character(len=StrKIND),pointer:: config_lsm_scheme,   &
                                  config_microp_scheme
 character(len=StrKIND),pointer:: config_gwdo_scheme
 logical,pointer:: config_ngw_scheme

!----------------------------------------------------------------------------------------------------------------- 

 call mpas_pool_get_config(configs,'config_lsm_scheme'   ,config_lsm_scheme   )
 call mpas_pool_get_config(configs,'config_microp_scheme',config_microp_scheme)
 call mpas_pool_get_config(configs,'config_gwdo_scheme',config_gwdo_scheme)
 call mpas_pool_get_config(configs,'config_ngw_scheme',config_ngw_scheme)

 if(trim(config_lsm_scheme) == 'sf_noahmp') &
    call sf_noahmp_deallocate

 if(trim(config_microp_scheme) == 'mp_thompson'         .or. &
    trim(config_microp_scheme) == 'mp_thompson_aerosols') then
    call mp_thompson_deallocate
 endif

 if((trim(config_gwdo_scheme) == 'bl_ugwp_gwdo').and.config_ngw_scheme) &
    call ugwpv1_ngw_deallocate

 end subroutine atmphys_finalize

!=================================================================================================================
 subroutine mp_thompson_deallocate
!=================================================================================================================
!call mpas_log_write('')
!call mpas_log_write('--- enter subroutine mp_thompson_deallocate:')

 if(allocated(tcg_racg) ) deallocate(tcg_racg ) 
 if(allocated(tmr_racg) ) deallocate(tmr_racg )
 if(allocated(tcr_gacr) ) deallocate(tcr_gacr )
 if(allocated(tmg_gacr) ) deallocate(tmg_gacr )
 if(allocated(tnr_racg) ) deallocate(tnr_racg )
 if(allocated(tnr_gacr) ) deallocate(tnr_gacr )
 if(allocated(tcs_racs1)) deallocate(tcs_racs1)
 if(allocated(tmr_racs1)) deallocate(tmr_racs1)
 if(allocated(tcs_racs2)) deallocate(tcs_racs2)
 if(allocated(tmr_racs2)) deallocate(tmr_racs2)
 if(allocated(tcr_sacr1)) deallocate(tcr_sacr1)
 if(allocated(tms_sacr1)) deallocate(tms_sacr1)
 if(allocated(tcr_sacr2)) deallocate(tcr_sacr2)
 if(allocated(tms_sacr2)) deallocate(tms_sacr2)
 if(allocated(tnr_racs1)) deallocate(tnr_racs1)
 if(allocated(tnr_racs2)) deallocate(tnr_racs2)
 if(allocated(tnr_sacr1)) deallocate(tnr_sacr1)
 if(allocated(tnr_sacr2)) deallocate(tnr_sacr2)
 if(allocated(tpi_qcfz) ) deallocate(tpi_qcfz )
 if(allocated(tni_qcfz) ) deallocate(tni_qcfz )
 if(allocated(tpi_qrfz) ) deallocate(tpi_qrfz )
 if(allocated(tpg_qrfz) ) deallocate(tpg_qrfz )
 if(allocated(tni_qrfz) ) deallocate(tni_qrfz )
 if(allocated(tnr_qrfz) ) deallocate(tnr_qrfz )
 if(allocated(tps_iaus) ) deallocate(tps_iaus )
 if(allocated(tni_iaus) ) deallocate(tni_iaus )
 if(allocated(tpi_ide)  ) deallocate(tpi_ide  )
 if(allocated(t_efrw)   ) deallocate(t_efrw   )
 if(allocated(t_efsw)   ) deallocate(t_efsw   )
 if(allocated(tnr_rev)  ) deallocate(tnr_rev  )
 if(allocated(tpc_wev)  ) deallocate(tpc_wev  )
 if(allocated(tnc_wev)  ) deallocate(tnc_wev  )
 if(allocated(tnccn_act)) deallocate(tnccn_act)

!call mpas_log_write('--- end subroutine mp_thompson_deallocate')

 end subroutine mp_thompson_deallocate


!=================================================================================================================
 subroutine ugwpv1_ngw_deallocate
!=================================================================================================================

 call cires_ugwp_dealloc

 end subroutine ugwpv1_ngw_deallocate


!=================================================================================================================
 end module mpas_atmphys_finalize
!=================================================================================================================
