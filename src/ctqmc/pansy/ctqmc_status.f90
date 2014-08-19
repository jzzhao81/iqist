!!!-------------------------------------------------------------------------
!!! project : pansy
!!! program : ctqmc_save_status
!!!           ctqmc_retrieve_status
!!! source  : ctqmc_status.f90
!!! type    : subroutine
!!! author  : li huang (email:huangli712@yahoo.com.cn)
!!!           yilin wang (email:qhwyl2006@126.com)
!!! history : 09/23/2009 by li huang
!!!           09/26/2009 by li huang
!!!           10/10/2009 by li huang
!!!           10/20/2009 by li huang
!!!           10/29/2009 by li huang
!!!           11/01/2009 by li huang
!!!           11/10/2009 by li huang
!!!           11/29/2009 by li huang
!!!           12/01/2009 by li huang
!!!           12/02/2009 by li huang
!!!           12/26/2009 by li huang
!!!           02/21/2010 by li huang
!!!           08/18/2014 by yilin wang
!!! purpose : save or retrieve the perturbation expansion series information
!!!           to or from the status file for hybridization expansion version
!!!           continuous time quantum Monte Carlo (CTQMC) quantum impurity
!!!           solver, respectively.
!!!           it can be used to save the computational time to achieve the
!!!           equilibrium state
!!! status  : unstable
!!! comment :
!!!-------------------------------------------------------------------------

!!>>> ctqmc_save_status: save the current perturbation expansion series
!!>>> information for the continuous time quantum Monte Carlo quantum
!!>>> impurity solver
  subroutine ctqmc_save_status()
     use constants, only : mytmp
     use control, only : norbs

     use context, only : rank, time_s, time_e, index_s, index_e
     use context, only : empty_v, time_v, flvr_v, type_v, index_v

     use stack, only : istack_getrest

     implicit none

! local variables
! loop index over orbitals
     integer :: i

! loop index over operators
     integer :: j

! total number of operators
     integer :: nsize

! string for current date and time
     character (len = 20) :: date_time_string

! obtain current date and time
     call s_time_builder(date_time_string)

! evaluate nsize at first
     nsize = istack_getrest( empty_v )

! open status file: solver.status.dat
     open(mytmp, file='solver.status.dat', form='formatted', status='unknown')

! write the header message
     write(mytmp,'(a)') '>> WARNING: DO NOT MODIFY THIS FILE MANUALLY'
     write(mytmp,'(a)') '>> it is used to store current status of ctqmc quantum impurity solver'
     write(mytmp,'(a)') '>> generated by PANSY code at '//date_time_string
     write(mytmp,'(a)') '>> any problem, please contact me: huangli712@yahoo.com.cn'

! dump the colour part
     do i=1,norbs
         write(mytmp,'(a,i4)') '# flavor     :', i

! write out create operators
         write(mytmp,'(a,i4)') '# time_s data:', rank(i)
         do j=1,rank(i)
             write(mytmp,'(2i4,f12.6)') i, j, time_s( index_s(j, i), i )
         enddo ! over j={1,rank(i)} loop

! write out destroy operators
         write(mytmp,'(a,i4)') '# time_e data:', rank(i)
         do j=1,rank(i)
             write(mytmp,'(2i4,f12.6)') i, j, time_e( index_e(j, i), i )
         enddo ! over j={1,rank(i)} loop

         write(mytmp,*) ! write empty lines
         write(mytmp,*)
     enddo ! over i={1,norbs} loop

! dump the flavor part, not be used at all, just for reference
     write(mytmp,'(a,i4)') '# time_v data:', nsize
     do j=1,nsize
         write(mytmp,'(3X,a,i4)',advance='no') '>>>', j
         write(mytmp,'(3X,a,i4)',advance='no') 'flvr:', flvr_v( index_v(j) )
         write(mytmp,'(3X,a,i4)',advance='no') 'type:', type_v( index_v(j) )
         write(mytmp,'(3X,a,f12.6)')           'time:', time_v( index_v(j) )
     enddo ! over j={1,nsize} loop

! close the file handler
     close(mytmp)

     return
  end subroutine ctqmc_save_status

!!>>> ctqmc_retrieve_status: retrieve the perturbation expansion series
!!>>> information to initialize the continuous time quantum Monte Carlo
!!>>> quantum impurity solver
  subroutine ctqmc_retrieve_status()
     use constants, only : dp, zero, epss, mytmp
     use control, only : mkink, myid, master, norbs, beta
     use context, only : ckink, rank, matrix_ntrace, csign, cnegs

     use mmpi

     implicit none

! local variables
! loop index
     integer  :: i
     integer  :: j

! dummy integer variables
     integer  :: i1
     integer  :: j1

! index address for create and destroy operators in flavor part, respectively
     integer  :: fis
     integer  :: fie

! whether it is valid to update the configuration
     logical  :: ladd

! used to check whether the input file (solver.status.dat) exists
     logical  :: exists

! dummy character variables
     character(14) :: chr

! determinant ratio for insert operators
     real(dp) :: deter_ratio

! dummy variables, used to store imaginary time points
     real(dp) :: tau_s(mkink,norbs)
     real(dp) :: tau_e(mkink,norbs)

! initialize variables
     exists = .false.

     tau_s = zero
     tau_e = zero

! inquire file status: solver.status.dat, only master node can do it
     if ( myid == master ) then
         inquire (file = 'solver.status.dat', exist = exists)
     endif

! broadcast exists from master node to all children nodes
# if defined (MPI)

! broadcast data
     call mp_bcast( exists, master )

! block until all processes have reached here
     call mp_barrier()

# endif  /* MPI */

! if solver.status.dat does not exist, return parent subroutine immediately
     if ( exists .eqv. .false. ) RETURN

! read solver.status.dat, only master node can do it
     if ( myid == master ) then

! open the status file
         open(mytmp, file='solver.status.dat', form='formatted', status='unknown')

! skip comment lines
         read(mytmp,*)
         read(mytmp,*)
         read(mytmp,*)
         read(mytmp,*)

! read in key data
         do i=1,norbs
             read(mytmp, '(a14,i4)') chr, i1

             read(mytmp, '(a14,i4)') chr, ckink
             do j=1,ckink
                 read(mytmp,*) i1, j1, tau_s(j, i)
             enddo ! over j={1,ckink} loop

             read(mytmp, '(a14,i4)') chr, ckink
             do j=1,ckink
                 read(mytmp,*) i1, j1, tau_e(j, i)
             enddo ! over j={1,ckink} loop

             read(mytmp,*) ! skip two lines
             read(mytmp,*)

             rank(i) = ckink
         enddo ! over i={1,norbs} loop

! close the status file
         close(mytmp)

     endif ! back if ( myid == master ) block

! broadcast rank, tau_s, and tau_e from master node to all children nodes
# if defined (MPI)

! broadcast data
     call mp_bcast( rank,  master )

! block until all processes have reached here
     call mp_barrier()

! broadcast data
     call mp_bcast( tau_s, master )
     call mp_bcast( tau_e, master )

! block until all processes have reached here
     call mp_barrier()

# endif  /* MPI */

! check the validity of tau_s
     if ( maxval(tau_s) > beta ) then
         call s_print_error('ctqmc_retrieve_status','the retrieved tau_s data are not correct')
     endif

! check the validity of tau_e
     if ( maxval(tau_e) > beta ) then
         call s_print_error('ctqmc_retrieve_status','the retrieved tau_e data are not correct')
     endif

! restore all the operators for colour part
     do i=1,norbs
         do j=1,rank(i)
             ckink = j - 1 ! update ckink simultaneously
             call cat_insert_detrat(i, tau_s(j, i), tau_e(j, i), deter_ratio)
             call cat_insert_matrix(i, j, j, tau_s(j, i), tau_e(j, i), deter_ratio)
         enddo ! over j={1,rank(i)} loop
     enddo ! over i={1,norbs} loop

! restore all the operators for flavor part
     do i=1,norbs
         do j=1,rank(i)
             call try_insert_flavor(i, fis, fie, tau_s(j, i), tau_e(j, i), ladd)
             call cat_insert_flavor(i, fis, fie, tau_s(j, i), tau_e(j, i))
         enddo ! over j={1,rank(i)} loop
     enddo ! over i={1,norbs} loop

! update the matrix trace for product of F matrix and time evolution operators
     i = 2 * sum(rank) ! get total number of operators
     call ctqmc_make_ztrace(4, i, matrix_ntrace, -1.0_dp, -1.0_dp)

! update the operators trace
     call ctqmc_make_evolve()

! reset csign and cnegs
     csign = 1
     cnegs = 0

! finally, it is essential to check the validity of matrix_ntrace
     if ( abs( matrix_ntrace - zero ) < epss ) then
         call s_print_exception('ctqmc_retrieve_status','very dangerous! ztrace maybe too small')
     endif

     return
  end subroutine ctqmc_retrieve_status
