import { Component, OnInit } from '@angular/core';
import { FormBuilder, Validators } from '@angular/forms';
import { NgbActiveModal } from '@ng-bootstrap/ng-bootstrap';
import { ToastrService } from 'ngx-toastr';
import { DriverCashAdvanceDriver, DriverCashAdvanceOverview } from '../../models/driver-cash-advance.model';
import { DriverCashAdvancesService } from '../../services/driver-cash-advances.service';

@Component({
  selector: 'app-driver-cash-advance-modal',
  templateUrl: './driver-cash-advance-modal.component.html',
  styleUrls: ['./driver-cash-advance-modal.component.scss'],
})
export class DriverCashAdvanceModalComponent implements OnInit {
  overview: DriverCashAdvanceOverview | null = null;
  isLoading = true;
  isSaving = false;
  loadError = '';

  form = this.fb.group({
    driverUserId: ['', Validators.required],
    amount: [null as number | null, [Validators.required, Validators.min(0.01)]],
    reason: ['', [Validators.required, Validators.maxLength(300)]],
  });

  constructor(
    private fb: FormBuilder,
    public modal: NgbActiveModal,
    private advances: DriverCashAdvancesService,
    private toastr: ToastrService
  ) {}

  ngOnInit(): void {
    this.loadOverview();
  }

  get selectedDriver(): DriverCashAdvanceDriver | undefined {
    const id = this.form.controls.driverUserId.value;
    return this.overview?.drivers.find((driver) => driver.id === id);
  }

  get amount(): number {
    return Number(this.form.controls.amount.value) || 0;
  }

  get canSubmit(): boolean {
    const driver = this.selectedDriver;
    return !this.isLoading && !this.isSaving && !!driver && this.form.valid &&
      this.amount <= driver.remainingCapacity &&
      this.amount <= (this.overview?.companyVaultBalance || 0);
  }

  loadOverview(): void {
    this.isLoading = true;
    this.loadError = '';
    this.advances.getOverview().subscribe({
      next: (overview) => {
        this.overview = overview;
        this.isLoading = false;
      },
      error: (error) => {
        this.loadError = this.errorMessage(error, 'تعذر تحميل أرصدة المندوبين وخزينة الشركة.');
        this.isLoading = false;
      },
    });
  }

  submit(): void {
    if (!this.canSubmit) {
      this.form.markAllAsTouched();
      return;
    }
    const driver = this.selectedDriver!;
    this.isSaving = true;
    this.advances.create({
      driverUserId: driver.id,
      amount: this.amount,
      reason: (this.form.controls.reason.value || '').trim(),
      idempotencyKey: this.newIdempotencyKey(),
    }).subscribe({
      next: (result) => {
        this.toastr.success(`تم تسجيل العهدة. الرصيد الحالي للمندوب ${result.balance.toLocaleString('en-US')} ل.س.`, 'تمت العملية');
        this.modal.close(result);
      },
      error: (error) => {
        this.isSaving = false;
        this.toastr.error(this.errorMessage(error, 'تعذر تسجيل العهدة. لم يتم اعتماد العملية.'));
        this.loadOverview();
      },
    });
  }

  private newIdempotencyKey(): string {
    return `web-${Date.now()}-${Math.random().toString(36).slice(2, 14)}`;
  }

  private errorMessage(error: any, fallback: string): string {
    return error?.error?.message || error?.error?.error || error?.error?.detail || fallback;
  }
}
