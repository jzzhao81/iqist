!!!-----------------------------------------------------------------------
!!! project : camellia
!!! program : ctqmc_dmft_selfer
!!!           ctqmc_dmft_conver
!!!           ctqmc_dmft_bethe
!!!           ctqmc_dmft_anydos
!!! source  : ctqmc_dmft.f90
!!! type    : subroutines
!!! author  : li huang (email:lihuang.dmft@gmail.com)
!!! history : 09/16/2009 by li huang (created)
!!!           08/17/2015 by li huang (last modified)
!!! purpose : the self-consistent engine for dynamical mean field theory
!!!           (DMFT) simulation. it is only suitable for hybridization
!!!           expansion version continuous time quantum Monte Carlo (CTQMC)
!!!           quantum impurity solver plus bethe lattice model.
!!! status  : unstable
!!! comment :
!!!-----------------------------------------------------------------------

!!>>> ctqmc_dmft_selfer: the self-consistent engine for continuous time
!!>>> quantum Monte Carlo quantum impurity solver plus dynamical mean field
!!>>> theory simulation
  subroutine ctqmc_dmft_selfer()
     use constants, only : dp, one, half, czi, mystd

     use control, only : nband, norbs
     use control, only : mfreq
     use control, only : Uc, Jz
     use control, only : mune, alpha
     use control, only : myid, master
     use context, only : tmesh, rmesh
     use context, only : eimp
     use context, only : grnf
     use context, only : wtau, wssf, hybf

     implicit none

! local variables
! loop index over flavors
     integer  :: i

! loop index over frequencies
     integer  :: k

! status flag
     integer  :: istat

! effective chemical potential
     real(dp) :: qmune

! dummy hybridization function, in matsubara frequency axis, matrix form
     complex(dp), allocatable :: htmp(:,:,:)

! allocate memory
     allocate(htmp(mfreq,norbs,norbs), stat=istat)
     if ( istat /= 0 ) then
         call s_print_error('ctqmc_dmft_selfer','can not allocate enough memory')
     endif ! back if ( istat /= 0 ) block

! initialize htmp
     htmp = hybf

! calculate new hybridization function using self-consistent condition
     call ctqmc_dmft_bethe(hybf, grnf)

! mixing new and old hybridization function: htmp and hybf
     call s_mix_z(size(hybf), htmp, hybf, alpha)

! \mu_{eff} = (N - 0.5)*U - (N - 1)*2.5*J
     qmune = ( real(nband) - half ) * Uc - ( real(nband) - one ) * 2.5_dp * Jz
     qmune = mune - qmune

! calculate new bath weiss's function
! G^{-1}_0 = i\omega + mu - E_{imp} - \Delta(i\omega)
     do i=1,norbs
         do k=1,mfreq
             wssf(k,i,i) = czi * rmesh(k) + qmune - eimp(i) - hybf(k,i,i)
         enddo ! over k={1,mfreq} loop
     enddo ! over i={1,norbs} loop

     do k=1,mfreq
         call s_inv_z(norbs, wssf(k,:,:))
     enddo ! over k={1,mfreq} loop

! fourier transformation bath weiss's function from matsubara frequency
! space to imaginary time space
     call ctqmc_four_hybf(wssf, wtau)

! write out the new bath weiss's function in matsubara frequency axis
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_wssf(rmesh, wssf)
     endif ! back if ( myid == master ) block

! write out the new bath weiss's function in imaginary time axis
     if ( myid == master ) then ! only master node can do it
         call ctqmc_dump_wtau(tmesh, wtau)
     endif ! back if ( myid == master ) block

! print necessary self-consistent simulation information
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(2X,a)') 'CAMELLIA >>> DMFT hybridization function is updated'
         write(mystd,*)
     endif ! back if ( myid == master ) block

! deallocate memory
     deallocate(htmp)

     return
  end subroutine ctqmc_dmft_selfer

!!>>> ctqmc_dmft_conver: check the convergence of self-energy function
  subroutine ctqmc_dmft_conver(iter, convergence)
     use constants, only : dp, zero, one, two, eps8, mystd

     use control, only : norbs, niter
     use control, only : mfreq
     use control, only : alpha
     use control, only : myid, master
     use context, only : sig1, sig2

     implicit none

! external arguments
! current iteration number
     integer, intent(in)    :: iter

! convergence flag
     logical, intent(inout) :: convergence

! local parameters
! required minimum iteration number to achieive convergence
     integer, parameter :: minit = 16

! local variables
! loop index over orbitals
     integer  :: i

! dummy variables
     real(dp) :: diff
     real(dp) :: norm
     real(dp) :: seps

! calculate diff and norm
! why not using the whole matrix? since the off-diagonal elementes may be NaN!
     diff = zero
     do i=1,norbs
         diff = diff + abs( sum( sig2(:,i,i) - sig1(:,i,i) ) )
     enddo ! over i={1,norbs} loop

     norm = zero
     do i=1,norbs
         norm = norm + abs( sum( sig2(:,i,i) + sig1(:,i,i) ) )
     enddo ! over i={1,norbs} loop
     norm = norm / two

! calculate seps
     seps = (diff / norm) / real(mfreq * norbs)

! judge convergence status
     convergence = ( ( seps <= eps8 ) .and. ( iter >= minit ) )

! update sig1
     call s_mix_z(size(sig1), sig2, sig1, one - alpha)

! write convergence information to screen
     if ( myid == master ) then ! only master node can do it
         write(mystd,'(3(2X,a,i3))') 'CAMELLIA >>> cur_iter:', iter, 'min_iter:', minit, 'max_iter:', niter
         write(mystd,'(2(2X,a,E12.4))') 'CAMELLIA >>> sig_curr:', seps, 'eps_curr:', eps8
         write(mystd,'( (2X,a,L1))') 'CAMELLIA >>> self-consistent iteration convergence is ', convergence
         write(mystd,*)
     endif ! back if ( myid == master ) block

     return
  end subroutine ctqmc_dmft_conver

!!>>> ctqmc_dmft_bethe: dmft self-consistent conditions, bethe lattice,
!!>>> semicircular density of states, force a paramagnetic order, equal
!!>>> band width
  subroutine ctqmc_dmft_bethe(hybf, grnf)
     use constants, only : dp

     use control, only : norbs
     use control, only : mfreq
     use control, only : part

     implicit none

! external arguments
! hybridization function
     complex(dp), intent(out) :: hybf(mfreq,norbs,norbs)

! impurity green's function
     complex(dp), intent(in)  :: grnf(mfreq,norbs,norbs)

! local variables
! loop index over orbitals
     integer :: i
     integer :: j

     do i=1,norbs
         do j=1,norbs
             hybf(:,j,i) = part * part * grnf(:,j,i)
         enddo ! over j={1,norbs} loop
     enddo ! over i={1,norbs} loop

     return
  end subroutine ctqmc_dmft_bethe
