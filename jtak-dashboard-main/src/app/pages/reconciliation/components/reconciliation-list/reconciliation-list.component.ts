import { Component, OnInit, ChangeDetectorRef, ViewChild, TemplateRef } from '@angular/core';
import { NgbModal } from '@ng-bootstrap/ng-bootstrap';
import {
  CaptainSettlementSummary,
  CaptainShiftDetails,
  DailySettlementBatch,
  SettleCaptainShiftRequest,
  SettlementResult,
  SettlementRequestItem,
  SettlementRequestStatus,
  SettlementPartyType,
} from '../../models/reconciliation.model';
import { ReconciliationService } from '../../services/reconciliation.service';
import { NotificationSummaryService } from 'src/app/_metronic/layout/core/notification-summary.service';

@Component({
  selector: 'app-reconciliation-list',
  templateUrl: './reconciliation-list.component.html',
  styleUrls: ['./reconciliation-list.component.scss'],
})
export class ReconciliationListComponent implements OnInit {
  activeTab: 'merchants' | 'couriers' | 'history' = 'merchants';
  captains: CaptainSettlementSummary[] = [];
  filteredCaptains: CaptainSettlementSummary[] = [];
  history: DailySettlementBatch[] = [];
  settlementRequests: SettlementRequestItem[] = [];
  isLoadingRequests = false;
  processingRequestId: string | null = null;
  readonly requestStatus = SettlementRequestStatus;
  readonly partyType = SettlementPartyType;

  get merchantRequests(): SettlementRequestItem[] {
    return this.settlementRequests.filter(r => r.partyType === SettlementPartyType.Merchant);
  }

  get pendingMerchantRequestsCount(): number {
    return this.merchantRequests.filter(r => r.status === SettlementRequestStatus.Pending).length;
  }

  get courierRequests(): SettlementRequestItem[] {
    return this.settlementRequests.filter(r => r.partyType === SettlementPartyType.Captain);
  }

  get pendingCourierRequestsCount(): number {
    return this.courierRequests.filter(r => r.status === SettlementRequestStatus.Pending).length;
  }

  isLoading: boolean = false;
  searchTerm: string = '';

  // Settlement Form State
  selectedCaptain: CaptainSettlementSummary | null = null;
  settleCashReceived: number = 0;
  settleNotes: string = '';
  settleReason: string = '';
  isSettling: boolean = false;
  settlementError: string | null = null;
  settlementSuccess: SettlementResult | null = null;

  // Statement State
  statementDetails: CaptainShiftDetails | null = null;
  isLoadingStatement: boolean = false;

  constructor(
    private reconciliationService: ReconciliationService,
    private modalService: NgbModal,
    private cdr: ChangeDetectorRef,
    private notificationSummaryService: NotificationSummaryService
  ) {}

  ngOnInit(): void {
    this.loadCaptains();
    this.loadHistory();
    this.loadSettlementRequests();
  }

  loadSettlementRequests(): void {
    this.isLoadingRequests = true;
    this.reconciliationService.getSettlementRequests().subscribe({
      next: (items) => {
        this.settlementRequests = items || [];
        this.isLoadingRequests = false;
        this.cdr.detectChanges();
      },
      error: () => {
        this.isLoadingRequests = false;
        this.cdr.detectChanges();
      },
    });
  }

  acceptSettlementRequest(item: SettlementRequestItem): void {
    const message = item.partyType === SettlementPartyType.Captain
      ? `تأكيد استلام ${item.amount.toLocaleString()} ل.س من المندوب؟ سيتم تصفير عهدته وإضافة المبلغ لخزنة جيتك.`
      : `قبول طلب التاجر ${item.requestNumber}؟ سيبقى المبلغ محجوزاً حتى تأكيد الاستلام.`;
    if (!window.confirm(message)) return;
    this.processingRequestId = item.id;
    this.reconciliationService.acceptRequest(item.id).subscribe({
      next: () => this.finishRequestAction(),
      error: (err) => this.failRequestAction(err),
    });
  }

  rejectSettlementRequest(item: SettlementRequestItem): void {
    const reason = window.prompt('اكتب سبب رفض طلب التسوية (سيصل لصاحب الطلب):');
    if (reason === null || !reason.trim()) return;
    this.processingRequestId = item.id;
    this.reconciliationService.rejectRequest(item.id, reason.trim()).subscribe({
      next: () => this.finishRequestAction(),
      error: (err) => this.failRequestAction(err),
    });
  }

  completeMerchantSettlement(item: SettlementRequestItem): void {
    if (!window.confirm(`تأكيد أن التاجر استلم ${item.amount.toLocaleString()} ل.س؟ سيتم خصم المبلغ من خزنة جيتك وإغلاق التسوية.`)) return;
    this.processingRequestId = item.id;
    this.reconciliationService.completeMerchantRequest(item.id).subscribe({
      next: () => this.finishRequestAction(),
      error: (err) => this.failRequestAction(err),
    });
  }

  requestStatusLabel(status: SettlementRequestStatus): string {
    switch (status) {
      case SettlementRequestStatus.Pending: return 'قيد المراجعة';
      case SettlementRequestStatus.Approved: return 'مقبول — بانتظار الاستلام';
      case SettlementRequestStatus.Rejected: return 'مرفوض';
      case SettlementRequestStatus.Completed: return 'مكتمل';
      default: return '-';
    }
  }

  private finishRequestAction(): void {
    this.processingRequestId = null;
    this.loadSettlementRequests();
    this.loadCaptains();
    this.loadHistory();
    this.notificationSummaryService.refresh();
  }

  private failRequestAction(err: any): void {
    this.processingRequestId = null;
    window.alert(err?.error?.message || err?.error?.title || err?.message || 'تعذر تنفيذ العملية');
    this.cdr.detectChanges();
  }

  loadCaptains(): void {
    this.isLoading = true;
    this.reconciliationService.getCaptains().subscribe({
      next: (data) => {
        this.captains = data || [];
        this.applyFilter();
        this.isLoading = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load fleet reconciliation summaries', err);
        this.isLoading = false;
        this.cdr.detectChanges();
      },
    });
  }

  loadHistory(): void {
    this.reconciliationService.getHistory(50).subscribe({
      next: (data) => {
        this.history = data || [];
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load settlement history', err);
      },
    });
  }

  applyFilter(): void {
    if (!this.searchTerm.trim()) {
      this.filteredCaptains = [...this.captains];
      return;
    }
    const term = this.searchTerm.toLowerCase();
    this.filteredCaptains = this.captains.filter(
      (c) =>
        (c.captainName && c.captainName.toLowerCase().includes(term)) ||
        (c.phoneNumber && c.phoneNumber.includes(term)) ||
        c.captainUserId.toLowerCase().includes(term)
    );
  }

  get totalFloatInField(): number {
    return this.captains.reduce((sum, c) => sum + (c.cashFloatBalance || 0), 0);
  }

  get totalWagesEarned(): number {
    return this.captains.reduce((sum, c) => sum + (c.wagesEarnedBalance || 0), 0);
  }

  get totalNetDue(): number {
    return this.captains.reduce((sum, c) => sum + (c.expectedNetCashDue || 0), 0);
  }

  get activeFleetCount(): number {
    return this.captains.filter((c) => (c.cashFloatBalance || 0) > 0 || (c.expectedNetCashDue || 0) > 0).length;
  }

  get settleDiscrepancy(): number {
    if (!this.selectedCaptain) return 0;
    return (this.settleCashReceived || 0) - (this.selectedCaptain.expectedNetCashDue || 0);
  }

  openSettleModal(content: TemplateRef<any>, captain: CaptainSettlementSummary): void {
    this.selectedCaptain = captain;
    this.settleCashReceived = captain.expectedNetCashDue > 0 ? captain.expectedNetCashDue : 0;
    this.settleNotes = '';
    this.settleReason = '';
    this.settlementError = null;
    this.settlementSuccess = null;
    this.isSettling = false;

    this.modalService.open(content, { size: 'lg', backdrop: 'static', centered: true });
  }

  confirmSettlement(modal: any): void {
    if (!this.selectedCaptain) return;

    if (this.settleDiscrepancy !== 0 && !this.settleReason.trim()) {
      this.settlementError = 'Please provide a discrepancy reason for non-zero cash variance.';
      return;
    }

    this.isSettling = true;
    this.settlementError = null;

    const request: SettleCaptainShiftRequest = {
      captainUserId: this.selectedCaptain.captainUserId,
      physicalCashReceived: this.settleCashReceived,
      currency: this.selectedCaptain.currency || 'SYP',
      notes: this.settleNotes,
      discrepancyReason: this.settleReason,
    };

    this.reconciliationService.settleShift(request).subscribe({
      next: (result) => {
        this.settlementSuccess = result;
        this.isSettling = false;
        this.loadCaptains();
        this.loadHistory();
        this.cdr.detectChanges();
        setTimeout(() => {
          modal.close();
        }, 1500);
      },
      error: (err) => {
        this.isSettling = false;
        this.settlementError = err?.error?.message || err?.message || 'Settlement failed. Check server logs.';
        this.cdr.detectChanges();
      },
    });
  }

  openStatementModal(content: TemplateRef<any>, captain: CaptainSettlementSummary): void {
    this.selectedCaptain = captain;
    this.isLoadingStatement = true;
    this.statementDetails = null;

    this.modalService.open(content, { size: 'xl', centered: true });

    this.reconciliationService.getCaptainStatement(captain.captainUserId).subscribe({
      next: (data) => {
        this.statementDetails = data;
        this.isLoadingStatement = false;
        this.cdr.detectChanges();
      },
      error: (err) => {
        console.error('Failed to load statement', err);
        this.isLoadingStatement = false;
        this.cdr.detectChanges();
      },
    });
  }

  formatPhoneNumber(phone?: string): string {
    if (!phone) return '-';
    let clean = phone.trim();
    if (!clean.startsWith('+')) {
      clean = '+' + clean;
    }
    // Syria: +963 912 345 666
    if (clean.startsWith('+963') && clean.length >= 12) {
      return `${clean.slice(0, 4)} ${clean.slice(4, 7)} ${clean.slice(7, 10)} ${clean.slice(10)}`;
    }
    // Turkey: +90 555 555 5553
    if (clean.startsWith('+90') && clean.length >= 12) {
      return `${clean.slice(0, 3)} ${clean.slice(3, 6)} ${clean.slice(6, 9)} ${clean.slice(9)}`;
    }
    // Universal 10-14 digit international chunking
    if (clean.length >= 11) {
      const countryCodeLen = clean.length > 12 ? 3 : 2;
      const cc = clean.slice(0, countryCodeLen + 1);
      const rest = clean.slice(countryCodeLen + 1);
      return `${cc} ${rest.slice(0, 3)} ${rest.slice(3, 6)} ${rest.slice(6)}`.trim();
    }
    return clean;
  }

  getInitials(name?: string): string {
    if (!name || !name.trim()) return 'C';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
    }
    return name.charAt(0).toUpperCase();
  }

  isSettled(cap: CaptainSettlementSummary): boolean {
    return (cap.cashFloatBalance || 0) === 0 && (cap.wagesEarnedBalance || 0) === 0 && (cap.expectedNetCashDue || 0) === 0;
  }

  printVoucher(batch: any): void {
    window.print();
  }
}
