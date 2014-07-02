!-------------------------------------------------------------------------
! project : lavender
! program : ctqmc_print_header
!           ctqmc_print_footer
!           ctqmc_print_summary
!           ctqmc_print_runtime
!           ctqmc_print_error
!           ctqmc_print_exception
! source  : ctqmc_print.f90
! type    : subroutines
! author  : li huang (email:huangli712@yahoo.com.cn)
! history : 09/15/2009 by li huang
!           09/20/2009 by li huang
!           12/01/2009 by li huang
!           02/21/2010 by li huang
! purpose : provide printing infrastructure for hybridization expansion
!           version continuous time quantum Monte Carlo (CTQMC) quantum
!           impurity solver
! input   :
! output  :
! status  : very unstable
! comment :
!-------------------------------------------------------------------------

!>>> print the startup information for continuous time quantum Monte Carlo
! quantum impurity solver plus dynamical mean field theory self-consistent
! engine
  subroutine ctqmc_print_header()
     use constants
     use control, only : nprocs

     implicit none

! string for current date and time
     character (len = 20) :: date_time_string

! obtain current date and time
     call ctqmc_time_builder(date_time_string)

     write(mystd,'(2X,a)') 'LAVENDER'
     write(mystd,'(2X,a)') '>>> A DMFT Engine With Continuous Time Quantum Monte Carlo Impurity Solver'
     write(mystd,*)

     write(mystd,'(2X,a)') 'version: 2012.08.20T '//'(built at '//__TIME__//" "//__DATE__//')'
     write(mystd,'(2X,a)') 'develop: by li huang, CAEP & IOP'
     write(mystd,'(2X,a)') 'support: huangli712@yahoo.com.cn'
     write(mystd,'(2X,a)') 'license: GPL2 and later versions'
     write(mystd,*)

     write(mystd,'(2X,a)') 'LAVENDER >>> start running at '//date_time_string

# if defined (MPI)

     write(mystd,'(2X,a,i4)') 'LAVENDER >>> parallelism: Yes >>> processors:', nprocs

# else   /* MPI */

     write(mystd,'(2X,a,i4)') 'LAVENDER >>> parallelism: No  >>> processors:', 1

# endif  /* MPI */

     write(mystd,*)

     return
  end subroutine ctqmc_print_header

!>>> print the ending information for continuous time quantum Monte Carlo
! quantum impurity solver plus dynamical mean field theory self-consistent
! engine
  subroutine ctqmc_print_footer()
     use constants

     implicit none

! string for current date and time
     character (len = 20) :: date_time_string

! used to record the time usage information
     real(dp) :: tot_time

! obtain time usage information
     call cpu_time(tot_time)

! obtain current date and time
     call ctqmc_time_builder(date_time_string)

     write(mystd,'(2X,a,f10.2,a)') 'LAVENDER >>> total time spent:', tot_time, 's'
     write(mystd,*)

     write(mystd,'(2X,a)') 'LAVENDER >>> I am tired and want to go to bed. Bye!'
     write(mystd,'(2X,a)') 'LAVENDER >>> happy ending at '//date_time_string

     return
  end subroutine ctqmc_print_footer

!>>> print the running parameters, only for reference
  subroutine ctqmc_print_summary()
     use constants
     use control

     implicit none

     write(mystd,'(2X,a)') 'LAVENDER >>> parameters list:'

     write(mystd,'(2(4X,a,i10))')   'isscf :', isscf  , 'isbin :', isbin
     write(mystd,'(2(4X,a,i10))')   'issun :', issun  , 'isspn :', isspn
     write(mystd,'(2(4X,a,i10))')   'isort :', isort  , 'isvrt :', isvrt

     write(mystd,'(2(4X,a,i10))')   'lemax :', lemax  , 'legrd :', legrd
     write(mystd,'(2(4X,a,i10))')   'chmax :', chmax  , 'chgrd :', chgrd
     write(mystd,'(2(4X,a,i10))')   'mkink :', mkink  , 'mfreq :', mfreq
     write(mystd,'(2(4X,a,i10))')   'nband :', nband  , 'nspin :', nspin
     write(mystd,'(2(4X,a,i10))')   'norbs :', norbs  , 'ncfgs :', ncfgs
     write(mystd,'(2(4X,a,i10))')   'nzero :', nzero  , 'niter :', niter
     write(mystd,'(2(4X,a,i10))')   'nffrq :', nffrq  , 'nbfrq :', nbfrq
     write(mystd,'(2(4X,a,i10))')   'nfreq :', nfreq  , 'ntime :', ntime
     write(mystd,'(2(4X,a,i10))')   'npart :', npart  , 'nflip :', nflip

     write(mystd,'(2(4X,a,i10))')   'ntherm:', ntherm , 'nsweep:', nsweep
     write(mystd,'(2(4X,a,i10))')   'nclean:', nclean , 'nwrite:', nwrite
     write(mystd,'(2(4X,a,i10))')   'nmonte:', nmonte , 'ncarlo:', ncarlo

     write(mystd,'(2(4X,a,f10.5))') 'U     :', U      , 'Uc    :', Uc
     write(mystd,'(2(4X,a,f10.5))') 'Js    :', Js     , 'Uv    :', Uv
     write(mystd,'(2(4X,a,f10.5))') 'Jp    :', Jp     , 'Jz    :', Jz
     write(mystd,'(2(4X,a,f10.5))') 'mune  :', mune   , 'beta  :', beta
     write(mystd,'(2(4X,a,f10.5))') 'part  :', part   , 'temp  :', ev2k/beta

     write(mystd,*)

     return
  end subroutine ctqmc_print_summary

!>>> print the runtime information, including physical observables and
! statistic data, only for reference
  subroutine ctqmc_print_runtime(iter, cstep)
     use constants
     use context

     implicit none

! external arguments
! current self-consistent iteration number
     integer, intent(in) :: iter

! current QMC sweeping steps
     integer, intent(in) :: cstep

! local variables
! integer dummy variables
     integer :: istat

! about iteration number
     write(mystd,'(2X,a,i3,2(a,i10))') 'LAVENDER >>> iter:', iter, ' sweep:', cstep, ' of ', nsweep

! about auxiliary physical observables
     istat = cstep / nmonte
     write(mystd,'(4X,a)')        'auxiliary system observables:'
     write(mystd,'(2(4X,a,f10.5))') 'etot :', paux(1) / istat, 'epot :', paux(2) / istat
     write(mystd,'(2(4X,a,f10.5))') 'ekin :', paux(3) / istat, '<Sz> :', paux(4) / istat

! about insert action
     if ( insert_tcount <= half ) insert_tcount = -one ! if insert is disable
     write(mystd,'(4X,a)')        'insert kink statistics:'
     write(mystd,'(4X,a,3i10)')   'count:', int( insert_tcount ), int( insert_accept ), int( insert_reject )
     write(mystd,'(4X,a,3f10.5)') 'ratio:', one, insert_accept / insert_tcount, insert_reject / insert_tcount

! about remove action
     if ( remove_tcount <= half ) remove_tcount = -one ! if remove is disable
     write(mystd,'(4X,a)')        'remove kink statistics:'
     write(mystd,'(4X,a,3i10)')   'count:', int( remove_tcount ), int( remove_accept ), int( remove_reject )
     write(mystd,'(4X,a,3f10.5)') 'ratio:', one, remove_accept / remove_tcount, remove_reject / remove_tcount

! about lshift action
     if ( lshift_tcount <= half ) lshift_tcount = -one ! if lshift is disable
     write(mystd,'(4X,a)')        'lshift kink statistics:'
     write(mystd,'(4X,a,3i10)')   'count:', int( lshift_tcount ), int( lshift_accept ), int( lshift_reject )
     write(mystd,'(4X,a,3f10.5)') 'ratio:', one, lshift_accept / lshift_tcount, lshift_reject / lshift_tcount

! about rshift action
     if ( rshift_tcount <= half ) rshift_tcount = -one ! if rshift is disable
     write(mystd,'(4X,a)')        'rshift kink statistics:'
     write(mystd,'(4X,a,3i10)')   'count:', int( rshift_tcount ), int( rshift_accept ), int( rshift_reject )
     write(mystd,'(4X,a,3f10.5)') 'ratio:', one, rshift_accept / rshift_tcount, rshift_reject / rshift_tcount

! about reflip action
     if ( reflip_tcount <= half ) reflip_tcount = -one ! if reflip is disable
     write(mystd,'(4X,a)')        'global flip statistics:'
     write(mystd,'(4X,a,3i10)')   'count:', int( reflip_tcount ), int( reflip_accept ), int( reflip_reject )
     write(mystd,'(4X,a,3f10.5)') 'ratio:', one, reflip_accept / reflip_tcount, reflip_reject / reflip_tcount

! about negative sign
     write(mystd,'(4X,a,i10)')    'negative sign counter:', cnegs
     write(mystd,'(4X,a,f10.5)')  'averaged sign sampler:', caves / real(cstep)

     return
  end subroutine ctqmc_print_runtime

!>>> print the error information and STOP the program
  subroutine ctqmc_print_error(sub, msg)
     use constants

     implicit none

! external arguments
! subroutine name
     character(len=*), intent(in) :: sub

! error message
     character(len=*), intent(in) :: msg

! print error information
     write(mystd,'(2X,4a)') 'fatal error occurred in ', sub, ': ', msg

! TERMINATE THE PROGRAM
!-------------------------------------------------------------------------
     STOP
!-------------------------------------------------------------------------

     return
  end subroutine ctqmc_print_error

!>>> print normal runtime exceptional information, and continue
  subroutine ctqmc_print_exception(sub, msg)
     use constants

     implicit none

! external arguments
! subroutine name
     character(len=*), intent(in) :: sub

! exception message
     character(len=*), intent(in) :: msg

! print error information
     write(mystd,'(2X,4a)') 'runtime exception occurred in ', sub, ': ', msg

! CONTINUE/PAUSE THE PROGRAM
!-------------------------------------------------------------------------
     CONTINUE ! OR PAUSE
!-------------------------------------------------------------------------

     return
  end subroutine ctqmc_print_exception