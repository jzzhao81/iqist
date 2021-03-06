!!!-----------------------------------------------------------------------
!!! project : lavender
!!! program : ctqmc_impurity_solver
!!!           ctqmc_diagram_warmming
!!!           ctqmc_diagram_sampling
!!!           ctqmc_diagram_checking
!!!           ctqmc_diagram_plotting
!!!           ctqmc_impurity_tester
!!! source  : ctqmc_solver.f90
!!! type    : subroutines
!!! author  : li huang (email:lihuang.dmft@gmail.com)
!!! history : 09/16/2009 by li huang (created)
!!!           08/17/2015 by li huang (last modified)
!!! purpose : the main subroutine for the hybridization expansion version
!!!           continuous time quantum Monte Carlo (CTQMC) quantum impurity
!!!           solver
!!! status  : unstable
!!! comment :
!!!-----------------------------------------------------------------------

!!>>> ctqmc_impurity_solver: core engine for hybridization expansion version
!!>>> continuous time quantum Monte Carlo quantum impurity solver
  subroutine ctqmc_impurity_solver(iter)
     use constants, only : dp, zero, one, mystd

     use control, only : cname
     use control, only : issun, isspn, issus, isvrt
     use control, only : nband, nspin, norbs, ncfgs
     use control, only : mkink, mfreq
     use control, only : nffrq, nbfrq, ntime, nsweep, nwrite, nmonte, ncarlo
     use control, only : Uc, Jz
     use control, only : myid, master
     use context, only : caves
     use context, only : tmesh, rmesh
     use context, only : hist, prob
     use context, only : nmat, nnmat
     use context, only : kmat, kkmat
     use context, only : lmat, rmat, lrmat
     use context, only : g2_re, g2_im, ps_re, ps_im
     use context, only : symm, naux, saux
     use context, only : gtau, grnf
     use context, only : sig2

     implicit none

! external arguments
! current self-consistent iteration number
     integer, intent(in) :: iter

! local variables
! loop index
     integer  :: i
     integer  :: j

! status flag
     integer  :: istat

! current QMC sweeping steps
     integer  :: cstep

! control flag, whether the solver is checked periodically
! cflag = 0  , do not check the quantum impurity solver
! cflag = 1  , check the quantum impurity solver periodically
! cflag = 99 , the quantum impurity solver is out of control
! cflag = 100, the quantum impurity solver has reached convergence
     integer  :: cflag

! starting time
     real(dp) :: time_begin

! ending time
     real(dp) :: time_end

! time consuming by current iteration
     real(dp) :: time_iter

! time consuming by total iteration
     real(dp) :: time_niter

! histogram for perturbation expansion series, for mpi case
     real(dp), allocatable :: hist_mpi(:)
     real(dp), allocatable :: hist_err(:)

! probability of atomic states, for mpi case
     real(dp), allocatable :: prob_mpi(:)
     real(dp), allocatable :: prob_err(:)

! impurity occupation number matrix, for mpi case
     real(dp), allocatable :: nmat_mpi(:)
     real(dp), allocatable :: nmat_err(:)

! impurity double occupation number matrix, for mpi case
     real(dp), allocatable :: nnmat_mpi(:,:)
     real(dp), allocatable :: nnmat_err(:,:)

! number of operators < k >, for mpi case
     real(dp), allocatable :: kmat_mpi(:)
     real(dp), allocatable :: kmat_err(:)

! square of number of operators < k^2 >, for mpi case
     real(dp), allocatable :: kkmat_mpi(:,:)
     real(dp), allocatable :: kkmat_err(:,:)

! number of operators at left half axis < k_l >, for mpi case
     real(dp), allocatable :: lmat_mpi(:)
     real(dp), allocatable :: lmat_err(:)

! number of operators at right half axis < k_r >, for mpi case
     real(dp), allocatable :: rmat_mpi(:)
     real(dp), allocatable :: rmat_err(:)

! used to evaluate fidelity susceptibility < k_l k_r >, for mpi case
     real(dp), allocatable :: lrmat_mpi(:,:)
     real(dp), allocatable :: lrmat_err(:,:)

! note: for the two-particle quantities, we don't measure the error bars
! used to measure two-particle green's function, real part, for mpi case
     real(dp), allocatable :: g2_re_mpi(:,:,:,:,:)

! used to measure two-particle green's function, imaginary part, for mpi case
     real(dp), allocatable :: g2_im_mpi(:,:,:,:,:)

! used to measure particle-particle pair susceptibility, real part, for mpi case
     real(dp), allocatable :: ps_re_mpi(:,:,:,:,:)

! used to measure particle-particle pair susceptibility, imaginary part, for mpi case
     real(dp), allocatable :: ps_im_mpi(:,:,:,:,:)

! impurity green's function, imaginary time axis, for mpi case
     real(dp), allocatable :: gtau_mpi(:,:,:)
     real(dp), allocatable :: gtau_err(:,:,:)

! impurity green's function, matsubara frequency axis, for mpi case
     complex(dp), allocatable :: grnf_mpi(:,:,:)
     complex(dp), allocatable :: grnf_err(:,:,:)

! allocate memory
     allocate(hist_mpi(mkink),             stat=istat)
     allocate(hist_err(mkink),             stat=istat)
     allocate(prob_mpi(ncfgs),             stat=istat)
     allocate(prob_err(ncfgs),             stat=istat)
     allocate(nmat_mpi(norbs),             stat=istat)
     allocate(nmat_err(norbs),             stat=istat)
     allocate(nnmat_mpi(norbs,norbs),      stat=istat)
     allocate(nnmat_err(norbs,norbs),      stat=istat)
     allocate(kmat_mpi(norbs),             stat=istat)
     allocate(kmat_err(norbs),             stat=istat)
     allocate(kkmat_mpi(norbs,norbs),      stat=istat)
     allocate(kkmat_err(norbs,norbs),      stat=istat)
     allocate(lmat_mpi(norbs),             stat=istat)
     allocate(lmat_err(norbs),             stat=istat)
     allocate(rmat_mpi(norbs),             stat=istat)
     allocate(rmat_err(norbs),             stat=istat)
     allocate(lrmat_mpi(norbs,norbs),      stat=istat)
     allocate(lrmat_err(norbs,norbs),      stat=istat)
     allocate(g2_re_mpi(nffrq,nffrq,nbfrq,norbs,norbs), stat=istat)
     allocate(g2_im_mpi(nffrq,nffrq,nbfrq,norbs,norbs), stat=istat)
     allocate(ps_re_mpi(nffrq,nffrq,nbfrq,norbs,norbs), stat=istat)
     allocate(ps_im_mpi(nffrq,nffrq,nbfrq,norbs,norbs), stat=istat)
     allocate(gtau_mpi(ntime,norbs,norbs), stat=istat)
     allocate(gtau_err(ntime,norbs,norbs), stat=istat)
     allocate(grnf_mpi(mfreq,norbs,norbs), stat=istat)
     allocate(grnf_err(mfreq,norbs,norbs), stat=istat)

     if ( istat /= 0 ) then
         call s_print_error('ctqmc_impurity_solver','can not allocate enough memory')
     endif ! back if ( istat /= 0 ) block

! setup cstep
     cstep = 0

! setup cflag, check the status of quantum impurity solver periodically
     cflag = 1

! setup timer
     time_iter = zero
     time_niter = zero

! setup nsweep
! whether it is time to enter QMC data accumulating mode
     if ( iter == 999 ) then
         nsweep = nsweep * 10
         nwrite = nwrite * 10
     endif ! back if ( iter == 999 ) block

!!========================================================================
!!>>> starting quantum impurity solver                                 <<<
!!========================================================================

! print the header of continuous time quantum Monte Carlo quantum impurity solver
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(2X,a)') cname//' >>> CTQMC quantum impurity solver running'
         write(mystd,'(4X,a,i10,4X,a,f10.5)') 'nband :', nband, 'Uc    :', Uc
         write(mystd,'(4X,a,i10,4X,a,f10.5)') 'nspin :', nspin, 'Jz    :', Jz
         write(mystd,*)
     endif ! back if ( myid == master ) block

!!========================================================================
!!>>> initializing quantum impurity solver                             <<<
!!========================================================================

! init the continuous time quantum Monte Carlo quantum impurity solver
! setup the key variables
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(4X,a)') 'quantum impurity solver initializing'
     endif ! back if ( myid == master ) block

     call cpu_time(time_begin) ! record starting time
     call ctqmc_solver_init()
     call cpu_time(time_end)   ! record ending   time

! print the time information
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(4X,a,f10.3,a)') 'time:', time_end - time_begin, 's'
         write(mystd,*)
     endif ! back if ( myid == master ) block

!!========================================================================
!!>>> retrieving quantum impurity solver                               <<<
!!========================================================================

! init the continuous time quantum Monte Carlo quantum impurity solver further
! retrieving the time series information produced by previous running
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(4X,a)') 'quantum impurity solver retrieving'
     endif ! back if ( myid == master ) block

     call cpu_time(time_begin) ! record starting time
     call ctqmc_retrieve_status()
     call cpu_time(time_end)   ! record ending   time

! print the time information
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(4X,a,f10.3,a)') 'time:', time_end - time_begin, 's'
         write(mystd,*)
     endif ! back if ( myid == master ) block

!!========================================================================
!!>>> warmming quantum impurity solver                                 <<<
!!========================================================================

! warmup the continuous time quantum Monte Carlo quantum impurity solver,
! in order to achieve equilibrium state
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(4X,a)') 'quantum impurity solver warmming'
     endif ! back if ( myid == master ) block

     call cpu_time(time_begin) ! record starting time
     call ctqmc_diagram_warmming()
     call cpu_time(time_end)   ! record ending   time

! print the time information
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(4X,a,f10.3,a)') 'time:', time_end - time_begin, 's'
         write(mystd,*)
     endif ! back if ( myid == master ) block

!!========================================================================
!!>>> beginning main iteration                                         <<<
!!========================================================================

! start simulation
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(4X,a)') 'quantum impurity solver sampling'
         write(mystd,*)
     endif ! back if ( myid == master ) block

     CTQMC_MAIN_ITERATION: do i=1, nsweep, nwrite

! record start time
         call cpu_time(time_begin)

         CTQMC_DUMP_ITERATION: do j=1, nwrite

!!========================================================================
!!>>> sampling perturbation expansion series                           <<<
!!========================================================================

! increase cstep by 1
             cstep = cstep + 1

! sampling the perturbation expansion feynman diagrams randomly
             call ctqmc_diagram_sampling(cstep)

!!========================================================================
!!>>> sampling the physical observables                                <<<
!!========================================================================

! record the histogram for perturbation expansion series
             call ctqmc_record_hist()

! record the impurity (double) occupation number matrix and other
! auxiliary physical observables
             if ( mod(cstep, nmonte) == 0 ) then
                 call ctqmc_record_nmat()
             endif ! back if ( mod(cstep, nmonte) == 0 ) block

! record the impurity green's function in matsubara frequency space
             if ( mod(cstep, nmonte) == 0 ) then
                 call ctqmc_record_grnf()
             endif ! back if ( mod(cstep, nmonte) == 0 ) block

! record the probability of eigenstates
             if ( mod(cstep, ncarlo) == 0 ) then
                 call ctqmc_record_prob()
             endif ! back if ( mod(cstep, ncarlo) == 0 ) block

! record the impurity green's function in imaginary time space
             if ( mod(cstep, ncarlo) == 0 ) then
                 call ctqmc_record_gtau()
             endif ! back if ( mod(cstep, ncarlo) == 0 ) block

! record nothing
             if ( mod(cstep, nmonte) == 0 .and. btest(issus, 0) ) then
                 CONTINUE
             endif ! back if ( mod(cstep, nmonte) == 0 .and. btest(issus, 0) ) block

! record the < k^2 > - < k >^2
             if ( mod(cstep, nmonte) == 0 .and. btest(issus, 5) ) then
                 call ctqmc_record_kmat()
             endif ! back if ( mod(cstep, nmonte) == 0 .and. btest(issus, 5) ) block

! record the fidelity susceptibility
             if ( mod(cstep, nmonte) == 0 .and. btest(issus, 6) ) then
                 call ctqmc_record_lmat()
             endif ! back if ( mod(cstep, nmonte) == 0 .and. btest(issus, 6) ) block

! record nothing
             if ( mod(cstep, nmonte) == 0 .and. btest(isvrt, 0) ) then
                 CONTINUE
             endif ! back if ( mod(cstep, nmonte) == 0 .and. btest(isvrt, 0) ) block

! record the two-particle green's function
             if ( mod(cstep, nmonte) == 0 .and. btest(isvrt, 1) ) then
                 call ctqmc_record_twop()
             endif ! back if ( mod(cstep, nmonte) == 0 .and. btest(isvrt, 1) ) block

! record the particle-particle pair susceptibility
             if ( mod(cstep, nmonte) == 0 .and. btest(isvrt, 3) ) then
                 call ctqmc_record_pair()
             endif ! back if ( mod(cstep, nmonte) == 0 .and. btest(isvrt, 3) ) block

         enddo CTQMC_DUMP_ITERATION ! over j={1,nwrite} loop

!!========================================================================
!!>>> reporting quantum impurity solver                                <<<
!!========================================================================

! it is time to write out the statistics results
         if ( myid == master ) then ! only master node can do it
             call ctqmc_print_runtime(iter, cstep)
         endif ! back if ( myid == master ) block

!!========================================================================
!!>>> reducing immediate results                                       <<<
!!========================================================================

! collect the histogram data from hist to hist_mpi
         call ctqmc_reduce_hist(hist_mpi, hist_err)

! collect the impurity green's function data from gtau to gtau_mpi
         gtau = gtau / real(caves)
         call ctqmc_reduce_gtau(gtau_mpi, gtau_err)
         gtau = gtau * real(caves)

! gtau_mpi need to be scaled properly before written
         gtau_mpi = gtau_mpi * real(ncarlo)
         gtau_err = gtau_err * real(ncarlo)

!!========================================================================
!!>>> symmetrizing immediate results                                   <<<
!!========================================================================

! symmetrize the impurity green's function over spin or over bands
         if ( issun == 2 .or. isspn == 1 ) then
             call ctqmc_symm_gtau(symm, gtau_mpi)
             call ctqmc_symm_gtau(symm, gtau_err)
         endif ! back if ( issun == 2 .or. isspn == 1 ) block

!!========================================================================
!!>>> writing immediate results                                        <<<
!!========================================================================

! write out the histogram data, hist_mpi
         if ( myid == master ) then ! only master node can do it
             call ctqmc_dump_hist(hist_mpi, hist_err)
         endif ! back if ( myid == master ) block

! write out the impurity green's function, gtau_mpi
         if ( myid == master ) then ! only master node can do it
             call ctqmc_dump_gtau(tmesh, gtau_mpi, gtau_err)
         endif ! back if ( myid == master ) block

!!========================================================================
!!>>> checking quantum impurity solver                                 <<<
!!========================================================================

! check the status at first
         call ctqmc_diagram_checking(cflag)

! write out the snapshot for the current diagram configuration
         if ( myid == master ) then
             call ctqmc_diagram_plotting(iter, cstep)
         endif ! back if ( myid == master ) block

!!========================================================================
!!>>> timing quantum impurity solver                                   <<<
!!========================================================================

! record ending time for this iteration
         call cpu_time(time_end)

! calculate timing information
         time_iter = time_end - time_begin
         time_niter = time_niter + time_iter
         time_begin = time_end

! print out the result
         if ( myid == master ) then ! only master node can do it
             call s_time_analyzer(time_iter, time_niter)
             write(mystd,*)
         endif ! back if ( myid == master ) block

!!========================================================================
!!>>> escaping quantum impurity solver                                 <<<
!!========================================================================

! if the quantum impurity solver is out of control or reaches convergence
         if ( cflag == 99 .or. cflag == 100 ) then
             EXIT CTQMC_MAIN_ITERATION ! jump out the iteration
         endif ! back if ( cflag == 99 .or. cflag == 100 ) block

     enddo CTQMC_MAIN_ITERATION ! over i={1,nsweep} loop

!!========================================================================
!!>>> ending main iteration                                            <<<
!!========================================================================

!!========================================================================
!!>>> reducing final results                                           <<<
!!========================================================================

! collect the histogram data from hist to hist_mpi
     call ctqmc_reduce_hist(hist_mpi, hist_err)

! collect the probability data from prob to prob_mpi
     prob  = prob  / real(caves)
     call ctqmc_reduce_prob(prob_mpi, prob_err)

! collect the occupation matrix data from nmat to nmat_mpi
! collect the double occupation matrix data from nnmat to nnmat_mpi
     nmat  = nmat  / real(caves)
     nnmat = nnmat / real(caves)
     call ctqmc_reduce_nmat(nmat_mpi, nnmat_mpi, nmat_err, nnmat_err)

! collect the < k^2 > - < k >^2 data from kmat to kmat_mpi
! collect the < k^2 > - < k >^2 data from kkmat to kkmat_mpi
     kmat  = kmat  / real(caves)
     kkmat = kkmat / real(caves)
     call ctqmc_reduce_kmat(kmat_mpi, kkmat_mpi, kmat_err, kkmat_err)

! collect the fidelity susceptibility data from lmat to lmat_mpi
! collect the fidelity susceptibility data from rmat to rmat_mpi
! collect the fidelity susceptibility data from lrmat to lrmat_mpi
     lmat  = lmat  / real(caves)
     rmat  = rmat  / real(caves)
     lrmat = lrmat / real(caves)
     call ctqmc_reduce_lmat(lmat_mpi, rmat_mpi, lrmat_mpi, lmat_err, rmat_err, lrmat_err)

! collect the two-particle green's function from g2_re to g2_re_mpi
! collect the two-particle green's function from g2_im to g2_im_mpi
     g2_re = g2_re / real(caves)
     g2_im = g2_im / real(caves)
     call ctqmc_reduce_twop(g2_re_mpi, g2_im_mpi)

! collect the pair susceptibility from ps_re to ps_re_mpi
! collect the pair susceptibility from ps_im to ps_im_mpi
     ps_re = ps_re / real(caves)
     ps_im = ps_im / real(caves)
     call ctqmc_reduce_pair(ps_re_mpi, ps_im_mpi)

! collect the impurity green's function data from gtau to gtau_mpi
     gtau  = gtau  / real(caves)
     call ctqmc_reduce_gtau(gtau_mpi, gtau_err)

! collect the impurity green's function data from grnf to grnf_mpi
     grnf  = grnf  / real(caves)
     call ctqmc_reduce_grnf(grnf_mpi, grnf_err)

! update original data and calculate the averages simultaneously
! average value section
     hist  = hist_mpi  * one
     prob  = prob_mpi  * real(ncarlo)

     nmat  = nmat_mpi  * real(nmonte)
     nnmat = nnmat_mpi * real(nmonte)
     kmat  = kmat_mpi  * real(nmonte)
     kkmat = kkmat_mpi * real(nmonte)
     lmat  = lmat_mpi  * real(nmonte)
     rmat  = rmat_mpi  * real(nmonte)
     lrmat = lrmat_mpi * real(nmonte)

     g2_re = g2_re_mpi * real(nmonte)
     g2_im = g2_im_mpi * real(nmonte)
     ps_re = ps_re_mpi * real(nmonte)
     ps_im = ps_im_mpi * real(nmonte)

     gtau  = gtau_mpi  * real(ncarlo)
     grnf  = grnf_mpi  * real(nmonte)

! update original data and calculate the averages simultaneously
! error bar section
     hist_err  = hist_err  * one
     prob_err  = prob_err  * real(ncarlo)

     nmat_err  = nmat_err  * real(nmonte)
     nnmat_err = nnmat_err * real(nmonte)
     kmat_err  = kmat_err  * real(nmonte)
     kkmat_err = kkmat_err * real(nmonte)
     lmat_err  = lmat_err  * real(nmonte)
     rmat_err  = rmat_err  * real(nmonte)
     lrmat_err = lrmat_err * real(nmonte)

     gtau_err  = gtau_err  * real(ncarlo)
     grnf_err  = grnf_err  * real(nmonte)

! build atomic green's function and self-energy function using improved
! Hubbard-I approximation, and then make interpolation for self-energy
! function between low frequency QMC data and high frequency Hubbard-I
! approximation data, the impurity green's function can be obtained by
! using dyson's equation finally
     call ctqmc_make_hub1()

!!========================================================================
!!>>> symmetrizing final results                                       <<<
!!========================================================================

! symmetrize the occupation number matrix (nmat) over spin or over bands
     if ( issun == 2 .or. isspn == 1 ) then
         call ctqmc_symm_nmat(symm, nmat)
         call ctqmc_symm_nmat(symm, nmat_err)
     endif ! back if ( issun == 2 .or. isspn == 1 ) block

! symmetrize the impurity green's function (gtau) over spin or over bands
     if ( issun == 2 .or. isspn == 1 ) then
         call ctqmc_symm_gtau(symm, gtau)
         call ctqmc_symm_gtau(symm, gtau_err)
     endif ! back if ( issun == 2 .or. isspn == 1 ) block

! symmetrize the impurity green's function (grnf) over spin or over bands
     if ( issun == 2 .or. isspn == 1 ) then
         call ctqmc_symm_grnf(symm, grnf)
         call ctqmc_symm_grnf(symm, grnf_err)
     endif ! back if ( issun == 2 .or. isspn == 1 ) block

! symmetrize the impurity self-energy function (sig2) over spin or over bands
     if ( issun == 2 .or. isspn == 1 ) then
         call ctqmc_symm_grnf(symm, sig2)
     endif ! back if ( issun == 2 .or. isspn == 1 ) block

!!========================================================================
!!>>> writing final results                                            <<<
!!========================================================================

! write out the final histogram data, hist
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_hist(hist, hist_err)
     endif ! back if ( myid == master ) block

! write out the final probability data, prob
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_prob(prob, naux, saux, prob_err)
     endif ! back if ( myid == master ) block

! write out the final (double) occupation matrix data, nmat and nnmat
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_nmat(nmat, nnmat, nmat_err, nnmat_err)
     endif ! back if ( myid == master ) block

! write out the final < k^2 > - < k >^2 data, kmat and kkmat
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_kmat(kmat, kkmat, kmat_err, kkmat_err)
     endif ! back if ( myid == master ) block

! write out the final fidelity susceptibility data, lmat, rmat, and lrmat
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_lmat(lmat, rmat, lrmat, lmat_err, rmat_err, lrmat_err)
     endif ! back if ( myid == master ) block

! write out the final two-particle green's function data, g2_re and g2_im
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_twop(g2_re, g2_im)
     endif ! back if ( myid == master ) block

! write out the final particle-particle pair susceptibility data, ps_re and ps_im
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_pair(ps_re, ps_im)
     endif ! back if ( myid == master ) block

! write out the final impurity green's function data, gtau
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_gtau(tmesh, gtau, gtau_err)
     endif ! back if ( myid == master ) block

! write out the final impurity green's function data, grnf
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_grnf(rmesh, grnf, grnf_err)
     endif ! back if ( myid == master ) block

! write out the final self-energy function data, sig2
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_sigf(rmesh, sig2)
     endif ! back if ( myid == master ) block

!!========================================================================
!!>>> saving quantum impurity solver                                   <<<
!!========================================================================

! save the perturbation expansion series information to the disk file
     if ( myid == master ) then ! only master node can do it
         call ctqmc_save_status()
     endif ! back if ( myid == master ) block

!!========================================================================
!!>>> finishing quantum impurity solver                                <<<
!!========================================================================

! print the footer of continuous time quantum Monte Carlo quantum impurity solver
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(2X,a)') cname//' >>> CTQMC quantum impurity solver shutdown'
         write(mystd,*)
     endif ! back if ( myid == master ) block

! deallocate memory
     deallocate(hist_mpi )
     deallocate(hist_err )
     deallocate(prob_mpi )
     deallocate(prob_err )
     deallocate(nmat_mpi )
     deallocate(nmat_err )
     deallocate(nnmat_mpi)
     deallocate(nnmat_err)
     deallocate(kmat_mpi )
     deallocate(kmat_err )
     deallocate(kkmat_mpi)
     deallocate(kkmat_err)
     deallocate(lmat_mpi )
     deallocate(lmat_err )
     deallocate(rmat_mpi )
     deallocate(rmat_err )
     deallocate(lrmat_mpi)
     deallocate(lrmat_err)
     deallocate(g2_re_mpi)
     deallocate(g2_im_mpi)
     deallocate(ps_re_mpi)
     deallocate(ps_im_mpi)
     deallocate(gtau_mpi )
     deallocate(gtau_err )
     deallocate(grnf_mpi )
     deallocate(grnf_err )

     return
  end subroutine ctqmc_impurity_solver

!!>>> ctqmc_diagram_warmming: perform thermalization or warmup on the
!!>>> perturbation expansion series to achieve thermodynamics stable
!!>>> equilibrium state
  subroutine ctqmc_diagram_warmming()
     use constants, only : zero

     use control, only : ntherm
     use context, only : cnegs, caves
     use context, only : insert_tcount, insert_accept, insert_reject
     use context, only : remove_tcount, remove_accept, remove_reject
     use context, only : lshift_tcount, lshift_accept, lshift_reject
     use context, only : rshift_tcount, rshift_accept, rshift_reject
     use context, only : reflip_tcount, reflip_accept, reflip_reject

     implicit none

! local variables
! loop index
     integer :: i

! warm up the diagram series
     do i=1,ntherm
         call ctqmc_diagram_sampling(i)
     enddo ! over i={1,ntherm} loop

! reset cnegs
     cnegs = 0

! reset caves
     caves = 0

! reinit statistics variables
     insert_tcount = zero
     insert_accept = zero
     insert_reject = zero

     remove_tcount = zero
     remove_accept = zero
     remove_reject = zero

     lshift_tcount = zero
     lshift_accept = zero
     lshift_reject = zero

     rshift_tcount = zero
     rshift_accept = zero
     rshift_reject = zero

     reflip_tcount = zero
     reflip_accept = zero
     reflip_reject = zero

     return
  end subroutine ctqmc_diagram_warmming

!!>>> ctqmc_diagram_sampling: visit the perturbation expansion diagrams
!!>>> randomly
  subroutine ctqmc_diagram_sampling(cstep)
     use constants, only : dp
     use spring, only : spring_sfmt_stream

     use control, only : nflip, nclean

     implicit none

! external arguments
! current QMC sweep steps
     integer, intent(in) :: cstep

! change the order of perturbation expansion series
     if ( spring_sfmt_stream() < 0.9_dp ) then
         if ( spring_sfmt_stream() > 0.5_dp ) then
             call ctqmc_insert_kink()  ! insert one new kink
         else
             call ctqmc_remove_kink()  ! remove one old kink
         endif ! back if ( spring_sfmt_stream() > 0.5_dp ) block
! do not change the order of perturbation expansion series
     else
         if ( spring_sfmt_stream() > 0.5_dp ) then
             call ctqmc_lshift_kink()  ! shift the create  operators
         else
             call ctqmc_rshift_kink()  ! shift the destroy operators
         endif ! back if ( spring_sfmt_stream() > 0.5_dp ) block
     endif ! back if ( spring_sfmt_stream() < 0.9_dp ) block

! numerical trick: perform global spin flip periodically
     if ( nflip > 0  .and. mod(cstep, +nflip) == 0 ) then
         if ( spring_sfmt_stream() < 0.8_dp ) then
             call ctqmc_reflip_kink(2) ! flip intra-orbital spins one by one
         else
             call ctqmc_reflip_kink(3) ! flip intra-orbital spins globally
         endif ! back if ( spring_sfmt_stream() < 0.8_dp ) block
     endif ! back if ( nflip > 0  .and. mod(cstep, +nflip) == 0 ) block

     if ( nflip < 0  .and. mod(cstep, -nflip) == 0 ) then
         if ( spring_sfmt_stream() < 0.8_dp ) then
             call ctqmc_reflip_kink(1) ! flip inter-orbital spins randomly
         else
             call ctqmc_reflip_kink(3) ! flip intra-orbital spins globally
         endif ! back if ( spring_sfmt_stream() < 0.8_dp ) block
     endif ! back if ( nflip < 0  .and. mod(cstep, -nflip) == 0 ) block

! numerical trick: perform global update periodically
     if ( nclean > 0 .and. mod(cstep, nclean) == 0 ) then
         call ctqmc_reload_kink()
     endif ! back if ( nclean > 0 .and. mod(cstep, nclean) == 0 ) block

     return
  end subroutine ctqmc_diagram_sampling

!!>>> ctqmc_diagram_checking: checking whether the quantum impurity
!!>>> solver is consistent internally
  subroutine ctqmc_diagram_checking(cflag)
     use constants, only : mystd

     use control, only : norbs
     use control, only : myid, master
     use context, only : index_s, index_e, time_s, time_e
     use context, only : index_v, time_v
     use context, only : rank

     implicit none

! external arguments
! control flag
     integer, intent(inout) :: cflag

! local variables
! loop index
     integer :: i
     integer :: j

     if ( cflag == 1 ) then

! check time order of operators in colour part
         do i=1,norbs
             do j=1,rank(i)-1
                 if ( time_s( index_s(j, i), i ) > time_s( index_s(j+1, i), i ) ) then
                     cflag = 99
                 endif ! back if ( time_s( index_s(j, i), i ) > time_s( index_s(j+1, i), i ) ) block
                 if ( time_e( index_e(j, i), i ) > time_e( index_e(j+1, i), i ) ) then
                     cflag = 99
                 endif ! back if ( time_e( index_e(j, i), i ) > time_e( index_e(j+1, i), i ) ) block
             enddo ! over j={1,rank(i)-1} loop
         enddo ! over i={1,norbs} loop

! check time order of operators in flavor part
         do j=1,2*sum(rank)-1
             if ( index_v(j) <= 0 .or. index_v(j+1) <= 0 ) then
                 cflag = 99
             endif ! back if ( index_v(j) <= 0 .or. index_v(j+1) <= 0 ) block
         enddo ! over j={1,2*sum(rank)-1} loop

         do j=1,2*sum(rank)-1
             if ( time_v( index_v(j) ) > time_v( index_v(j+1) ) ) then
                 cflag = 99
             endif ! back if ( time_v( index_v(j) ) > time_v( index_v(j+1) ) ) block
         enddo ! over j={1,2*sum(rank)-1} loop

! write the results, only master node can do it
         if ( myid == master ) then
             if ( cflag == 99 ) then
                 write(mystd,'(4X,a)') '>>> quantum impurity solver status: error?'
                 write(mystd,'(4X,a)') '>>> please check the status file: solver.status.dat'
                 call ctqmc_save_status()
                 call s_print_error('ctqmc_diagram_checking','unknown fatal error occur')
             else
                 write(mystd,'(4X,a)') '>>> quantum impurity solver status: normal'
             endif ! back if ( cflag == 99 ) block
         endif ! back if ( myid == master ) block

     endif ! back if ( cflag == 1 ) block

     return
  end subroutine ctqmc_diagram_checking

!!>>> ctqmc_diagram_plotting: write out a snapshot for the current diagram
!!>>> configuration, the results can be used to make a dynamical video.
  subroutine ctqmc_diagram_plotting(iter, cstep)
     use constants, only : mystd, mytmp

     use control, only : norbs
     use control, only : niter
     use control, only : nwrite, nsweep
     use context, only : index_s, index_e, time_s, time_e
     use context, only : rank

     implicit none

! external arguments
! current self-consistent iteration number
     integer, intent(in) :: iter

! current QMC sweeping steps
     integer, intent(in) :: cstep

! local variables
! loop index for the flavor
     integer :: i

! loop index for the operator pair
     integer :: j

! setup the internal criterion
     if ( nsweep/nwrite < 100 ) RETURN

! write the snapshot
! open data file: solver.diag.dat
     open(mytmp, file='solver.diag.dat', form='formatted', status='unknown', position='append')

! write diagram info
     write(mytmp,'(2(a,i4))') '>> cur_iter:', iter, ' tot_iter:', niter
     write(mytmp,'(2(a,i4))') '>> cur_diag:', cstep/nwrite, ' tot_diag:', nsweep/nwrite

! write the position of operators
     do i=1,norbs
         write(mytmp,'(2(a,i4))') '# flvr:', i, ' rank:', rank(i)
         do j=1,rank(i)
             write(mytmp,'(i4,2f16.8)') i, time_s( index_s(j, i), i ), time_e( index_e(j, i), i )
         enddo ! over j={1,rank(i)} loop
     enddo ! over i={1,norbs} loop

! write two blank lines
     write(mytmp,*)
     write(mytmp,*)

! close data file
     close(mytmp)

! write the message to the terminal
     write(mystd,'(4X,a)') '>>> quantum impurity solver config: saving'

     return
  end subroutine ctqmc_diagram_plotting

!!>>> ctqmc_impurity_tester: testing subroutine, please try to active it
!!>>> on ctqmc_diagram_sampling() subroutine
  subroutine ctqmc_impurity_tester()
     use constants ! ALL

     use control   ! ALL
     use context   ! ALL

     implicit none

!-------------------------------------------------------------------------
! please insert your debug code here
!-------------------------------------------------------------------------

     call ctqmc_make_display(1)
     call ctqmc_make_display(2)
     call s_print_error('ctqmc_impurity_tester','in debug mode')

     return
  end subroutine ctqmc_impurity_tester
