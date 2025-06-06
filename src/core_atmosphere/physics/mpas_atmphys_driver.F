! Copyright (c) 2013,  Los Alamos National Security, LLC (LANS)
! and the University Corporation for Atmospheric Research (UCAR).
!
! Unless noted otherwise source code is licensed under the BSD license.
! Additional copyright and license information can be found in the LICENSE file
! distributed with this code, or at http://mpas-dev.github.com/license.html
!
!=================================================================================================================
 module mpas_atmphys_driver
 use mpas_kind_types
 use mpas_pool_routines

 use mpas_atmphys_driver_cloudiness
 use mpas_atmphys_driver_convection
 use mpas_atmphys_driver_gwdo
 use mpas_atmphys_driver_lsm
 use mpas_atmphys_driver_lsm_noahmp
 use mpas_atmphys_driver_pbl
 use mpas_atmphys_driver_radiation_lw
 use mpas_atmphys_driver_radiation_sw 
 use mpas_atmphys_driver_seaice,only: allocate_seaice,deallocate_seaice,driver_seaice
 use mpas_atmphys_driver_sfclayer
 use mpas_atmphys_driver_oml
 use mpas_atmphys_constants
 use mpas_atmphys_interface
 use mpas_atmphys_sfc_diagnostics,only: atmphys_sfc_diagnostics
 use mpas_atmphys_update
 use mpas_atmphys_vars, only: l_camlw,l_conv,l_radtlw,l_radtsw
 use mpas_timer

 implicit none
 private
 public:: physics_driver


!MPAS top physics driver.
!Laura D. Fowler (send comments to laura@ucar.edu).
!2013-05-01.
!
! subroutine physics_driver is the top physics driver from which separate drivers for all physics
! parameterizations, except cloud microphysics parameterizations are called.
!
! subroutines called in mpas_atmphys_driver:
! ------------------------------------------
! allocate_forall_physics     : allocate local arrays defining atmospheric soundings (pressure,..)
! allocate_cloudiness         : allocate all local arrays used in driver_cloudiness.
! allocate_convection         : allocate all local arrays used in driver_convection.
! allocate_gwdo               : allocate all local arrays used in driver_gwdo.
! allocate_lsm                : allocate all local arrays used in driver_lsm.
! allocate_pbl                : allocate all local arrays used in driver_pbl.
! allocate_radiation_lw       : allocate all local arrays used in driver_radiation_lw.
! allocate_radiation_sw       : allocate all local arrays used in driver_radiation_sw.
! allocate_sfclayer           : allocate all local arrays used in driver_sfclayer.
!
! deallocate_forall_physics   : deallocate local arrays defining atmospheric soundings.
! deallocate_cloudiness       : dedeallocate all local arrays used in driver_cloudiness.
! deallocate_convection       : deallocate all local arrays used in driver_convection.
! deallocate_gwdo             : deallocate all local arrays used in driver_gwdo.
! deallocate_lsm              : deallocate all local arrays used in driver_lsm.
! deallocate_pbl              : deallocate all local arrays used in driver_pbl.
! deallocate_radiation_lw     : deallocate all local arrays used in driver_radiation_lw.
! deallocate_radiation_sw     : deallocate all local arrays used in driver_radiation_sw.
! deallocate_sfclayer         : deallocate all local arrays used in driver_sfclayer.
!
! MPAS_to_physics             :
! driver_cloudiness           : driver for parameterization of fractional cloudiness.
! driver_convection           : driver for parameterization of convection.
! driver_gwdo                 : driver for parameterization of gravity wave drag over orography.
! driver_lsm                  : driver for land-surface scheme.
! driver_pbl                  : driver for planetary boundary layer scheme.
! driver_radiation_sw         : driver for short wave radiation schemes.
! driver_radiation_lw         : driver for long wave radiation schemes.
! driver_sfclayer             : driver for surface layer scheme.
! update_convection_step1     : updates lifetime of deep convective clouds in Kain-Fritsch scheme.
! update_convection_step2     : updates accumulated precipitation output from convection schemes.
! update_radiation_diagnostics: updates accumualted radiation diagnostics from radiation schemes.
!
! add-ons and modifications to sourcecode:
! ----------------------------------------
! * removed call to calculate atmospheric soundings for the hydrostatic dynamical core.
!   Laura D. Fowler (2013-05-06).
! * removed the namelist option config_eddy_scheme and associated sourcecode.
! * removed the namelist option config_conv_shallow_scheme and associated sourcecode.
!   Laura D. Fowler (birch.ucar.edu) / 2013-05-29.
! * added block%atm_input in calls to subroutines driver_radiation_lw amd driver_radiation_lw.
!   Laura D. Fowler (laura@ucar.edu) / 2013-07-03.
! * modified sourcecode to use pools.
!   Laura D. Fowler (laura@ucar.edu) / 2014-05-15.
! * renamed config_conv_deep_scheme to config_convection_scheme.
!   Laura D. Fowler (laura@ucar.edu) / 2014-09-18.
! * in the call to driver_convection, added block%configs needed for the implementation of the
!   Grell-Freitas convection scheme.
!   Laura D. Fowler (laura@ucar.edu) / 2016-03-30.
! * modified the call to the subroutines driver_sfclayer and driver_pbl for the implementation
!   of the MYNN surface layer scheme and PBL schemes. itimestep and block%configs are added to
!   the argument list.
!   Laura D. Fowler (laura@ucar.edu) / 2015-01-06.
! * now only call subroutine update_convection_step2 when config_convection_scheme is not off.
!   Laura D. Fowler (laura@ucar.edu) / 2016-04-13.
! * modified call to driver_cloudiness to accomodate the calculation of the cloud fraction with the Thompson
!   cloud microphysics scheme.
!   Laura D. Fowler (laura@ucar.edu) / 2016-06-04.
! * added call to the Noah-MP land surface scheme.
!   Laura D. Fowler (laura@ucar.edu) / 2024-03-11.


 contains


!=================================================================================================================
 subroutine physics_driver(domain,itimestep,xtime_s)
!=================================================================================================================

!input arguments:
 integer,intent(in):: itimestep
 real(kind=RKIND),intent(in):: xtime_s

!inout arguments:
 type(domain_type),intent(inout):: domain

!local pointers:
 type(mpas_pool_type),pointer::  configs,             &
                                 mesh,                &
                                 state,               &
                                 diag,                &
                                 diag_physics,        &
                                 diag_physics_noahmp, &
                                 output_noahmp,       &
                                 tend_physics,        &
                                 atm_input,           &
                                 ngw_input,           &
                                 sfc_input

 logical,pointer:: config_frac_seaice

 character(len=StrKIND),pointer:: config_bucket_update,     &
                                  config_convection_scheme, &
                                  config_gwdo_scheme,       &
                                  config_lsm_scheme,        &
                                  config_pbl_scheme,        &
                                  config_radt_lw_scheme,    &
                                  config_radt_sw_scheme,    &
                                  config_sfclayer_scheme

 logical, pointer:: config_oml1d
 real(kind=RKIND),pointer:: config_bucket_radt

!local variables:
 type(block_type),pointer:: block

 integer:: time_lev
 integer:: thread

 integer,pointer:: nThreads
 integer,dimension(:),pointer:: cellSolveThreadStart, cellSolveThreadEnd

!=================================================================================================================
!call mpas_log_write('')
!call mpas_log_write('--- enter subroutine mpas_atmphys_driver:')

 call mpas_timer_start('physics driver')

 call mpas_pool_get_config(domain%configs,'config_convection_scheme',config_convection_scheme)
 call mpas_pool_get_config(domain%configs,'config_gwdo_scheme'      ,config_gwdo_scheme      )
 call mpas_pool_get_config(domain%configs,'config_lsm_scheme'       ,config_lsm_scheme       )
 call mpas_pool_get_config(domain%configs,'config_pbl_scheme'       ,config_pbl_scheme       )
 call mpas_pool_get_config(domain%configs,'config_radt_lw_scheme'   ,config_radt_lw_scheme   )
 call mpas_pool_get_config(domain%configs,'config_radt_sw_scheme'   ,config_radt_sw_scheme   )
 call mpas_pool_get_config(domain%configs,'config_sfclayer_scheme'  ,config_sfclayer_scheme  )
 call mpas_pool_get_config(domain%configs,'config_bucket_radt'      ,config_bucket_radt      )
 call mpas_pool_get_config(domain%configs,'config_bucket_update'    ,config_bucket_update    )
 call mpas_pool_get_config(domain%configs,'config_frac_seaice'      ,config_frac_seaice      ) 
 call mpas_pool_get_config(domain%configs,'config_oml1d'            ,config_oml1d            )

 if(config_convection_scheme .ne. 'off' .or. &
    config_lsm_scheme        .ne. 'off' .or. &
    config_pbl_scheme        .ne. 'off' .or. & 
    config_radt_lw_scheme    .ne. 'off' .or. &
    config_radt_sw_scheme    .ne. 'off' .or. &
    config_sfclayer_scheme   .ne. 'off') then

 block => domain % blocklist
 do while(associated(block))

    call mpas_pool_get_subpool(block%structs,'mesh'               ,mesh               )
    call mpas_pool_get_subpool(block%structs,'state'              ,state              )
    call mpas_pool_get_subpool(block%structs,'diag'               ,diag               )
    call mpas_pool_get_subpool(block%structs,'diag_physics'       ,diag_physics       )
    call mpas_pool_get_subpool(block%structs,'diag_physics_noahmp',diag_physics_noahmp)
    call mpas_pool_get_subpool(block%structs,'output_noahmp'      ,output_noahmp      )
    call mpas_pool_get_subpool(block%structs,'atm_input'          ,atm_input          )
    call mpas_pool_get_subpool(block%structs,'sfc_input'          ,sfc_input          )
    call mpas_pool_get_subpool(block%structs,'ngw_input'          ,ngw_input          )
    call mpas_pool_get_subpool(block%structs,'tend_physics'       ,tend_physics       )

    call mpas_pool_get_dimension(block%dimensions,'nThreads',nThreads)

    call mpas_pool_get_dimension(block%dimensions,'cellSolveThreadStart',cellSolveThreadStart)
    call mpas_pool_get_dimension(block%dimensions,'cellSolveThreadEnd',cellSolveThreadEnd)

    !allocate arrays shared by all physics parameterizations:
    call allocate_forall_physics(block%configs)

    !physics prep step:
    time_lev = 1

!$OMP PARALLEL DO
    do thread=1,nThreads
       call MPAS_to_physics(block%configs,mesh,state,time_lev,diag,diag_physics, &
                            cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
    end do
!$OMP END PARALLEL DO

    !call to cloud scheme:
    if(l_radtlw .or. l_radtsw) then
       call allocate_cloudiness
!$OMP PARALLEL DO
       do thread=1,nThreads
          call driver_cloudiness(block%configs,mesh,diag_physics,sfc_input, &
                                 cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       end do
!$OMP END PARALLEL DO
    endif

    !call to short wave radiation scheme:
    if(l_radtsw) then
       time_lev = 1
       call allocate_radiation_sw(block%configs,xtime_s)
!$OMP PARALLEL DO
       do thread=1,nThreads
          call driver_radiation_sw(itimestep,block%configs,mesh,state,time_lev,diag_physics, &
                                   atm_input,sfc_input,tend_physics,xtime_s, &
                                   cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       end do
!$OMP END PARALLEL DO
    endif

    !call to long wave radiation scheme:
    if(l_radtlw) then
       time_lev = 1
       call allocate_radiation_lw(block%configs,xtime_s)
!$OMP PARALLEL DO
       do thread=1,nThreads
          call driver_radiation_lw(xtime_s,block%configs,mesh,state,time_lev,diag_physics, &
                                   atm_input,sfc_input,tend_physics, &
                                   cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       end do
!$OMP END PARALLEL DO
    endif

    !call to accumulate long- and short-wave diagnostics if needed:
     if(config_bucket_update /= 'none' .and. config_bucket_radt .gt. 0._RKIND) then
!$OMP PARALLEL DO
       do thread=1,nThreads
          call update_radiation_diagnostics(block%configs,mesh,diag_physics, &
                                            cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       end do
!$OMP END PARALLEL DO
     endif

    !deallocate all radiation arrays:
    if(config_radt_sw_scheme.ne.'off' .or. config_radt_lw_scheme.ne.'off') &
       call deallocate_cloudiness
    if(config_radt_sw_scheme.ne.'off') call deallocate_radiation_sw(block%configs)
    if(config_radt_lw_scheme.ne.'off') call deallocate_radiation_lw(block%configs)

    !call to surface-layer scheme:
    if(config_sfclayer_scheme .ne. 'off') then
       call allocate_sfclayer(block%configs)
!$OMP PARALLEL DO
       do thread=1,nThreads
          call driver_sfclayer(itimestep,block%configs,mesh,diag_physics,sfc_input, &
                               cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       end do
!$OMP END PARALLEL DO
       call deallocate_sfclayer(block%configs)
    endif

    !call to 1d ocean mixed-layer model
    if(config_oml1d) call driver_oml1d(block%configs,mesh,diag,diag_physics,sfc_input)

    !call to land-surface scheme:
    if(config_lsm_scheme .ne. 'off') then
       if(config_lsm_scheme == 'sf_noah') then
          call allocate_lsm
!$OMP PARALLEL DO
          do thread=1,nThreads
             call driver_lsm(itimestep,block%configs,mesh,diag_physics,sfc_input, &
                             cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
          end do
!$OMP END PARALLEL DO
       call deallocate_lsm

       elseif(config_lsm_scheme == 'sf_noahmp') then
          do thread=1,nThreads
             call driver_lsm_noahmp(block%configs,mesh,state,time_lev,diag,diag_physics,   &
                                    diag_physics_noahmp,output_noahmp,sfc_input,itimestep, &
                                    cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
          enddo
       endif

       call allocate_seaice(block%configs)
!$OMP PARALLEL DO
       do thread=1,nThreads
          call driver_seaice(block%configs,diag_physics,sfc_input, &
                             cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       enddo
!$OMP END PARALLEL DO
       call deallocate_seaice(block%configs)

!$OMP PARALLEL DO
       do thread=1,nThreads
          call atmphys_sfc_diagnostics(block%configs,mesh,diag,diag_physics,sfc_input,output_noahmp, &
                           cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       enddo
!$OMP END PARALLEL DO
    endif

    !call to pbl schemes:
    if(config_pbl_scheme .ne. 'off' .and. config_sfclayer_scheme .ne. 'off') then
       call allocate_pbl(block%configs)
!$OMP PARALLEL DO
       do thread=1,nThreads
          call driver_pbl(itimestep,block%configs,mesh,sfc_input,diag_physics,tend_physics, &
                          cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       end do
!$OMP END PARALLEL DO
       call deallocate_pbl(block%configs)

    endif

    !call to gravity wave drag over orography scheme:
    if(config_gwdo_scheme .ne. 'off') then
       call allocate_gwdo(block%configs)
!$OMP PARALLEL DO
       do thread=1,nThreads
          call driver_gwdo(itimestep,block%configs,mesh,sfc_input,ngw_input,diag_physics,       &
                           tend_physics,cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       end do
!$OMP END PARALLEL DO
       call deallocate_gwdo(block%configs)
    endif

    !call to convection scheme:
!$OMP PARALLEL DO
    do thread=1,nThreads
       call update_convection_step1(block%configs,diag_physics,tend_physics, &
                            cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
    end do
!$OMP END PARALLEL DO
    if(l_conv) then
       call allocate_convection(block%configs)
!$OMP PARALLEL DO
       do thread=1,nThreads
          call driver_convection(itimestep,block%configs,mesh,sfc_input,diag_physics,tend_physics, &
                                 cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       end do
!$OMP END PARALLEL DO
       call deallocate_convection(block%configs)
    endif
    !update diagnostics:
    if(config_convection_scheme .ne. 'off') then
!$OMP PARALLEL DO
       do thread=1,nThreads
          call update_convection_step2(block%configs,diag_physics, &
                               cellSolveThreadStart(thread),cellSolveThreadEnd(thread))
       end do
!$OMP END PARALLEL DO
    end if

    !deallocate arrays shared by all physics parameterizations:
    call deallocate_forall_physics(block%configs)

    block => block % next
 end do 

 endif

 call mpas_timer_stop('physics driver')

!call mpas_log_write('--- enter subroutine mpas_atmphys_driver:')
!call mpas_log_write('')

 end subroutine physics_driver

!=================================================================================================================
 end module mpas_atmphys_driver
!=================================================================================================================
