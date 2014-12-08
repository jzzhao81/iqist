!!!=========+=========+=========+=========+=========+=========+=========+!
!!! DAISY @ iQIST                                                        !
!!!                                                                      !
!!! A test program for dynamical mean field theory (DMFT) self-consistent!
!!! engine plus classical Hirsch-Fye quantum Monte Carlo (HFQMC) quantum !
!!! impurity solver                                                      !
!!! author  : Li Huang (at IOP/CAS & SPCLab/CAEP & UNIFR)                !
!!! version : v2014.10.11T                                               !
!!! status  : WARNING: IN TESTING STAGE, USE IT IN YOUR RISK             !
!!! comment : any question, please contact with huangli712@gmail.com     !
!!!=========+=========+=========+=========+=========+=========+=========+!

!!
!!
!! WARNING
!! =======
!!
!! If you want to obtain an executable program, please go to src/build/,
!! open make.sys and comment out the API flag. On the contrary, if you
!! want to compile azalea as a library, please activate the API flag.
!!
!! Introduction
!! ============
!!
!! The azalea code is a hybridization expansion version continuous time
!! quantum Monte Carlo quantum impurity solver. It adopts the segment
!! picture, and only implements very limited features. So it is highly
!! efficient, and can be used as a standard to benchmark the other ctqmc
!! impurity solvers. In fact, it is the prototype for the other more
!! advanced ctqmc impurity solver. The azalea code also includes a mini
!! dynamical mean field theory engine which implements the self-consistent
!! equation for Bethe lattice in paramagnetic state. So you can use it
!! to perform dynamical mean field theory calculations quickly. Enjoy it.
!!
!! Usage
!! =====
!!
!! # ./ctqmc or bin/azalea.x
!!
!! Input
!! =====
!!
!! solver.ctqmc.in (optional)
!! solver.eimp.in (optional)
!! solver.hyb.in (optional)
!!
!! Output
!! ======
!!
!! terminal output
!! solver.green.bin.*
!! solver.green.dat
!! solver.grn.dat
!! solver.hybri.dat
!! solver.hyb.dat
!! solver.wss.dat
!! solver.sgm.dat
!! solver.hub.dat
!! solver.hist.dat
!! solver.prob.dat
!! solver.nmat.dat
!! solver.status.dat
!! etc.
!!
!! Running mode
!! ============
!!
!! case 1: isscf == 1 .and. isbin == 1
!! -----------------------------------
!!
!! call ctqmc_impurity_solver only, normal mode
!!
!! case 2: isscf == 1 .and. isbin == 2
!! -----------------------------------
!!
!! call ctqmc_impurity_solver only, binner mode
!!
!! case 3: isscf == 2 .and. isbin == 1
!! -----------------------------------
!!
!! call ctqmc_impurity_solver, normal mode
!! plus
!! call ctqmc_dmft_selfer
!! until convergence
!!
!! case 4: isscf == 2 .and. isbin == 2
!! -----------------------------------
!!
!! call ctqmc_impurity_solver, normal mode
!! plus
!! call ctqmc_dmft_selfer
!! until convergence
!! plus
!! call ctqmc_impurity_solver, binner mode
!!
!! Documents
!! =========
!!
!! For more details, please go to iqist/doc/manual directory.
!!
!!

# if !defined (API)

  program hfqmc_main
     use constants, only : mystd
     use mmpi, only : mp_init, mp_finalize
     use mmpi, only : mp_comm_rank, mp_comm_size
     use mmpi, only : mp_barrier

     use control, only : isscf, isbin
     use control, only : niter
     use control, only : nprocs, myid, master

     implicit none

! local variables
! loop index
     integer :: iter

! convergence flag
     logical :: convergence

! initialize mpi envirnoment
# if defined (MPI)

! initialize the mpi execution environment
     call mp_init()

! determines the rank of the calling process in the communicator
     call mp_comm_rank(myid)

! determines the size of the group associated with a communicator
     call mp_comm_size(nprocs)

# endif  /* MPI */

! print the running header for Hirsch-Fye quantum Monte Carlo quantum
! impurity solver and dynamical mean field theory self-consistent engine
     if ( myid == master ) then ! only master node can do it
         call hfqmc_print_header()
     endif ! back if ( myid == master ) block

! setup the important parameters for Hirsch-Fye quantum Monte Carlo
! quantum impurity solver and dynamical mean field theory self-consistent
! engine
     call hfqmc_config()

! print out runtime parameters in summary, only for check
     if ( myid == master ) then ! only master node can do it
         call hfqmc_print_summary()
     endif ! back if ( myid == master ) block

! allocate memory and initialize
     call hfqmc_setup_array()

! prepare initial bath weiss's function, init self-consistent iteration
     call hfqmc_selfer_init()

!!========================================================================
!!>>> DMFT ITERATION BEGIN                                             <<<
!!========================================================================

! case A: one-shot non-self-consistent mode
!-------------------------------------------------------------------------
! it is suitable for local density approximation plus dynamical mean field
! theory calculation
     if ( isscf == 1 .and. isbin == 1 ) then

! set the iter number
         iter = niter

! write the iter to screen
         if ( myid == master ) then ! only master node can do it
             write(mystd,'(2X,a,i3,a)') 'DAISY >>> DMFT iter:', iter, ' <<< SELFING'
         endif ! back if ( myid == master ) block

! call the Hirsch-Fye quantum Monte Carlo quantum impurity solver, to
! build the impurity green's function and self-energy function
         call hfqmc_impurity_solver(iter)

     endif ! back if ( isscf == 1 .and. isbin == 1 ) block

! case B: self-consistent mode
!-------------------------------------------------------------------------
! it is suitable for lattice model hamiltonian plus dynamical mean field
! theory calculation
     DMFT_HFQMC_ITERATION: do iter=1,niter

! check the running mode
         if ( isscf == 1 ) then
             EXIT DMFT_HFQMC_ITERATION ! jump out the iteration
         endif ! back if ( isscf == 1 ) block

! write the iter to screen
         if ( myid == master ) then ! only master node can do it
             write(mystd,'(2X,a,i3,a)') 'DAISY >>> DMFT iter:', iter, ' <<< SELFING'
         endif ! back if ( myid == master ) block

! call the Hirsch-Fye quantum Monte Carlo quantum impurity solver, to
! build the impurity green's function and self-energy function
         call hfqmc_impurity_solver(iter)

! call the self-consistent engine for dynamical mean field theory, to build
! the bath weiss's function
         call hfqmc_dmft_selfer()

! check convergence for dynamical mean field theory iteration
         convergence = .false.
         call hfqmc_dmft_conver(iter, convergence)

! now convergence is achieved
         if ( convergence .eqv. .true. ) then
             EXIT DMFT_HFQMC_ITERATION ! jump out the iteration
         endif ! back if ( convergence .eqv. .true. ) block

     enddo DMFT_HFQMC_ITERATION ! over iter={1,niter} loop

! case C: binner mode
!-------------------------------------------------------------------------
! perform quantum Monte Carlo data binning
     if ( isbin == 2 ) then

! set the iter number
         iter = 999

! write the iter to screen
         if ( myid == master ) then ! only master node can do it
             write(mystd,'(2X,a,i3,a)') 'DAISY >>> DMFT iter:', iter, ' <<< BINNING'
         endif ! back if ( myid == master ) block

! accumulate the quantum Monte Carlo data
         call hfqmc_impurity_solver(iter)

     endif ! back if ( isbin == 2 ) block

!!========================================================================
!!>>> DMFT ITERATION END                                               <<<
!!========================================================================

! deallocate memory and finalize
     call hfqmc_final_array()

! print the footer for Hirsch-Fye quantum Monte Carlo quantum impurity
! solver and dynamical mean field theory self-consistent engine
     if ( myid == master ) then ! only master node can do it
         call hfqmc_print_footer()
     endif ! back if ( myid == master ) block

! finalize mpi envirnoment
# if defined (MPI)

! blocks until all processes have reached this routine
     call mp_barrier()

! terminates mpi execution environment
     call mp_finalize()

# endif  /* MPI */

  end program hfqmc_main

# endif  /* API */
